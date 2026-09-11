import 'package:flutter_test/flutter_test.dart';
import 'package:secondhand_marketplace/shared/models/feed_composition.dart';

FeedCandidate<String> c(
  String id, {
  double affinity = 0,
  double trend = 0,
  String? cat,
  String? brand,
  String? seller,
}) => FeedCandidate<String>(
  item: id,
  affinity: affinity,
  trend: trend,
  categoryKey: cat,
  brandKey: brand,
  sellerKey: seller,
);

void main() {
  group('the blocked-feed complaint', () {
    test('does NOT show every iPhone, then every trainer, then every TV', () {
      final candidates = [
        for (var i = 0; i < 4; i++)
          c('phone$i', affinity: 0.9, cat: 'electronics', brand: 'Apple'),
        for (var i = 0; i < 3; i++)
          c('shoe$i', affinity: 0.6, cat: 'fashion', brand: 'Jordan'),
        for (var i = 0; i < 2; i++)
          c('tv$i', affinity: 0.55, cat: 'electronics', brand: 'LG'),
      ];

      final feed = composeFeed(candidates);

      for (var i = 0; i + 2 < feed.length; i++) {
        final brands = [feed[i], feed[i + 1], feed[i + 2]]
            .map((id) => candidates.firstWhere((x) => x.item == id).brandKey)
            .toSet();
        expect(
          brands.length,
          greaterThan(1),
          reason:
              'three in a row from the same brand at index $i: '
              '${feed.sublist(i, i + 3)}',
        );
      }
      expect(feed.length, candidates.length, reason: 'nothing may be dropped');
      expect(feed.toSet().length, feed.length, reason: 'no duplicates');
    });

    test('the strongest interest still leads', () {
      final candidates = [
        for (var i = 0; i < 6; i++)
          c('phone$i', affinity: 0.9, cat: 'electronics', brand: 'Apple'),
        for (var i = 0; i < 6; i++)
          c('misc$i', affinity: 0.1, cat: 'other', brand: 'B$i'),
      ];
      final feed = composeFeed(candidates, limit: 5);
      final phones = feed.where((id) => id.startsWith('phone')).length;
      expect(
        phones,
        greaterThanOrEqualTo(3),
        reason: 'the top interest should dominate the opening screen',
      );
    });
  });

  group('discovery', () {
    test('reserves a slot even when the viewer has strong interests', () {
      final candidates = [
        for (var i = 0; i < 20; i++)
          c('known$i', affinity: 0.9, cat: 'electronics', brand: 'b$i'),
        for (var i = 0; i < 3; i++) c('new$i', affinity: 0, cat: 'x$i'),
      ];
      final feed = composeFeed(candidates, limit: 10);
      expect(
        feed.where((id) => id.startsWith('new')).isNotEmpty,
        isTrue,
        reason: 'a full window must contain at least one discovery item',
      );
    });
  });

  group('trending', () {
    test('appears without crowding out personal interest', () {
      final candidates = [
        for (var i = 0; i < 6; i++)
          c('hot$i', affinity: 0.1, trend: 0.9, cat: 't$i'),
        for (var i = 0; i < 6; i++)
          c('mine$i', affinity: 0.9, cat: 'electronics', brand: 'b$i'),
      ];
      final feed = composeFeed(candidates, limit: 10);
      expect(
        feed.where((id) => id.startsWith('hot')).length,
        greaterThanOrEqualTo(2),
      );
      expect(
        feed.where((id) => id.startsWith('mine')).length,
        greaterThanOrEqualTo(3),
      );
    });
  });

  group('seller spread', () {
    test('one seller cannot own a window', () {
      final candidates = [
        for (var i = 0; i < 12; i++)
          c(
            'big$i',
            affinity: 0.9,
            cat: 'electronics',
            brand: 'b$i',
            seller: 'bigshop',
          ),
        for (var i = 0; i < 6; i++)
          c(
            'small$i',
            affinity: 0.8,
            cat: 'fashion',
            brand: 'x$i',
            seller: 'shop$i',
          ),
      ];
      final feed = composeFeed(candidates, limit: 10);
      final fromBig = feed.where((id) => id.startsWith('big')).length;
      expect(
        fromBig,
        lessThanOrEqualTo(3),
        reason: 'the per-window seller cap is 3',
      );
    });
  });

  group('degenerate inputs', () {
    test('empty in, empty out', () {
      expect(composeFeed<String>(const []), isEmpty);
    });

    test('a single candidate is returned, not dropped', () {
      expect(composeFeed([c('only', affinity: 0.9)]), ['only']);
    });

    test('everything from one category and brand still returns everything', () {
      final candidates = [
        for (var i = 0; i < 7; i++)
          c('x$i', affinity: 0.9, cat: 'electronics', brand: 'Apple'),
      ];
      final feed = composeFeed(candidates);
      expect(feed.length, 7);
      expect(feed.toSet().length, 7);
    });

    test('unknown keys never count as a repeat', () {
      final candidates = [for (var i = 0; i < 6; i++) c('n$i', affinity: 0.9)];
      expect(composeFeed(candidates).length, 6);
    });

    test('limit is honoured and never exceeds what exists', () {
      final candidates = [for (var i = 0; i < 3; i++) c('n$i', affinity: 0.9)];
      expect(composeFeed(candidates, limit: 10).length, 3);
      expect(composeFeed(candidates, limit: 2).length, 2);
    });
  });

  group('bucketize', () {
    test('claims trending before interest', () {
      final b = bucketize([
        c('b', affinity: 0.9, trend: 0.9),
        c('c', affinity: 0.9),
        c('d', affinity: 0.2),
        c('e'),
      ], const FeedRecipe());

      expect(b[FeedSlot.trending]!.single.item, 'b');
      expect(b[FeedSlot.primary]!.single.item, 'c');
      expect(b[FeedSlot.secondary]!.single.item, 'd');
      expect(b[FeedSlot.discovery]!.single.item, 'e');
    });
  });
}
