library;

import 'dart:math' as math;

const int kProductGeohashPrecision = 9;

class GeoBoundingBox {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  const GeoBoundingBox({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  @override
  String toString() => 'GeoBoundingBox($minLat..$maxLat, $minLng..$maxLng)';
}

class GeoHash {
  GeoHash._();

  static const String base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  static const int maxPrecision = 12;

  static const double _earthRadiusM = 6371000.0;

  static const double _boxSafetyMarginM = 50.0;

  static String encode(
    double latitude,
    double longitude, {
    int precision = kProductGeohashPrecision,
  }) {
    final p = precision.clamp(1, maxPrecision);
    var lat = latitude.clamp(-90.0, 90.0).toDouble();
    var lng = longitude.clamp(-180.0, 180.0).toDouble();
    if (lat.isNaN) lat = 0;
    if (lng.isNaN) lng = 0;

    var latMin = -90.0, latMax = 90.0;
    var lngMin = -180.0, lngMax = 180.0;

    final out = StringBuffer();
    var isLng = true;
    var bits = 0;
    var value = 0;

    while (out.length < p) {
      if (isLng) {
        final mid = (lngMin + lngMax) / 2;
        if (lng >= mid) {
          value = value * 2 + 1;
          lngMin = mid;
        } else {
          value = value * 2;
          lngMax = mid;
        }
      } else {
        final mid = (latMin + latMax) / 2;
        if (lat >= mid) {
          value = value * 2 + 1;
          latMin = mid;
        } else {
          value = value * 2;
          latMax = mid;
        }
      }
      isLng = !isLng;
      if (++bits == 5) {
        out.write(base32[value]);
        bits = 0;
        value = 0;
      }
    }
    return out.toString();
  }

  static String prefixEnd(String prefix) => '$prefix~';

  static int _latBits(int precision) => (5 * precision) ~/ 2;
  static int _lngBits(int precision) => (5 * precision + 1) ~/ 2;

  static double cellLatDegrees(int precision) =>
      180.0 / (1 << _latBits(precision));

  static double cellLngDegrees(int precision) =>
      360.0 / (1 << _lngBits(precision));

  static GeoBoundingBox boundingBox({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) {
    final lat = latitude.isNaN ? 0.0 : latitude.clamp(-90.0, 90.0).toDouble();
    final lng = longitude.isNaN
        ? 0.0
        : longitude.clamp(-180.0, 180.0).toDouble();

    final radiusM = math.max(radiusKm, 0.0) * 1000.0 + _boxSafetyMarginM;

    final delta = radiusM / _earthRadiusM;
    if (!delta.isFinite || delta >= math.pi / 2) {
      return const GeoBoundingBox(
        minLat: -90.0,
        maxLat: 90.0,
        minLng: -180.0,
        maxLng: 180.0,
      );
    }

    final latDelta = delta * 180.0 / math.pi;
    final minLat = (lat - latDelta).clamp(-90.0, 90.0).toDouble();
    final maxLat = (lat + latDelta).clamp(-90.0, 90.0).toDouble();

    final cosLat = math.cos(lat * math.pi / 180.0).abs();
    final sinRatio = math.sin(delta) / cosLat;
    if (!sinRatio.isFinite || sinRatio >= 1.0) {
      return GeoBoundingBox(
        minLat: minLat,
        maxLat: maxLat,
        minLng: -180.0,
        maxLng: 180.0,
      );
    }
    final lngDelta = math.asin(sinRatio) * 180.0 / math.pi;

    if (lngDelta >= 180.0) {
      return GeoBoundingBox(
        minLat: minLat,
        maxLat: maxLat,
        minLng: -180.0,
        maxLng: 180.0,
      );
    }

    final rawMin = lng - lngDelta;
    final rawMax = lng + lngDelta;
    if (rawMin < -180.0 || rawMax > 180.0) {
      return GeoBoundingBox(
        minLat: minLat,
        maxLat: maxLat,
        minLng: -180.0,
        maxLng: 180.0,
      );
    }

    return GeoBoundingBox(
      minLat: minLat,
      maxLat: maxLat,
      minLng: rawMin,
      maxLng: rawMax,
    );
  }

  static int cellCountFor(GeoBoundingBox box, int precision) {
    final latStep = cellLatDegrees(precision);
    final lngStep = cellLngDegrees(precision);
    final latCells =
        ((box.maxLat + 90.0) / latStep).floor() -
        ((box.minLat + 90.0) / latStep).floor() +
        1;
    final lngCells =
        ((box.maxLng + 180.0) / lngStep).floor() -
        ((box.minLng + 180.0) / lngStep).floor() +
        1;
    return latCells * lngCells;
  }

  static List<String> coveringPrefixes(
    GeoBoundingBox box, {
    int maxCells = 12,
    int minPrecision = 1,
    int maxPrecisionHint = 8,
  }) {
    final budget = math.max(maxCells, 1);
    final hi = maxPrecisionHint.clamp(1, maxPrecision);
    final lo = minPrecision.clamp(1, hi);

    List<String>? fittingAt(int p) {
      if (cellCountFor(box, p) > budget) return null;
      final prefixes = prefixesAt(box, p);
      return prefixes.length <= budget ? prefixes : null;
    }

    for (var p = hi; p >= lo; p--) {
      final prefixes = fittingAt(p);
      if (prefixes != null) return prefixes;
    }
    for (var p = lo - 1; p >= 1; p--) {
      final prefixes = fittingAt(p);
      if (prefixes != null) return prefixes;
    }

    return const <String>[''];
  }

  static List<String> prefixesAt(GeoBoundingBox box, int precision) {
    final p = precision.clamp(1, maxPrecision);
    final latStep = cellLatDegrees(p);
    final lngStep = cellLngDegrees(p);
    final latCount = 1 << _latBits(p);
    final lngCount = 1 << _lngBits(p);

    int latIndex(double lat) =>
        (((lat + 90.0) / latStep).floor()).clamp(0, latCount - 1);
    int lngIndex(double lng) =>
        (((lng + 180.0) / lngStep).floor()).clamp(0, lngCount - 1);

    final iLatMin = latIndex(box.minLat);
    final iLatMax = latIndex(box.maxLat);
    final iLngMin = lngIndex(box.minLng);
    final iLngMax = lngIndex(box.maxLng);

    final out = <String>[];
    final seen = <String>{};
    for (var iLat = iLatMin; iLat <= iLatMax; iLat++) {
      final centreLat = -90.0 + (iLat + 0.5) * latStep;
      for (var iLng = iLngMin; iLng <= iLngMax; iLng++) {
        final centreLng = -180.0 + (iLng + 0.5) * lngStep;
        final hash = encode(centreLat, centreLng, precision: p);
        if (seen.add(hash)) out.add(hash);
      }
    }
    return out;
  }
}
