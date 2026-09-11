import 'package:flutter_test/flutter_test.dart';
import 'package:secondhand_marketplace/core/services/personalization_scorer.dart';
import 'package:secondhand_marketplace/shared/models/product_model.dart';

ProductModel _product({String? brand}) => ProductModel.fromMap({
  'sellerId': 'seller-1',
  'title': 'אייפון 13',
  'price': 2500,
  'city': 'תל אביב',
  'category': 'electronics',
  'brand': brand,
}, 'p1');

TasteProfileV2 _profileWithBrands(Map<String, double> brands) => TasteProfileV2(
  version: 2,
  categoryWeights: const {},
  brandWeights: brands,
  sellerWeights: const {},
  priceBandWeights: const {},
  recentSearches: const [],
  cartAdds: const [],
  totalSignals: 40,
);

void main() {
  group('brandKeyOf', () {
    test('folds case and surrounding whitespace', () {
      expect(brandKeyOf('Apple'), 'apple');
      expect(brandKeyOf('  APPLE '), 'apple');
      expect(brandKeyOf('apple'), 'apple');
    });

    test('folds repeated inner whitespace, so "new  balance" is one brand', () {
      expect(brandKeyOf('New  Balance'), brandKeyOf('new balance'));
    });

    test('leaves a Hebrew brand alone apart from trimming', () {
      expect(brandKeyOf(' רהיטי בן-דוד '), 'רהיטי בן-דוד');
    });
  });

  group('brandWeightFor', () {
    test('scores a legacy display-cased listing against a folded key', () {
      final scorer = PersonalizationScorer(_profileWithBrands({'apple': 40}));
      expect(scorer.brandWeightFor(_product(brand: 'Apple')), 1.0);
      expect(scorer.brandWeightFor(_product(brand: 'apple')), 1.0);
    });

    test('a brand-less product still scores zero, not a crash', () {
      final scorer = PersonalizationScorer(_profileWithBrands({'apple': 40}));
      expect(scorer.brandWeightFor(_product()), 0.0);
    });

    test('an unknown brand scores zero', () {
      final scorer = PersonalizationScorer(_profileWithBrands({'apple': 40}));
      expect(scorer.brandWeightFor(_product(brand: 'Samsung')), 0.0);
    });
  });

  group('parseWeightMap — the fold TasteProfileV2.fromDoc applies', () {
    test('two spellings sum instead of one overwriting the other', () {
      final folded = parseWeightMap(<String, dynamic>{
        'Apple': 24.75,
        'apple': 16.22,
        'Samsung': 8.0,
      }, keyOf: brandKeyOf);
      expect(folded.keys.toSet(), {'apple', 'samsung'});
      expect(folded['apple'], closeTo(40.97, 1e-9));
      expect(folded['apple'], greaterThan(24.75));
    });

    test('the folded max is what the brand term normalises against', () {
      final split = _profileWithBrands(
        parseWeightMap(<String, dynamic>{
          'Apple': 24.75,
          'apple': 16.22,
        }, keyOf: brandKeyOf),
      );
      final halved = _profileWithBrands({'apple': 16.22, 'samsung': 40.0});
      expect(
        PersonalizationScorer(split).brandWeightFor(_product(brand: 'Apple')),
        1.0,
      );
      expect(
        PersonalizationScorer(halved).brandWeightFor(_product(brand: 'Apple')),
        lessThan(1.0),
      );
    });

    test('a non-numeric or unreadable entry is skipped, not read as zero', () {
      final folded = parseWeightMap(<String, dynamic>{
        'apple': 12.0,
        'lg': 'nonsense',
        '   ': 5.0,
      }, keyOf: brandKeyOf);
      expect(folded, {'apple': 12.0});
      expect(parseWeightMap(null), isEmpty);
      expect(parseWeightMap('not a map'), isEmpty);
    });
  });
}
