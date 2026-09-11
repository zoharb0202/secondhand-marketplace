import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secondhand_marketplace/core/constants/enums.dart';
import 'package:secondhand_marketplace/shared/models/product_model.dart';
import 'package:secondhand_marketplace/shared/models/product_similarity.dart';

final _now = DateTime(2026, 8, 18, 12, 0);

ProductModel prod({
  required String id,
  String sellerId = 'seller-a',
  String title = 'מוצר',
  ProductCategory category = ProductCategory.electronics,
  String? categoryId,
  String? subcategory,
  String? subCategoryId,
  String? brand,
  String? model,
  double price = 1000,
  ProductCondition condition = ProductCondition.good,
  int ageDays = 0,
  bool isSold = false,
  bool isActive = true,
}) {
  return ProductModel(
    id: id,
    sellerId: sellerId,
    title: title,
    description: '',
    price: price,
    category: category,
    categoryId: categoryId,
    subcategory: subcategory,
    subCategoryId: subCategoryId,
    brand: brand,
    condition: condition,
    imageUrls: const [],
    createdAt: _now.subtract(Duration(days: ageDays)),
    location: const GeoPoint(32.08, 34.78),
    city: 'תל אביב',
    specificFields: model == null ? null : {'model': model},
    isSold: isSold,
    isActive: isActive,
  );
}

SimilarityFeatures feat(ProductModel p) => SimilarityFeatures.fromProduct(p);

double scoreOf(ProductModel reference, ProductModel candidate) =>
    scoreSimilarity(
      reference: feat(reference),
      candidate: feat(candidate),
      now: _now,
    ).total;

SimilarityScore breakdown(ProductModel reference, ProductModel candidate) =>
    scoreSimilarity(
      reference: feat(reference),
      candidate: feat(candidate),
      now: _now,
    );

final iphone14 = prod(
  id: 'ref',
  title: 'אייפון 14 פרו',
  category: ProductCategory.electronics,
  categoryId: 'electronics',
  subcategory: 'mobilePhones',
  subCategoryId: 'smartphones',
  brand: 'Apple',
  model: 'iPhone 14 Pro',
  price: 3000,
  ageDays: 21,
);

