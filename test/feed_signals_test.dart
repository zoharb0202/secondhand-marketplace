import 'package:flutter_test/flutter_test.dart';
import 'package:secondhand_marketplace/shared/models/feed_composition.dart';
import 'package:secondhand_marketplace/shared/models/feed_signals.dart';

void main() {
  group('proximity is a decay, not a filter', () {
    test('no viewer location contributes NOTHING, not a flat penalty', () {
      expect(proximityMultiplier(null), 1.0);
      expect(affinityWithProximity(0.83, null), 0.83);
    });

    test('a listing with no real coordinates is not punished for it', () {
      expect(affinityWithProximity(0.4, null), 0.4);
    });

    test('is 1.0 at the doorstep and falls monotonically', () {
      expect(proximityMultiplier(0), 1.0);
      double previous = 1.0;
      for (final km in [0.5, 1.0, 2.0, 5.0, 8.0, 15.0, 40.0, 120.0]) {
        final m = proximityMultiplier(km);
        expect(m, lessThan(previous), reason: 'not monotone at $km km');
        previous = m;
      }
    });

    test('THE SAFETY BOUND: a far listing never loses more than the cap', () {
      expect(
        proximityMultiplier(20000),
        greaterThanOrEqualTo(1.0 - kPickupMaxDistancePenalty),
      );
    });

    test('a great match 40km away still beats a poor one nearby', () {
      final far = affinityWithProximity(0.9, 40);
      final near = affinityWithProximity(0.5, 0.2);
      expect(far, greaterThan(near));
    });

    test('but distance DOES break a tie', () {
      final near = affinityWithProximity(0.6, 1);
      final far = affinityWithProximity(0.6, 40);
      expect(near, greaterThan(far));
    });

    test('proximity is a modifier on interest, never a source of it', () {
      expect(affinityWithProximity(0, 0), 0.0);
    });

    test('nonsense distances degrade instead of poisoning the score', () {
      expect(proximityMultiplier(double.nan), 1.0);
      expect(proximityMultiplier(-5), 1.0);
      expect(affinityWithProximity(1.0, 0), 1.0);
    });
  });

  group('trend normalisation', () {
    test('maps the batch leader to 1 and everything else below it', () {
      expect(normalisedTrend(40, 40), 1.0);
      expect(normalisedTrend(10, 40), 0.25);
    });

    test('no trend data anywhere means no trending bucket, not a full one', () {
      expect(normalisedTrend(null, 0), 0.0);
      expect(normalisedTrend(0, 0), 0.0);
      expect(normalisedTrend(5, 0), 0.0);
    });

    test('a missing or negative score is 0, never negative', () {
      expect(normalisedTrend(null, 40), 0.0);
      expect(normalisedTrend(-3, 40), 0.0);
    });

    test('a score above the batch max clamps instead of exceeding 1', () {
      expect(normalisedTrend(60, 40), 1.0);
    });
  });

  group('cold start', () {
    test('newest first is preserved when there is no taste signal', () {
      double previous = double.infinity;
      for (var days = 0; days <= 40; days++) {
        final a = coldStartAffinity(Duration(days: days));
        expect(a, lessThan(previous), reason: 'not decreasing at $days days');
        expect(
          a,
          greaterThan(0),
          reason:
              'must stay > 0 so old stock stays ordered, not shuffled '
              'into the discovery bucket',
        );
        previous = a;
      }
    });

    test('never claims the primary bucket', () {
      const recipe = FeedRecipe();
      expect(
        coldStartAffinity(Duration.zero),
        lessThan(recipe.primaryAffinityThreshold),
      );
      expect(
        kColdStartAffinityCeiling,
        lessThan(recipe.primaryAffinityThreshold),
      );
    });

    test('a future-dated listing is capped, not boosted', () {
      expect(
        coldStartAffinity(const Duration(days: -30)),
        kColdStartAffinityCeiling,
      );
    });
  });

  group('the seller cap can end the walk early', () {
    List<FeedCandidate<String>> oneSellersStock(int n) => [
      for (var i = 0; i < n; i++)
        FeedCandidate<String>(
          item: 'p$i',
          affinity: 0.9 - i * 0.01,
          sellerKey: 'the-only-shop',
          categoryKey: 'c${i % 4}',
        ),
    ];

    test('one seller with a full pool is truncated under the default cap', () {
      final feed = composeFeed(oneSellersStock(20));
      expect(
        feed.length,
        lessThan(20),
        reason:
            'if this ever stops being true the completeness guard and '
            'the Following recipe are both dead weight — check before '
            'deleting either',
      );
    });

    test('lifting the cap to the window size returns everything', () {
      const recipe = FeedRecipe(maxPerSellerPerWindow: 10);
      expect(
        recipe.maxPerSellerPerWindow,
        greaterThanOrEqualTo(recipe.windowSize),
      );
      final feed = composeFeed(oneSellersStock(20), recipe: recipe);
      expect(feed.length, 20);
      expect(feed.toSet().length, 20, reason: 'no duplicates');
    });
  });
}
