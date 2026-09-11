import '../../core/constants/enums.dart';
import 'product_model.dart';

final RegExp _hebDiacritics = RegExp('[֑-ׇ]');
final RegExp _hebQuotes = RegExp('[\'"׳״‘’“”]');
const Map<String, String> _finalForms = {
  'ך': 'כ',
  'ם': 'מ',
  'ן': 'נ',
  'ף': 'פ',
  'ץ': 'צ',
};
final RegExp _finalFormChars = RegExp('[ךםןףץ]');
final RegExp _nonAlphanumeric = RegExp(r'[^0-9a-zא-ת]+');

String normalizeToken(String raw) {
  var t = raw.toLowerCase().trim();
  t = t.replaceAll(_hebDiacritics, '').replaceAll(_hebQuotes, '');
  t = t.replaceAllMapped(_finalFormChars, (m) => _finalForms[m[0]] ?? m[0]!);
  t = t.replaceAll('וו', 'ו').replaceAll('יי', 'י');
  return t;
}

String foldIdentifier(String raw) =>
    normalizeToken(raw).replaceAll(_nonAlphanumeric, '');

const Set<String> matchFillerWords = {
  'חדש',
  'חדשה',
  'יד',
  'שנייה',
  'שניה',
  'למכירה',
  'מצוין',
  'מצוינת',
  'מצויין',
  'כמו',
  'במצב',
  'מושלם',
  'מושלמת',
  'מקורי',
  'מקורית',
  'זול',
  'מבצע',
  'הזדמנות',
  'דחוף',
  'בהזדמנות',
  'משומש',
  'משומשת',
  'new',
  'used',
  'like',
  'condition',
  'for',
  'sale',
  'the',
  'and',
  'with',
  'original',
  'mint',
};

List<String> coreTokens(String text) {
  final seen = <String>{};
  for (final part in normalizeToken(text).split(_nonAlphanumeric)) {
    if (part.length < 2) continue;
    if (matchFillerWords.contains(part)) continue;
    seen.add(part);
  }
  final out = seen.toList()..sort();
  return out;
}

String productMatchKey(ProductModel p) {
  final brand = (p.brand ?? '').toLowerCase().trim();
  final sub = (p.subcategory ?? '').toLowerCase().trim();
  final tokens =
      p.title
          .toLowerCase()
          .replaceAll(RegExp(r'[^0-9a-z֐-׿]+'), ' ')
          .split(RegExp(r'\s+'))
          .where((t) => t.length >= 2 && !matchFillerWords.contains(t))
          .toSet()
          .toList()
        ..sort();
  final core = tokens.join('-');
  return '$brand|$sub|$core';
}

class ProductPriceKey {
  final String category;
  final String subcategory;
  final String brand;
  final String model;

  const ProductPriceKey({
    required this.category,
    required this.subcategory,
    required this.brand,
    required this.model,
  });

  bool get identifiesModel => model.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is ProductPriceKey &&
      other.category == category &&
      other.subcategory == subcategory &&
      other.brand == brand &&
      other.model == model;

  @override
  int get hashCode => Object.hash(category, subcategory, brand, model);

  @override
  String toString() => '$category|$subcategory|$brand|$model';
}

ProductPriceKey? priceKeyFor(ProductModel p) {
  final brand = normalizeToken(p.brand ?? '');
  final model = normalizeToken((p.specificFields?['model'] as String?) ?? '');
  final category = p.categoryId ?? p.category.name;
  final subcategory = p.subCategoryId ?? p.subcategory ?? '';
  if (brand.isEmpty) return null;
  if (model.isEmpty && subcategory.isEmpty) return null;
  return ProductPriceKey(
    category: category,
    subcategory: subcategory,
    brand: brand,
    model: model,
  );
}

const double kSameModelScore = 100;

const double kPartialModelMaxScore = 35;

const double kSameBrandScore = 30;

const double kFineCategoryScore = 25;

const double kBroadCategoryScore = 12;

const double kSameSubcategoryScore = 18;

const double kSameConditionScore = 6;

const double kPriceProximityMaxScore = 20;

const double kPriceRatioCutoff = 3.0;

const double kSameSellerBoost = 15;

const double kFreshnessMaxScore = 4;

const int kFreshnessHorizonDays = 90;

const double kMinimumRelevance = kBroadCategoryScore;

const int kMinSharedTokensForRelevance = 2;

const int kSimilarCategoryPoolSize = 150;

const int kSimilarBrandPoolSize = 40;

const int kSimilarSellerPoolSize = 30;

const int kMaxFromSameSeller = 4;

const int kSimilarProductsLimit = 12;

class SimilarityFeatures {
  final String productId;
  final String sellerId;

  final String legacyCategory;

  final String rawBrand;

  final String brand;

  final String model;

  final ProductPriceKey? priceKey;

  final String matchKey;

  final Set<String> categoryKeys;

  final String fineCategoryKey;

  final Set<String> subcategoryKeys;

  final Set<String> modelTokens;

  final double price;
  final ProductCondition condition;
  final DateTime createdAt;

