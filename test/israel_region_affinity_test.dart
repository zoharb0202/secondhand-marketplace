import 'package:flutter_test/flutter_test.dart';
import 'package:secondhand_marketplace/core/constants/enums.dart';
import 'package:secondhand_marketplace/core/services/location_service.dart';
import 'package:secondhand_marketplace/core/services/personalization_scorer.dart';
import 'package:secondhand_marketplace/shared/models/feed_composition.dart';
import 'package:secondhand_marketplace/shared/models/feed_signals.dart';
import 'package:secondhand_marketplace/shared/models/israel_regions.dart';
import 'package:secondhand_marketplace/shared/models/product_model.dart';

ProductModel _product({
  String id = 'p1',
  String sellerId = 'seller-1',
  String category = 'electronics',
  String? brand,
  double price = 2500,
  String city = 'תל אביב',
}) => ProductModel.fromMap({
  'sellerId': sellerId,
  'title': 'מוצר',
  'price': price,
  'city': city,
  'category': category,
  'brand': brand,
}, id);

TasteProfileV2 _profile({
  Map<String, double> categories = const {},
  Map<String, double> brands = const {},
  Map<String, double> sellers = const {},
  Map<String, double> priceBands = const {},
  Map<String, double> regions = const {},
}) => TasteProfileV2(
  version: 2,
  categoryWeights: categories,
  brandWeights: brands,
  sellerWeights: sellers,
  priceBandWeights: priceBands,
  regionWeights: regions,
  recentSearches: const [],
  cartAdds: const [],
  totalSignals: 40,
);

