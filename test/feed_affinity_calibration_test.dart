import 'package:flutter_test/flutter_test.dart';
import 'package:secondhand_marketplace/core/services/personalization_scorer.dart';
import 'package:secondhand_marketplace/shared/models/feed_composition.dart';
import 'package:secondhand_marketplace/shared/models/feed_signals.dart';
import 'package:secondhand_marketplace/shared/models/product_model.dart';

ProductModel _product({
  String id = 'p1',
  String sellerId = 'seller-1',
  String category = 'electronics',
  String? brand,
  double price = 2500,
}) => ProductModel.fromMap({
  'sellerId': sellerId,
  'title': 'אייפון 13',
  'price': price,
  'city': 'תל אביב',
  'category': category,
  'brand': brand,
}, id);

TasteProfileV2 _profile({
  Map<String, double> categories = const {},
  Map<String, double> brands = const {},
  Map<String, double> sellers = const {},
  Map<String, double> priceBands = const {},
}) => TasteProfileV2(
  version: 2,
  categoryWeights: categories,
  brandWeights: brands,
  sellerWeights: sellers,
  priceBandWeights: priceBands,
  recentSearches: const [],
  cartAdds: const [],
  totalSignals: 40,
);

void main() {
  group('the affinity handed to the composer is on the composer\'s scale', () {
    test('the raw score CANNOT reach the primary threshold on its own', () {
      expect(
        PersonalizationScorer.kWeightedTermsCeilingNoRegion,
        lessThan(const FeedRecipe().primaryAffinityThreshold),
      );
      expect(
        PersonalizationScorer.kWeightedTermsCeilingWithRegion,
        lessThan(const FeedRecipe().primaryAffinityThreshold),
      );
    });

    test('a viewer\'s STRONGEST possible match claims a primary slot', () {
      final scorer = PersonalizationScorer(
        _profile(
          categories: {'electronics': 40},
          brands: {'apple': 40},
          sellers: {'seller-1': 40},
          priceBands: {priceBandOf(2500): 40},
        ),
      );
      final perfect = _product(brand: 'Apple');

      expect(
        scorer.affinityFor(perfect),
        lessThan(const FeedRecipe().primaryAffinityThreshold),
        reason: 'the raw score is the bug this rescale exists for',
      );
      expect(
        scorer.compositionAffinityFor(perfect),
        greaterThanOrEqualTo(const FeedRecipe().primaryAffinityThreshold),
      );

      final buckets = bucketize([
        FeedCandidate<String>(
          item: 'perfect',
          affinity: scorer.compositionAffinityFor(perfect),
        ),
      ], const FeedRecipe());
      expect(buckets[FeedSlot.primary]!.map((c) => c.item), ['perfect']);
    });

    test('a WEAK match still does not, so secondary keeps its job', () {
      final scorer = PersonalizationScorer(
        _profile(
          categories: {'electronics': 40, 'fashion': 4},
          priceBands: {priceBandOf(2500): 40, priceBandOf(80): 3},
        ),
      );
      final weak = _product(category: 'fashion', price: 80);
      final a = scorer.compositionAffinityFor(weak);

      expect(a, greaterThan(0), reason: 'some signal is not no signal');
      expect(a, lessThan(const FeedRecipe().primaryAffinityThreshold));

      final buckets = bucketize([
        FeedCandidate<String>(item: 'weak', affinity: a),
      ], const FeedRecipe());
      expect(buckets[FeedSlot.secondary]!.map((c) => c.item), ['weak']);
    });

    test('no signal stays exactly 0, so it stays discoverable', () {
      final scorer = PersonalizationScorer(_profile(categories: {'jobs': 40}));
      expect(
        scorer.compositionAffinityFor(_product(category: 'vehicles')),
        0.0,
      );
    });

    test('an empty profile does not divide by zero or produce NaN', () {
      final scorer = PersonalizationScorer(TasteProfileV2.empty());
      final a = scorer.compositionAffinityFor(_product(brand: 'Apple'));
      expect(a.isNaN, isFalse);
      expect(a, 0.0);
    });

    test('is monotone in the raw score and never leaves 0..1', () {
      final scorer = PersonalizationScorer(
        _profile(
          categories: {'electronics': 40},
          brands: {'apple': 40},
          priceBands: {priceBandOf(2500): 40},
        ),
      );
      final better = _product(brand: 'Apple');
      final worse = _product(brand: 'Samsung');
      expect(
        scorer.affinityFor(better),
        greaterThan(scorer.affinityFor(worse)),
      );
      expect(
        scorer.compositionAffinityFor(better),
        greaterThan(scorer.compositionAffinityFor(worse)),
      );
      for (final p in [better, worse, _product(category: 'jobs', price: 5)]) {
        expect(scorer.compositionAffinityFor(p), inInclusiveRange(0.0, 1.0));
      }
    });
  });

  group('ties are broken by freshness, not by luck', () {
    test('Dart\'s sort really is unstable, which is why this exists', () {
      final input = [for (var i = 0; i < 60; i++) i];
      final sorted = [...input]..sort((a, b) => 0);
      expect(
        sorted,
        isNot(equals(input)),
        reason:
            'if this ever fails, sort became stable — the tie-break is '
            'then redundant rather than wrong',
      );
    });

    test('the tie-break is strictly decreasing and never reaches 0', () {
      double previous = double.infinity;
      for (final d in [
        Duration.zero,
        const Duration(minutes: 1),
        const Duration(hours: 6),
        const Duration(days: 1),
        const Duration(days: 30),
        const Duration(days: 365),
        const Duration(days: 365 * 5),
      ]) {
        final v = freshnessTieBreak(d);
        expect(v, lessThan(previous), reason: 'not decreasing at $d');
        expect(v, greaterThan(0), reason: 'decayed to a tie at $d');
        previous = v;
      }
      expect(
        freshnessTieBreak(const Duration(days: -5)),
        kFreshnessTieBreak,
        reason: 'a clock-skewed future listing is capped, not boosted',
      );
    });

    test('it is too small to reorder anything that genuinely differs', () {
      expect(
        kFreshnessTieBreak,
        lessThan(const FeedRecipe().primaryAffinityThreshold / 1000),
      );
      expect(
        kFreshnessTieBreak,
        lessThan(const FeedRecipe().trendingThreshold / 1000),
      );
      const better = 0.60;
      const worse = 0.59;
      expect(
        better + freshnessTieBreak(const Duration(days: 365 * 5)),
        greaterThan(worse + freshnessTieBreak(Duration.zero)),
      );
    });

    test('an untrended bucket comes back newest-first, not shuffled', () {
      final ages = [for (var i = 0; i < 60; i++) Duration(hours: i)];
      final candidates = [
        for (var i = 0; i < ages.length; i++)
          FeedCandidate<String>(
            item: 'p$i',
            affinity: 0,
            trend: freshnessTieBreak(ages[i]),
          ),
      ];
      final buckets = bucketize(candidates, const FeedRecipe());
      expect(buckets[FeedSlot.discovery]!.map((c) => c.item).toList(), [
        for (var i = 0; i < ages.length; i++) 'p$i',
      ]);
    });

    test('real trend still outranks any tie-break', () {
      final fresh = FeedCandidate<String>(
        item: 'fresh-but-ignored',
        affinity: 0,
        trend: freshnessTieBreak(Duration.zero),
      );
      final moving = FeedCandidate<String>(
        item: 'old-but-moving',
        affinity: 0,
        trend: normalisedTrend(1, 1000),
      );
      final buckets = bucketize([fresh, moving], const FeedRecipe());
      expect(buckets[FeedSlot.discovery]!.first.item, 'old-but-moving');
    });
  });
}