  final String signature;

  SimilarityFeatures({
    required this.productId,
    required this.sellerId,
    required this.legacyCategory,
    required this.rawBrand,
    required this.brand,
    required this.model,
    required this.priceKey,
    required this.matchKey,
    required this.categoryKeys,
    required this.fineCategoryKey,
    required this.subcategoryKeys,
    required this.modelTokens,
    required this.price,
    required this.condition,
    required this.createdAt,
  }) : signature = [
         productId,
         sellerId,
         legacyCategory,
         rawBrand,
         model,
         priceKey?.toString() ?? '',
         matchKey,
         (categoryKeys.toList()..sort()).join(','),
         fineCategoryKey,
         (subcategoryKeys.toList()..sort()).join(','),
         (modelTokens.toList()..sort()).join(','),
         price.toString(),
         condition.name,
         createdAt.millisecondsSinceEpoch.toString(),
       ].join('§');

  factory SimilarityFeatures.fromProduct(ProductModel p) {
    final model = normalizeToken((p.specificFields?['model'] as String?) ?? '');
    final fine = foldIdentifier(p.categoryId ?? '');
    final categoryKeys = <String>{foldIdentifier(p.category.name)};
    if (fine.isNotEmpty) categoryKeys.add(fine);
    final subcategoryKeys = <String>{
      foldIdentifier(p.subcategory ?? ''),
      foldIdentifier(p.subCategoryId ?? ''),
    }..removeWhere((s) => s.isEmpty);
    return SimilarityFeatures(
      productId: p.id,
      sellerId: p.sellerId,
      legacyCategory: p.category.name,
      rawBrand: (p.brand ?? '').trim(),
      brand: normalizeToken(p.brand ?? ''),
      model: model,
      priceKey: priceKeyFor(p),
      matchKey: productMatchKey(p),
      categoryKeys: categoryKeys,
      fineCategoryKey: fine,
      subcategoryKeys: subcategoryKeys,
      modelTokens: {...coreTokens(model), ...coreTokens(p.title)},
      price: p.price,
      condition: p.condition,
      createdAt: p.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SimilarityFeatures && other.signature == signature;

  @override
  int get hashCode => signature.hashCode;
}

enum SimilarityTier {
  sameModel,

  sameBrandAndCategory,

  sameBrand,

  relatedCategory,

  unrelated,
}

class SimilarityScore {
  final double total;
  final bool sameModel;
  final bool sameBrand;
  final bool sameFineCategory;
  final bool sameBroadCategory;
  final bool sameSubcategory;
  final bool sameSeller;

  final double modelOverlap;

  final int sharedModelTokens;

  final Map<String, double> components;

  const SimilarityScore({
    required this.total,
    required this.sameModel,
    required this.sameBrand,
    required this.sameFineCategory,
    required this.sameBroadCategory,
    required this.sameSubcategory,
    required this.sameSeller,
    required this.modelOverlap,
    required this.sharedModelTokens,
    required this.components,
  });

  bool get isRelevant =>
      (sameModel ||
          sameBrand ||
          sameSubcategory ||
          sameFineCategory ||
          sameBroadCategory ||
          sharedModelTokens >= kMinSharedTokensForRelevance) &&
      total >= kMinimumRelevance;

  SimilarityTier get tier {
    if (sameModel) return SimilarityTier.sameModel;
    if (sameBrand) {
      return (sameFineCategory || sameBroadCategory || sameSubcategory)
          ? SimilarityTier.sameBrandAndCategory
          : SimilarityTier.sameBrand;
    }
    if (sameFineCategory || sameBroadCategory || sameSubcategory) {
      return SimilarityTier.relatedCategory;
    }
    return SimilarityTier.unrelated;
  }

  @override
  String toString() =>
      'SimilarityScore(${total.toStringAsFixed(1)}, ${tier.name})';
}

double priceProximityScore(double a, double b) {
  if (a <= 0 || b <= 0) return 0;
  final ratio = a > b ? a / b : b / a;
  if (ratio >= kPriceRatioCutoff) return 0;
  return kPriceProximityMaxScore * (1 - (ratio - 1) / (kPriceRatioCutoff - 1));
}

double conditionProximityScore(ProductCondition a, ProductCondition b) {
  final d = (a.index - b.index).abs();
  if (d == 0) return kSameConditionScore;
  if (d == 1) return kSameConditionScore / 2;
  return 0;
}

double freshnessScore(DateTime createdAt, DateTime now) {
  final days = now.difference(createdAt).inDays;
  if (days <= 0) return kFreshnessMaxScore;
  if (days >= kFreshnessHorizonDays) return 0;
  return kFreshnessMaxScore * (1 - days / kFreshnessHorizonDays);
}

double _jaccard(Set<String> a, Set<String> b) {
  if (a.isEmpty || b.isEmpty) return 0;
  final shared = a.intersection(b).length;
  if (shared == 0) return 0;
  return shared / a.union(b).length;
}

SimilarityScore scoreSimilarity({
  required SimilarityFeatures reference,
  required SimilarityFeatures candidate,
  required DateTime now,
}) {
  final components = <String, double>{};

  final refKey = reference.priceKey;
  final candKey = candidate.priceKey;
  final sameModelByPriceKey =
      refKey != null &&
      candKey != null &&
      refKey.identifiesModel &&
      candKey.identifiesModel &&
      refKey.brand == candKey.brand &&
      refKey.model == candKey.model;
  final sameModelByMatchKey =
      reference.matchKey == candidate.matchKey &&
      (reference.brand.isNotEmpty || reference.modelTokens.length >= 2);
  final sameModel = sameModelByPriceKey || sameModelByMatchKey;

  final sharedTokens = reference.modelTokens
      .intersection(candidate.modelTokens)
      .length;
  final overlap = sameModel
      ? 1.0
      : _jaccard(reference.modelTokens, candidate.modelTokens);

  if (sameModel) {
    components['model'] = kSameModelScore;
  } else if (overlap > 0) {
    components['model'] = kPartialModelMaxScore * overlap;
  }

  final sameBrand =
      reference.brand.isNotEmpty && reference.brand == candidate.brand;
  if (sameBrand) components['brand'] = kSameBrandScore;

  final sameFineCategory =
      reference.fineCategoryKey.isNotEmpty &&
      reference.fineCategoryKey == candidate.fineCategoryKey;
  final sameBroadCategory = reference.categoryKeys
      .intersection(candidate.categoryKeys)
      .isNotEmpty;
  if (sameFineCategory) {
    components['category'] = kFineCategoryScore;
  } else if (sameBroadCategory) {
    components['category'] = kBroadCategoryScore;
  }

  final sameSubcategory = reference.subcategoryKeys
      .intersection(candidate.subcategoryKeys)
      .isNotEmpty;
  if (sameSubcategory) components['subcategory'] = kSameSubcategoryScore;

  final condition = conditionProximityScore(
    reference.condition,
    candidate.condition,
  );
  if (condition > 0) components['condition'] = condition;

  final price = priceProximityScore(reference.price, candidate.price);
  if (price > 0) components['price'] = price;

  final freshness = freshnessScore(candidate.createdAt, now);
  if (freshness > 0) components['freshness'] = freshness;

  final sameSeller =
      reference.sellerId.isNotEmpty && reference.sellerId == candidate.sellerId;
  if (sameSeller) components['seller'] = kSameSellerBoost;

  final total = components.values.fold<double>(0, (a, b) => a + b);

  return SimilarityScore(
    total: total,
    sameModel: sameModel,
    sameBrand: sameBrand,
    sameFineCategory: sameFineCategory,
    sameBroadCategory: sameBroadCategory,
    sameSubcategory: sameSubcategory,
    sameSeller: sameSeller,
    modelOverlap: overlap,
    sharedModelTokens: sharedTokens,
    components: Map.unmodifiable(components),
  );
}

class ScoredProduct {
  final ProductModel product;
  final SimilarityScore score;

  const ScoredProduct({required this.product, required this.score});

  bool get isFromSameSeller => score.sameSeller;

  @override
  String toString() => 'ScoredProduct(${product.id}, $score)';
}

List<ScoredProduct> rankSimilarProducts({
  required SimilarityFeatures reference,
  required Iterable<ProductModel> candidates,
  required DateTime now,
  int limit = kSimilarProductsLimit,
  int maxFromSameSeller = kMaxFromSameSeller,
}) {
  final seen = <String>{};
  final scored = <ScoredProduct>[];

  for (final p in candidates) {
    if (p.id == reference.productId) continue;
    if (p.isSold || !p.isActive) continue;
    if (!seen.add(p.id)) continue;

    final score = scoreSimilarity(
      reference: reference,
      candidate: SimilarityFeatures.fromProduct(p),
      now: now,
    );
    if (!score.isRelevant) continue;
    scored.add(ScoredProduct(product: p, score: score));
  }

  scored.sort((a, b) {
    final byScore = b.score.total.compareTo(a.score.total);
    if (byScore != 0) return byScore;
    final byDate = b.product.createdAt.compareTo(a.product.createdAt);
    if (byDate != 0) return byDate;
    return a.product.id.compareTo(b.product.id);
  });

  final out = <ScoredProduct>[];
  var fromSeller = 0;
  for (final s in scored) {
    if (out.length >= limit) break;
    if (s.isFromSameSeller) {
      if (fromSeller >= maxFromSameSeller) continue;
      fromSeller++;
    }
    out.add(s);
  }
  return out;
}

List<String> brandQueryVariants(String rawBrand) {
  final trimmed = rawBrand.trim();
  if (trimmed.isEmpty) return const [];
  final lower = trimmed.toLowerCase();
  final capitalised = lower.length == 1
      ? lower.toUpperCase()
      : lower[0].toUpperCase() + lower.substring(1);
  final out = <String>[];
  for (final v in [trimmed, lower, capitalised]) {
    if (v.isNotEmpty && !out.contains(v)) out.add(v);
  }
  return out;
}