void main() {
  group('taxonomy invariants', () {
    test('regionAdjacency: every IsraelRegion is a key, symmetric, no '
        'self-edge, and no region is isolated', () {
      for (final r in IsraelRegion.values) {
        expect(
          regionAdjacency.containsKey(r),
          isTrue,
          reason: '$r missing from regionAdjacency',
        );
        expect(
          regionAdjacency[r],
          isNot(contains(r)),
          reason: '$r is self-adjacent',
        );
        expect(
          regionAdjacency[r],
          isNotEmpty,
          reason:
              '$r is isolated — Israel is connected, no region should '
              'be (unlike ProductCategory.other)',
        );
      }
      for (final entry in regionAdjacency.entries) {
        for (final adj in entry.value) {
          expect(
            regionAdjacency[adj],
            contains(entry.key),
            reason: '${entry.key} -> $adj is not symmetric',
          );
        }
      }
    });

    test('categoryAdjacency: every ProductCategory is a key, symmetric, no '
        'self-edge, other is the one intentional exception', () {
      for (final c in ProductCategory.values) {
        expect(
          categoryAdjacency.containsKey(c),
          isTrue,
          reason: '$c missing from categoryAdjacency',
        );
        expect(
          categoryAdjacency[c],
          isNot(contains(c)),
          reason: '$c is self-adjacent',
        );
      }
      expect(categoryAdjacency[ProductCategory.other], isEmpty);
      for (final entry in categoryAdjacency.entries) {
        for (final adj in entry.value) {
          expect(
            categoryAdjacency[adj],
            contains(entry.key),
            reason: '${entry.key} -> $adj is not symmetric',
          );
        }
      }
    });
  });

  group('coverage cross-check — one taxonomy, not a fourth invented list', () {
    test(
      'every alias in regionCityAliases resolves back to its own region',
      () {
        regionCityAliases.forEach((region, names) {
          for (final name in names) {
            expect(
              israelRegionOf(name),
              region,
              reason: '"$name" should resolve to $region',
            );
          }
        });
      },
    );

    test('every LocationService centroid city resolves to a region', () {
      for (final name in LocationService.knownCityNames) {
        expect(
          israelRegionOf(name),
          isNotNull,
          reason:
              '"$name" (a LocationService centroid) has no region — '
              'the region table must be a superset of the centroid table',
        );
      }
    });
  });

  group('israelRegionOf matching discipline', () {
    test('null / empty / whitespace-only -> null', () {
      expect(israelRegionOf(null), isNull);
      expect(israelRegionOf(''), isNull);
      expect(israelRegionOf('   '), isNull);
    });

    test('exact city names resolve, Hebrew and English, with punctuation', () {
      expect(israelRegionOf('תל אביב-יפו'), IsraelRegion.gushDan);
      expect(israelRegionOf('Tel Aviv'), IsraelRegion.gushDan);
      expect(israelRegionOf('חיפה'), IsraelRegion.haifa);
    });

    test('direction words resolve via the tier-1 exact match', () {
      expect(israelRegionOf('המרכז'), IsraelRegion.gushDan);
      expect(israelRegionOf('הצפון'), IsraelRegion.north);
      expect(israelRegionOf('הדרום'), IsraelRegion.south);
    });

    test('THE TIER-2 TRAP: "צפון תל אביב" is gushDan, not north — naive '
        'substring matching against the direction words would get this '
        'backwards', () {
      expect(israelRegionOf('צפון תל אביב'), IsraelRegion.gushDan);
    });

    test('an unrecognised place returns null rather than guessing', () {
      expect(israelRegionOf('פריז'), isNull);
    });
  });

  test('foldCityWeightsToRegions SUMS same-region cities and DROPS cities '
      'the taxonomy does not recognise', () {
    final result = foldCityWeightsToRegions({
      'תל אביב': 10,
      'רמת גן': 5,
      'חיפה': 3,
      'פריז': 100,
    });
    expect(result, {IsraelRegion.gushDan.name: 15, IsraelRegion.haifa.name: 3});
  });

  group(
    'regionWeightFor — declared home region only (no behavioural signal)',
    () {
      test('own region scores 1.0', () {
        final scorer = PersonalizationScorer(
          TasteProfileV2.empty(),
          homeRegion: IsraelRegion.gushDan,
        );
        expect(scorer.regionWeightFor(_product(city: 'תל אביב')), 1.0);
      });

      test(
        'an adjacent region scores kAdjacentBorrow — the expanding radius',
        () {
          final scorer = PersonalizationScorer(
            TasteProfileV2.empty(),
            homeRegion: IsraelRegion.gushDan,
          );
          expect(
            scorer.regionWeightFor(_product(city: 'נתניה')),
            kAdjacentBorrow,
          );
        },
      );

      test(
        'two hops away scores 0.0 — single-hop only, like categoryAdjacency',
        () {
          final scorer = PersonalizationScorer(
            TasteProfileV2.empty(),
            homeRegion: IsraelRegion.gushDan,
          );
          expect(scorer.regionWeightFor(_product(city: 'נהריה')), 0.0);
        },
      );

      test('an unknown city scores 0.0 — no claim, either way', () {
        final scorer = PersonalizationScorer(
          TasteProfileV2.empty(),
          homeRegion: IsraelRegion.gushDan,
        );
        expect(scorer.regionWeightFor(_product(city: 'פריז')), 0.0);
      });
    },
  );

  test('regionWeightFor from BEHAVIOURAL signal alone (no homeRegion) mirrors '
      'catWeightFor\'s exact shape: direct wins, else kAdjacentBorrow x best '
      'adjacent, else 0', () {
    final scorer = PersonalizationScorer(
      _profile(regions: {IsraelRegion.gushDan.name: 40}),
    );
    expect(scorer.regionWeightFor(_product(city: 'תל אביב')), 1.0);
    expect(scorer.regionWeightFor(_product(city: 'נתניה')), kAdjacentBorrow);
    expect(scorer.regionWeightFor(_product(city: 'נהריה')), 0.0);
  });

  test('THE FLOOR IS A FLOOR: a strong behavioural signal for a region '
      'other than the declared home region still wins via max()', () {
    final scorer = PersonalizationScorer(
      _profile(regions: {IsraelRegion.gushDan.name: 40}),
      homeRegion: IsraelRegion.north,
    );
    expect(scorer.regionWeightFor(_product(city: 'תל אביב')), 1.0);
  });

  test('THE GATE: a listing in the buyer\'s home region with ZERO taste '
      'signal scores exactly 0.0, and stays in the discovery bucket — '
      'region MODIFIES affinity, it never CREATES it', () {
    final scorer = PersonalizationScorer(
      TasteProfileV2.empty(),
      homeRegion: IsraelRegion.gushDan,
    );
    final noSignalButInRegion = _product(city: 'תל אביב');

    final affinity = scorer.compositionAffinityFor(noSignalButInRegion);
    expect(affinity, 0.0);

    final buckets = bucketize([
      FeedCandidate<String>(item: 'p', affinity: affinity),
    ], const FeedRecipe());
    expect(buckets[FeedSlot.discovery]!.map((c) => c.item), ['p']);
  });

  group('THE DOMINANCE BOUND — region reorders ties, it cannot reorder '
      'relevance (the tasteProfile.js:61 warning, pinned as a number)', () {
    test('a top-category match OUT of region beats a same-region listing '
        'whose only other signal is a price band', () {
      final scorer = PersonalizationScorer(
        _profile(
          categories: {'electronics': 40},
          priceBands: {priceBandOf(80): 40},
          regions: {IsraelRegion.gushDan.name: 40},
        ),
        homeRegion: IsraelRegion.gushDan,
      );
      final categoryMatchOutOfRegion = _product(
        category: 'electronics',
        price: 2500,
        city: 'נהריה',
      );
      final priceOnlySameRegion = _product(
        category: 'jobs',
        price: 80,
        city: 'תל אביב',
      );

      expect(
        scorer.compositionAffinityFor(categoryMatchOutOfRegion),
        greaterThan(scorer.compositionAffinityFor(priceOnlySameRegion)),
      );
    });

    test('the maximum region-only contribution, on the composition scale, '
        'is exactly 1/weightedTermsMax (1/8 with the axis active)', () {
      final scorer = PersonalizationScorer(
        _profile(
          priceBands: {priceBandOf(80): 40},
          regions: {IsraelRegion.gushDan.name: 40},
        ),
        homeRegion: IsraelRegion.gushDan,
      );
      final inRegion = scorer.compositionAffinityFor(
        _product(category: 'jobs', price: 80, city: 'תל אביב'),
      );
      final outOfRegion = scorer.compositionAffinityFor(
        _product(category: 'jobs', price: 80, city: 'פריז'),
      );

      expect(
        inRegion - outOfRegion,
        closeTo(1 / scorer.weightedTermsMax, 1e-9),
      );
      expect(inRegion - outOfRegion, lessThanOrEqualTo(1 / 8));
    });

    test('combined with the EXISTING distance decay: a strong out-of-region '
        'match at 40km still beats a weak same-region one at the doorstep', () {
      final scorer = PersonalizationScorer(
        _profile(
          categories: {'electronics': 40},
          regions: {IsraelRegion.gushDan.name: 40},
        ),
        homeRegion: IsraelRegion.gushDan,
      );
      final strongOutOfRegion = _product(
        category: 'electronics',
        city: 'נהריה',
      );
      final weakSameRegion = _product(category: 'sports', city: 'תל אביב');

      final strongAtDistance = affinityWithProximity(
        scorer.compositionAffinityFor(strongOutOfRegion),
        40,
      );
      final weakAtDoorstep = affinityWithProximity(
        scorer.compositionAffinityFor(weakSameRegion),
        0,
      );
      expect(strongAtDistance, greaterThan(weakAtDoorstep));
    });
  });

  group('BACKWARD COMPATIBILITY — a viewer with no region signal is '
      'numerically unchanged by the region rewrite', () {
    test('the two published ceilings match their formulas and both stay '
        'under the primary threshold', () {
      expect(PersonalizationScorer.kWeightedTermsCeilingNoRegion, 7.0 / 18.0);
      expect(PersonalizationScorer.kWeightedTermsCeilingWithRegion, 8.0 / 19.0);
      expect(
        PersonalizationScorer.kWeightedTermsCeilingNoRegion,
        lessThan(const FeedRecipe().primaryAffinityThreshold),
      );
      expect(
        PersonalizationScorer.kWeightedTermsCeilingWithRegion,
        lessThan(const FeedRecipe().primaryAffinityThreshold),
      );
    });

    test('no homeRegion + no cities on the profile -> byte-identical to the '
        'previous formula', () {
      final scorer = PersonalizationScorer(
        _profile(
          categories: {'electronics': 40},
          brands: {'apple': 40},
          sellers: {'seller-1': 40},
          priceBands: {priceBandOf(2500): 40},
        ),
      );
      expect(scorer.regionAxisActive, isFalse);
      expect(scorer.weightedTermsMax, 7.0);
      expect(
        scorer.weightedTermsCeiling,
        PersonalizationScorer.kWeightedTermsCeilingNoRegion,
      );

      final perfect = _product(brand: 'Apple');
      expect(scorer.affinityFor(perfect), 7.0 / 18.0);
      expect(scorer.compositionAffinityFor(perfect), 1.0);
    });
  });

  group('no crash, no NaN', () {
    test('an empty profile with a homeRegion set stays sane', () {
      final scorer = PersonalizationScorer(
        TasteProfileV2.empty(),
        homeRegion: IsraelRegion.gushDan,
      );
      final a = scorer.affinityFor(_product());
      expect(a.isNaN, isFalse);
      expect(a, inInclusiveRange(0.0, 1.0));
    });

    test('a product with an empty city string does not crash', () {
      final scorer = PersonalizationScorer(
        _profile(regions: {IsraelRegion.gushDan.name: 40}),
        homeRegion: IsraelRegion.gushDan,
      );
      final product = ProductModel.fromMap({
        'sellerId': 's',
        'title': 'x',
        'price': 10,
        'city': '',
        'category': 'electronics',
      }, 'p-empty-city');

      final a = scorer.affinityFor(product);
      expect(a.isNaN, isFalse);
      expect(a, inInclusiveRange(0.0, 1.0));
    });
  });
}