void main() {
  group('normalisation', () {
    test('folds the Hebrew spellings that mean the same word', () {
      expect(normalizeToken('ג׳ינס'), normalizeToken("ג'ינס"));
      expect(normalizeToken('טלוויזיה'), normalizeToken('טלויזיה'));
      expect(normalizeToken('אופניים'), normalizeToken('אופנים'));
      expect(normalizeToken('  Apple '), 'apple');
    });

    test('the two category vocabularies fold to one key', () {
      expect(foldIdentifier('homeGarden'), foldIdentifier('home_garden'));
      expect(foldIdentifier('babyKids'), 'babykids');
      expect(foldIdentifier('kids') == foldIdentifier('toys'), isFalse);
    });
  });

  group('priceKeyFor (the price_stats definition, ported)', () {
    test('prefers the new catalog ids over the legacy strings', () {
      final key = priceKeyFor(
        prod(
          id: 'x',
          category: ProductCategory.babyKids,
          categoryId: 'toys',
          subcategory: 'baby_toys',
          subCategoryId: 'toys_games',
          brand: 'Lego',
          model: 'City 60380',
        ),
      )!;
      expect(key.category, 'toys');
      expect(key.subcategory, 'toys_games');
      expect(key.brand, 'lego');
      expect(key.model, 'city 60380');
    });

    test('falls back to the legacy fields when the new ids are absent', () {
      final key = priceKeyFor(
        prod(
          id: 'x',
          category: ProductCategory.electronics,
          subcategory: 'laptops',
          brand: 'Lenovo',
        ),
      )!;
      expect(key.category, 'electronics');
      expect(key.subcategory, 'laptops');
      expect(key.identifiesModel, isFalse);
    });

    test('is null when it would not name a comparable thing', () {
      expect(priceKeyFor(prod(id: 'x', brand: null)), isNull);
      expect(priceKeyFor(prod(id: 'x', brand: 'Sony')), isNull);
    });
  });

  group('scoreSimilarity', () {
    test('the same model beats the same brand in the same category', () {
      final sameModel = prod(
        id: 'a',
        title: 'אייפון 14 פרו למכירה',
        categoryId: 'electronics',
        subCategoryId: 'smartphones',
        brand: 'apple',
        model: 'iPhone 14 Pro',
        price: 3100,
      );
      final sameBrandSameCategory = prod(
        id: 'b',
        title: 'מקבוק פרו 14',
        categoryId: 'electronics',
        subCategoryId: 'laptops',
        brand: 'apple',
        model: 'MacBook Pro 14 M1 Pro',
        price: 3100,
      );

      expect(breakdown(iphone14, sameModel).tier, SimilarityTier.sameModel);
      expect(
        breakdown(iphone14, sameBrandSameCategory).tier,
        SimilarityTier.sameBrandAndCategory,
      );
      expect(
        scoreOf(iphone14, sameModel),
        greaterThan(scoreOf(iphone14, sameBrandSameCategory)),
      );
    });

    test('the same brand + category beats the category alone', () {
      final sameBrand = prod(
        id: 'a',
        title: 'אייפד אייר',
        categoryId: 'electronics',
        brand: 'apple',
        model: 'iPad Air',
        price: 3000,
      );
      final categoryOnly = prod(
        id: 'b',
        title: 'מסך מחשב דל',
        categoryId: 'electronics',
        brand: 'Dell',
        model: 'U2419H',
        price: 3000,
      );
      expect(
        scoreOf(iphone14, sameBrand),
        greaterThan(scoreOf(iphone14, categoryOnly)),
      );
      expect(
        breakdown(iphone14, categoryOnly).tier,
        SimilarityTier.relatedCategory,
      );
    });

    test(
      'a brand-new category listing does NOT outrank an old exact model',
      () {
        final oldExactModel = prod(
          id: 'old',
          title: 'אייפון 14 פרו',
          categoryId: 'electronics',
          subCategoryId: 'smartphones',
          brand: 'apple',
          model: 'iPhone 14 Pro',
          price: 3000,
          ageDays: 89,
        );
        final brandNewMicrowave = prod(
          id: 'new',
          title: 'מיקרוגל',
          categoryId: 'electronics',
          subCategoryId: 'appliances',
          brand: 'Samsung',
          model: 'MS23K3513',
          price: 400,
          ageDays: 0,
        );
        expect(
          scoreOf(iphone14, oldExactModel),
          greaterThan(scoreOf(iphone14, brandNewMicrowave)),
        );
      },
    );

    test(
      'a listing carrying both vocabularies bridges to one carrying either',
      () {
        final bothTagged = prod(
          id: 'both',
          subcategory: 'mobilePhones',
          subCategoryId: 'smartphones',
          brand: 'Xiaomi',
        );
        final legacyOnly = prod(
          id: 'legacy',
          subcategory: 'mobilePhones',
          brand: 'Xiaomi',
        );
        final newIdOnly = prod(
          id: 'new',
          subCategoryId: 'smartphones',
          brand: 'Xiaomi',
        );
        expect(breakdown(bothTagged, legacyOnly).sameSubcategory, isTrue);
        expect(breakdown(bothTagged, newIdOnly).sameSubcategory, isTrue);
        expect(breakdown(newIdOnly, bothTagged).sameSubcategory, isTrue);

        expect(breakdown(legacyOnly, newIdOnly).sameSubcategory, isFalse);
        expect(breakdown(legacyOnly, newIdOnly).isRelevant, isTrue);
      },
    );

    test('price proximity is a ratio, not a difference', () {
      expect(priceProximityScore(1000, 1000), kPriceProximityMaxScore);
      expect(priceProximityScore(100, 200), priceProximityScore(2000, 4000));
      expect(priceProximityScore(1000, 3000), 0);
      expect(priceProximityScore(1000, 9000), 0);
      expect(priceProximityScore(0, 0), 0);
    });

    test('a closer price wins between two otherwise identical candidates', () {
      final near = prod(
        id: 'near',
        title: 'אייפון 14 פרו',
        categoryId: 'electronics',
        subCategoryId: 'smartphones',
        brand: 'apple',
        model: 'iPhone 14 Pro',
        price: 3050,
      );
      final far = prod(
        id: 'far',
        title: 'אייפון 14 פרו',
        categoryId: 'electronics',
        subCategoryId: 'smartphones',
        brand: 'apple',
        model: 'iPhone 14 Pro',
        price: 5900,
      );
      expect(scoreOf(iphone14, near), greaterThan(scoreOf(iphone14, far)));
    });
  });

  group('the same-seller treatment', () {
    test(
      'lifts the seller\'s own item above an equal item from a stranger',
      () {
        final mine = prod(
          id: 'mine',
          sellerId: 'seller-a',
          title: 'אייפד אייר',
          categoryId: 'electronics',
          brand: 'apple',
          model: 'iPad Air',
          price: 3000,
        );
        final theirs = prod(
          id: 'theirs',
          sellerId: 'seller-z',
          title: 'אייפד אייר',
          categoryId: 'electronics',
          brand: 'apple',
          model: 'iPad Air',
          price: 3000,
        );
        final mineScore = breakdown(iphone14, mine);
        expect(mineScore.sameSeller, isTrue);
        expect(breakdown(iphone14, theirs).sameSeller, isFalse);
        expect(mineScore.total - scoreOf(iphone14, theirs), kSameSellerBoost);
      },
    );

    test('does not lift a BETTER match from a stranger below a worse one', () {
      final myUnrelatedishItem = prod(
        id: 'mine',
        sellerId: 'seller-a',
        title: 'מסך מחשב',
        categoryId: 'electronics',
        brand: 'Dell',
        model: 'U2419H',
        price: 900,
      );
      final theirExactModel = prod(
        id: 'theirs',
        sellerId: 'seller-z',
        title: 'אייפון 14 פרו',
        categoryId: 'electronics',
        subCategoryId: 'smartphones',
        brand: 'apple',
        model: 'iPhone 14 Pro',
        price: 3000,
      );
      expect(
        scoreOf(iphone14, theirExactModel),
        greaterThan(scoreOf(iphone14, myUnrelatedishItem)),
      );
    });

    test('cannot drag a genuinely unrelated item into the strip', () {
      final gardenHose = prod(
        id: 'hose',
        sellerId: 'seller-a',
        title: 'צינור השקיה',
        category: ProductCategory.homeGarden,
        categoryId: 'home_garden',
        subCategoryId: 'garden',
        brand: 'Gardena',
        model: 'Classic 20m',
        price: 90,
      );
      final score = breakdown(iphone14, gardenHose);
      expect(score.sameSeller, isTrue);
      expect(score.isRelevant, isFalse);
      expect(
        rankSimilarProducts(
          reference: feat(iphone14),
          candidates: [gardenHose],
          now: _now,
        ),
        isEmpty,
      );
    });

    test('one coincidental title word is not a link, two are', () {
      final bikePro = prod(
        id: 'bike',
        sellerId: 'seller-a',
        title: 'אופניים פרו',
        category: ProductCategory.sports,
        categoryId: 'sports',
        brand: 'Trek',
        model: 'Marlin 5',
        price: 900,
      );
      final bikeScore = breakdown(iphone14, bikePro);
      expect(bikeScore.sharedModelTokens, 1);
      expect(bikeScore.sameBrand, isFalse);
      expect(bikeScore.sameBroadCategory, isFalse);
      expect(bikeScore.sameFineCategory, isFalse);
      expect(bikeScore.sameSubcategory, isFalse);
      expect(bikeScore.total, greaterThan(kMinimumRelevance));
      expect(bikeScore.isRelevant, isFalse);
      expect(
        rankSimilarProducts(
          reference: feat(iphone14),
          candidates: [bikePro],
          now: _now,
        ),
        isEmpty,
      );

      final case14 = prod(
        id: 'case',
        sellerId: 'seller-a',
        title: 'כיסוי אייפון 14',
        category: ProductCategory.other,
        categoryId: 'accessories',
        brand: 'Spigen',
        price: 60,
      );
      final caseScore = breakdown(iphone14, case14);
      expect(
        caseScore.sharedModelTokens,
        greaterThanOrEqualTo(kMinSharedTokensForRelevance),
      );
      expect(caseScore.sameBrand, isFalse);
      expect(caseScore.sameBroadCategory, isFalse);
      expect(caseScore.isRelevant, isTrue);
    });

    test('HONEST LIMIT: a Hebrew prefix letter hides a shared word', () {
      final prefixed = prod(
        id: 'prefixed',
        sellerId: 'seller-a',
        title: 'כיסוי לאייפון 14',
        category: ProductCategory.other,
        categoryId: 'accessories',
        brand: 'Spigen',
        price: 60,
      );
      expect(breakdown(iphone14, prefixed).sharedModelTokens, 1);
    });
  });

  group('rankSimilarProducts', () {
    test('orders the pool by similarity, not by age', () {
      final pool = [
        prod(
          id: 'microwave',
          title: 'מיקרוגל',
          brand: 'Samsung',
          model: 'MS23',
          price: 400,
        ),
        prod(
          id: 'exact',
          title: 'אייפון 14 פרו',
          categoryId: 'electronics',
          subCategoryId: 'smartphones',
          brand: 'apple',
          model: 'iPhone 14 Pro',
          price: 2950,
          ageDays: 60,
        ),
        prod(
          id: 'ipad',
          title: 'אייפד אייר',
          categoryId: 'electronics',
          brand: 'apple',
          model: 'iPad Air',
          price: 2800,
          ageDays: 30,
        ),
      ];
      final ranked = rankSimilarProducts(
        reference: feat(iphone14),
        candidates: pool,
        now: _now,
      );
      expect(ranked.map((s) => s.product.id).toList(), [
        'exact',
        'ipad',
        'microwave',
      ]);
    });

    test(
      'drops the reference itself, sold, inactive and duplicate entries',
      () {
        final dup = prod(
          id: 'dup',
          title: 'אייפון 14 פרו',
          categoryId: 'electronics',
          brand: 'apple',
          model: 'iPhone 14 Pro',
        );
        final ranked = rankSimilarProducts(
          reference: feat(iphone14),
          candidates: [
            iphone14,
            dup,
            dup,
            prod(
              id: 'sold',
              brand: 'apple',
              model: 'iPhone 14 Pro',
              isSold: true,
            ),
            prod(
              id: 'off',
              brand: 'apple',
              model: 'iPhone 14 Pro',
              isActive: false,
            ),
          ],
          now: _now,
        );
        expect(ranked.map((s) => s.product.id).toList(), ['dup']);
      },
    );

    test('respects the limit', () {
      final pool = List.generate(
        30,
        (i) => prod(
          id: 'p$i',
          sellerId: 'seller-$i',
          title: 'אייפון 14 פרו',
          categoryId: 'electronics',
          brand: 'apple',
          model: 'iPhone 14 Pro',
          ageDays: i,
        ),
      );
      expect(
        rankSimilarProducts(
          reference: feat(iphone14),
          candidates: pool,
          now: _now,
          limit: 5,
        ).length,
        5,
      );
    });

    test('caps how much of the strip one seller may fill', () {
      final mine = List.generate(
        8,
        (i) => prod(
          id: 'mine$i',
          sellerId: 'seller-a',
          title: 'אייפון 14 פרו',
          categoryId: 'electronics',
          brand: 'apple',
          model: 'iPhone 14 Pro',
          ageDays: i,
        ),
      );
      final theirs = List.generate(
        8,
        (i) => prod(
          id: 'theirs$i',
          sellerId: 'seller-z',
          title: 'אייפון 14 פרו',
          categoryId: 'electronics',
          brand: 'apple',
          model: 'iPhone 14 Pro',
          ageDays: i,
        ),
      );
      final ranked = rankSimilarProducts(
        reference: feat(iphone14),
        candidates: [...mine, ...theirs],
        now: _now,
        limit: 10,
        maxFromSameSeller: 3,
      );
      expect(ranked.length, 10);
      expect(ranked.where((s) => s.isFromSameSeller).length, 3);
    });

    test('is deterministic when scores tie', () {
      final pool = [
        prod(
          id: 'b',
          title: 'אייפון 14 פרו',
          brand: 'apple',
          model: 'iPhone 14 Pro',
        ),
        prod(
          id: 'a',
          title: 'אייפון 14 פרו',
          brand: 'apple',
          model: 'iPhone 14 Pro',
        ),
      ];
      final first = rankSimilarProducts(
        reference: feat(iphone14),
        candidates: pool,
        now: _now,
      );
      final second = rankSimilarProducts(
        reference: feat(iphone14),
        candidates: pool.reversed.toList(),
        now: _now,
      );
      expect(
        first.map((s) => s.product.id).toList(),
        second.map((s) => s.product.id).toList(),
      );
    });
  });

  group('brandQueryVariants (recall, not ranking)', () {
    test('asks for the spellings that actually occur in the catalog', () {
      expect(brandQueryVariants('Apple'), ['Apple', 'apple']);
      expect(brandQueryVariants('samsung'), ['samsung', 'Samsung']);
      expect(brandQueryVariants('LG'), ['LG', 'lg', 'Lg']);
    });

    test('produces no query at all for a blank brand', () {
      expect(brandQueryVariants(''), isEmpty);
      expect(brandQueryVariants('   '), isEmpty);
    });
  });
}
