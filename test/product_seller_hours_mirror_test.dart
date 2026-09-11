import 'package:flutter_test/flutter_test.dart';
import 'package:secondhand_marketplace/shared/models/availability_window.dart';
import 'package:secondhand_marketplace/shared/models/product_model.dart';

Map<String, dynamic> _productData({Object? mirror, bool includeMirror = true}) {
  return {
    'sellerId': 'seller-1',
    'title': 'שולחן עץ',
    'price': 250,
    'city': 'תל אביב',
    if (includeMirror) kProductSellerHoursField: mirror,
  };
}

Map<String, dynamic> _window(int day, int startHour, int endHour) => {
  'dayOfWeek': day,
  'timeRange': {
    'startHour': startHour,
    'startMinute': 0,
    'endHour': endHour,
    'endMinute': 0,
  },
};

void main() {
  final sundayNoon = DateTime(2026, 8, 16, 12, 0);
  final sundayEvening = DateTime(2026, 8, 16, 20, 0);
  final mondayNoon = DateTime(2026, 8, 17, 12, 0);

  group('mirror decode: absent vs empty vs present', () {
    test('key absent → unknown, NOT "closed"', () {
      final p = ProductModel.fromMap(_productData(includeMirror: false), 'p1');

      expect(p.sellerAvailabilityWindows, isNull);
      expect(p.sellerIsOpenAt(sundayNoon), isNull);
    });

    test('key present but null → still unknown', () {
      final p = ProductModel.fromMap(_productData(mirror: null), 'p1');

      expect(p.sellerAvailabilityWindows, isNull);
      expect(p.sellerIsOpenAt(sundayNoon), isNull);
    });

    test('empty list → stamped, publishes no hours → false, not null', () {
      final p = ProductModel.fromMap(_productData(mirror: const []), 'p1');

      expect(p.sellerAvailabilityWindows, isEmpty);
      expect(p.sellerIsOpenAt(sundayNoon), isFalse);
    });

    test('non-list garbage → unknown rather than an invented empty week', () {
      final p = ProductModel.fromMap(_productData(mirror: 'open'), 'p1');

      expect(p.sellerAvailabilityWindows, isNull);
      expect(p.sellerIsOpenAt(sundayNoon), isNull);
    });
  });

  group('verdict comes from isOpenAt, on the mirrored week', () {
    test('inside a window → true; outside it, and on another day → false', () {
      final p = ProductModel.fromMap(
        _productData(mirror: [_window(1, 9, 17)]),
        'p1',
      );

      expect(p.sellerIsOpenAt(sundayNoon), isTrue);
      expect(p.sellerIsOpenAt(sundayEvening), isFalse);
      expect(p.sellerIsOpenAt(mondayNoon), isFalse);
    });

    test('the closing minute is already closed (shared isOpenAt boundary)', () {
      final p = ProductModel.fromMap(
        _productData(mirror: [_window(1, 9, 17)]),
        'p1',
      );

      expect(p.sellerIsOpenAt(DateTime(2026, 8, 16, 16, 59)), isTrue);
      expect(p.sellerIsOpenAt(DateTime(2026, 8, 16, 17, 0)), isFalse);
    });
  });

  group('tolerant parse — the same array arrives from two transports', () {
    test('a callable-decoded Map<Object?, Object?> entry still parses', () {
      final loose = <Object?, Object?>{
        'dayOfWeek': 1,
        'timeRange': <Object?, Object?>{
          'startHour': 9,
          'startMinute': 0,
          'endHour': 17,
          'endMinute': 0,
        },
      };
      final p = ProductModel.fromMap(_productData(mirror: [loose]), 'p1');

      expect(p.sellerAvailabilityWindows, hasLength(1));
      expect(p.sellerIsOpenAt(sundayNoon), isTrue);
    });

    test('JSON-widened numbers (9.0) still land on the right hour', () {
      final p = ProductModel.fromMap(
        _productData(
          mirror: [
            {
              'dayOfWeek': 1.0,
              'timeRange': {
                'startHour': 9.0,
                'startMinute': 0.0,
                'endHour': 17.0,
                'endMinute': 0.0,
              },
            },
          ],
        ),
        'p1',
      );

      expect(p.sellerIsOpenAt(sundayNoon), isTrue);
      expect(p.sellerIsOpenAt(sundayEvening), isFalse);
    });

    test('one bad entry does not blank out the rest of the week', () {
      final p = ProductModel.fromMap(
        _productData(mirror: ['nonsense', _window(1, 9, 17)]),
        'p1',
      );

      expect(p.sellerAvailabilityWindows, hasLength(1));
      expect(p.sellerIsOpenAt(sundayNoon), isTrue);
    });

    test('parseList and the product decode agree on the same bytes', () {
      final raw = [_window(1, 9, 17), _window(3, 8, 12)];
      final viaOrigin = AvailabilityWindow.parseList(raw);
      final viaMirror = ProductModel.fromMap(
        _productData(mirror: raw),
        'p1',
      ).sellerAvailabilityWindows!;

      expect(
        viaMirror.map((w) => w.toMap()).toList(),
        viaOrigin.map((w) => w.toMap()).toList(),
      );
    });
  });

  group('write side', () {
    test('unknown hours OMIT the key rather than writing null', () {
      final p = ProductModel.fromMap(_productData(includeMirror: false), 'p1');

      expect(p.toFirestore().containsKey(kProductSellerHoursField), isFalse);
    });

    test('a stamped empty week is written, and stays distinguishable', () {
      final p = ProductModel.fromMap(_productData(mirror: const []), 'p1');
      final written = p.toFirestore();

      expect(written[kProductSellerHoursField], isEmpty);
      expect(
        ProductModel.fromMap(written, 'p1').sellerIsOpenAt(sundayNoon),
        isFalse,
      );
    });

    test('a real week round-trips through toFirestore unchanged', () {
      final p = ProductModel.fromMap(
        _productData(mirror: [_window(1, 9, 17)]),
        'p1',
      );
      final again = ProductModel.fromMap(p.toFirestore(), 'p1');

      expect(again.sellerIsOpenAt(sundayNoon), isTrue);
      expect(again.sellerIsOpenAt(mondayNoon), isFalse);
    });
  });
}
