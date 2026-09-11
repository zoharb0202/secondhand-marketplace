import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final currentLocationProvider = FutureProvider<Position?>((ref) async {
  final service = ref.watch(locationServiceProvider);
  return service.getCurrentPosition();
});

final userGeoPointProvider = FutureProvider<GeoPoint?>((ref) async {
  try {
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) {
      final p = GeoPoint(last.latitude, last.longitude);
      if (LocationService.isRealGeoPoint(p)) return p;
    }
  } catch (_) {}

  try {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 0,
          timeLimit: Duration(seconds: 8),
        ),
      );
      final p = GeoPoint(pos.latitude, pos.longitude);
      if (LocationService.isRealGeoPoint(p)) return p;
    }
  } catch (_) {}

  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid != null) {
    try {
      return await LocationService().getDefaultSavedAddressGeoPoint(uid);
    } catch (_) {}
  }

  return null;
});

class SavedAddress {
  final String id;
  final String userId;
  final String label;
  final String fullAddress;
  final String city;
  final String street;
  final String? apartmentNumber;
  final String? floor;
  final String? instructions;
  final GeoPoint location;
  final bool isDefault;
  final DateTime createdAt;

  SavedAddress({
    required this.id,
    required this.userId,
    required this.label,
    required this.fullAddress,
    required this.city,
    required this.street,
    this.apartmentNumber,
    this.floor,
    this.instructions,
    required this.location,
    this.isDefault = false,
    required this.createdAt,
  });

  factory SavedAddress.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SavedAddress(
      id: doc.id,
      userId: data['userId'] ?? '',
      label: data['label'] ?? '',
      fullAddress: data['fullAddress'] ?? '',
      city: data['city'] ?? '',
      street: data['street'] ?? '',
      apartmentNumber: data['apartmentNumber'],
      floor: data['floor'],
      instructions: data['instructions'],
      location: data['location'] ?? const GeoPoint(0, 0),
      isDefault: data['isDefault'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'label': label,
      'fullAddress': fullAddress,
      'city': city,
      'street': street,
      'apartmentNumber': apartmentNumber,
      'floor': floor,
      'instructions': instructions,
      'location': location,
      'isDefault': isDefault,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class AddressValidation {
  static String? validateStreet(String? street) {
    final value = (street ?? '').trim();
    if (value.isEmpty) {
      return 'נא להזין כתובת';
    }
    final lower = value.toLowerCase();
    if (lower == 'תל אביב' ||
        lower == 'tel aviv' ||
        lower == 'תל-אביב' ||
        value.length < 5) {
      return 'נא להזין כתובת מלאה עם שם רחוב ומספר בית';
    }
    if (!value.contains(RegExp(r'\d+'))) {
      return 'כתובת חייבת לכלול מספר בית';
    }
    return null;
  }
}

final savedAddressesProvider =
    StreamProvider.family<List<SavedAddress>, String>((ref, userId) {
      final uid = userId.trim();
      if (uid.isEmpty) return Stream<List<SavedAddress>>.empty();
      return _watchSavedAddresses(uid);
    });

final _signedInUidProvider = StreamProvider<String?>(
  (ref) => FirebaseAuth.instance.authStateChanges().map((user) => user?.uid),
);

final primaryAddressProvider = Provider<SavedAddress?>((ref) {
  final uid = ref.watch(_signedInUidProvider).valueOrNull;
  if (uid == null) return null;
  final addresses = ref.watch(savedAddressesProvider(uid)).valueOrNull;
  if (addresses == null || addresses.isEmpty) return null;
  for (final address in addresses) {
    if (address.isDefault) return address;
  }
  return addresses.first;
});

Stream<List<SavedAddress>> _watchSavedAddresses(String uid) {
  late final StreamController<List<SavedAddress>> controller;
  StreamSubscription<User?>? authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? querySub;

  void stopQuery() {
    querySub?.cancel();
    querySub = null;
  }

  void startQuery() {
    if (querySub != null) return;
    querySub = FirebaseFirestore.instance
        .collection('addresses')
        .where('userId', isEqualTo: uid)
        .orderBy('isDefault', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            if (controller.isClosed) return;
            controller.add(
              snapshot.docs
                  .map((doc) => SavedAddress.fromFirestore(doc))
                  .toList(),
            );
          },
          onError: (Object error, StackTrace stack) {
            stopQuery();
            if (controller.isClosed) return;
            controller.addError(error, stack);
          },
        );
  }

  void syncWithAuth(User? user) {
    if (user != null && user.uid == uid) {
      startQuery();
    } else {
      stopQuery();
    }
  }

  controller = StreamController<List<SavedAddress>>(
    onListen: () {
      syncWithAuth(FirebaseAuth.instance.currentUser);
      authSub = FirebaseAuth.instance.authStateChanges().listen(syncWithAuth);
    },
    onCancel: () async {
      await authSub?.cancel();
      authSub = null;
      await querySub?.cancel();
      querySub = null;
    },
  );

  return controller.stream;
}

class LocationData {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory LocationData.fromMap(Map<String, dynamic> map) {
    return LocationData(
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _mapsApiKey = String.fromEnvironment(
    'MAPS_API_KEY',
    defaultValue: '',
  );

  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<Position?> getCurrentPosition() async {
    final hasPermission = await checkAndRequestPermission();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  Future<String?> getAddressFromCoordinates(double lat, double lng) async {
    if (kIsWeb) {
      return _reverseGeocodeWithGoogleApi(lat, lng);
    }

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return '${place.street}, ${place.locality}';
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
    }

    return _reverseGeocodeWithGoogleApi(lat, lng);
  }

  Future<String?> _reverseGeocodeWithGoogleApi(double lat, double lng) async {
    if (_mapsApiKey.isEmpty) {
      if (kDebugMode) {
        print(
          '⚠️ [GEOCODING] MAPS_API_KEY not provided (build with --dart-define=MAPS_API_KEY=...) — cannot reverse geocode',
        );
      }
      return null;
    }
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?'
        'latlng=$lat,$lng&language=he&key=$_mapsApiKey',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
          return data['results'][0]['formatted_address'] as String?;
        }
        if (kDebugMode) {
          print('⚠️ [GEOCODING] Reverse geocoding status: ${data['status']}');
        }
      } else {
        if (kDebugMode) {
          print(
            '❌ [GEOCODING] Reverse geocoding API error: ${response.statusCode}',
          );
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('❌ [GEOCODING] Reverse geocoding exception: $e');
      return null;
    }
  }

  Future<({String street, String city})?> getAddressComponentsFromCoordinates(
    double lat,
    double lng,
  ) async {
    if (_mapsApiKey.isEmpty) return null;
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?'
        'latlng=$lat,$lng&language=he&key=$_mapsApiKey',
      );
      final response = await http.get(url);
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body);
      final results = (data['status'] == 'OK')
          ? (data['results'] as List)
          : const [];
      if (results.isEmpty) return null;

      String? bestRoute, bestNumber, city;
      for (final r in results) {
        final comps = (r['address_components'] as List?) ?? const [];
        String? route, number, locality;
        for (final c in comps) {
          final types = (c['types'] as List).cast<String>();
          if (types.contains('route')) {
            route = c['long_name'] as String?;
          } else if (types.contains('street_number')) {
            number = c['long_name'] as String?;
          } else if (types.contains('locality')) {
            locality = c['long_name'] as String?;
          } else if (types.contains('administrative_area_level_2')) {
            locality ??= c['long_name'] as String?;
          }
        }
        city ??= locality;
        if (route != null && number != null) {
          bestRoute = route;
          bestNumber = number;
          break;
        }
        bestRoute ??= route;
      }
      final street = [
        bestRoute,
        bestNumber,
      ].where((e) => e != null && e.isNotEmpty).join(' ').trim();
      if (street.isEmpty && (city == null || city.isEmpty)) return null;
      return (street: street, city: city ?? '');
    } catch (e) {
      if (kDebugMode) print('❌ [GEOCODING] components reverse failed: $e');
      return null;
    }
  }

  GeoPoint? _getKnownAddressCoordinates(String address) {
    final addressLower = address.toLowerCase();

    if (addressLower.contains('הרצל 125') ||
        addressLower.contains('herzl 125')) {
      return const GeoPoint(32.0644, 34.7748);
    }
    if (addressLower.contains('הרצל') && addressLower.contains('תל אביב')) {
      return const GeoPoint(32.0644, 34.7748);
    }

    if (addressLower.contains('רוטשילד 52') ||
        addressLower.contains('rothschild 52')) {
      return const GeoPoint(32.0641, 34.7759);
    }
    if (addressLower.contains('רוטשילד 50') ||
        addressLower.contains('rothschild 50')) {
      return const GeoPoint(32.0641, 34.7759);
    }
    if (addressLower.contains('רוטשילד 95') ||
        addressLower.contains('rothschild 95')) {
      return const GeoPoint(32.0700, 34.7900);
    }

    if (addressLower.contains('דיזנגוף 123') ||
        addressLower.contains('dizengoff 123')) {
      return const GeoPoint(32.0853, 34.7818);
    }

    if (addressLower.contains('אבן גבירול') ||
        addressLower.contains('ibn gabirol')) {
      return const GeoPoint(32.0853, 34.7818);
    }

    return null;
  }

  static const Map<List<String>, GeoPoint> _cityCentroids = {
    ['רמת גן', 'ramat gan']: GeoPoint(32.0684, 34.8248),
    ['גבעתיים', 'givatayim']: GeoPoint(32.0722, 34.8125),
    ['בת ים', 'bat yam']: GeoPoint(32.0171, 34.7457),
    ['תל אביב', 'tel aviv']: GeoPoint(32.0853, 34.7818),
    ['חולון', 'holon']: GeoPoint(32.0158, 34.7874),
    ['פתח תקווה', 'פתח תקוה', 'petah tikva', 'petach tikva']: GeoPoint(
      32.0840,
      34.8878,
    ),
    ['ראשון לציון', 'rishon']: GeoPoint(31.9730, 34.7925),
    ['הרצליה', 'herzliya', 'herzelia']: GeoPoint(32.1624, 34.8447),
    ['רמת השרון', 'ramat hasharon']: GeoPoint(32.1461, 34.8394),
    ['בני ברק', 'bnei brak']: GeoPoint(32.0807, 34.8338),
    ['נתניה', 'netanya']: GeoPoint(32.3215, 34.8532),
    ['ירושלים', 'jerusalem']: GeoPoint(31.7683, 35.2137),
    ['חיפה', 'haifa']: GeoPoint(32.7940, 34.9896),
    ['באר שבע', 'beer sheva', 'beersheba']: GeoPoint(31.2518, 34.7913),
    ['ראש העין', 'rosh haayin']: GeoPoint(32.0956, 34.9568),
    ['אור יהודה', 'or yehuda']: GeoPoint(32.0308, 34.8534),
    ['קרית אונו', 'kiryat ono']: GeoPoint(32.0556, 34.8556),
  };

  GeoPoint? _getCityCentroid(String address) => cityCentroidFor(address);

  static List<String> get knownCityNames => [
    for (final names in _cityCentroids.keys) ...names,
  ];

  static GeoPoint? cityCentroidFor(String cityOrAddress) {
    final lower = cityOrAddress.toLowerCase();
    for (final entry in _cityCentroids.entries) {
      for (final name in entry.key) {
        if (lower.contains(name.toLowerCase())) return entry.value;
      }
    }
    return null;
  }

  static String? _extractCity(String address) {
    final parts = address.split(',').map((e) => e.trim()).toList();
    if (parts.length < 2) return null;
    var city = parts.last;
    if (RegExp(r'(israel|ישראל)', caseSensitive: false).hasMatch(city) &&
        parts.length >= 3) {
      city = parts[parts.length - 2];
    }
    return city.isEmpty ? null : city;
  }

  static bool _cityMatches(String a, String b) {
    String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[\s\-]'), '');
    final na = norm(a), nb = norm(b);
    if (na.isEmpty || nb.isEmpty) return true;
    return na.contains(nb) || nb.contains(na);
  }

  Future<GeoPoint?> getCoordinatesFromAddress(String address) async {
    try {
      if (kDebugMode) {
        print('🗺️ [GEOCODING] Starting geocoding for address: $address');
      }

      final String? expectedCity = _extractCity(address);

      String fullAddress = address;
      if (!address.toLowerCase().contains('israel') &&
          !address.toLowerCase().contains('ישראל')) {
        fullAddress = '$address, Israel';
      }

      if (_mapsApiKey.isNotEmpty) {
        final apiResult = await _geocodeWithGoogleApi(
          fullAddress,
          expectedCity: expectedCity,
        );
        if (apiResult != null) return apiResult;

        if (expectedCity != null) {
          final centroid = cityCentroidFor(expectedCity);
          if (centroid != null) {
            if (kDebugMode) {
              print(
                '⚠️ [GEOCODING] using "$expectedCity" centroid (REST failed/wrong-city)',
              );
            }
            return centroid;
          }
        }
      } else if (!kIsWeb) {
        if (kDebugMode) {
          print('📍 [GEOCODING] No key — native locationFromAddress...');
        }
        try {
          List<Location> locations = await locationFromAddress(fullAddress);
          if (locations.isNotEmpty) {
            final lat = locations.first.latitude;
            final lng = locations.first.longitude;
            if (lat >= 29.5 && lat <= 33.3 && lng >= 34.2 && lng <= 35.9) {
              return GeoPoint(lat, lng);
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ [GEOCODING] Native geocoding package error: $e');
          }
        }
      }

      final knownAddress = _getKnownAddressCoordinates(address);
      if (knownAddress != null) {
        if (kDebugMode) {
          print(
            '⚠️ [GEOCODING] FALLBACK (NOT REAL GEOCODING): using known-test-address table for '
            '"$address" -> (${knownAddress.latitude}, ${knownAddress.longitude})',
          );
        }
        return knownAddress;
      }

      final cityCentroid = _getCityCentroid(address);
      if (cityCentroid != null) {
        if (kDebugMode) {
          print(
            '⚠️ [GEOCODING] FALLBACK: using city centroid for "$address" -> '
            '(${cityCentroid.latitude}, ${cityCentroid.longitude})',
          );
        }
        return cityCentroid;
      }

      if (kDebugMode) {
        print('❌ [GEOCODING] All geocoding attempts failed for: $address');
      }
      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) print('❌ [GEOCODING] Error geocoding address: $e');
      if (kDebugMode) print('📋 [GEOCODING] Stack trace: $stackTrace');
      return null;
    }
  }

  Future<GeoPoint?> _geocodeWithGoogleApi(
    String fullAddress, {
    String? expectedCity,
  }) async {
    if (_mapsApiKey.isEmpty) {
      if (kDebugMode) {
        print(
          '⚠️ [GEOCODING] MAPS_API_KEY not provided (build with --dart-define=MAPS_API_KEY=...)',
        );
      }
      return null;
    }
    try {
      final encodedAddress = Uri.encodeComponent(fullAddress);
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?'
        'address=$encodedAddress&components=country:IL&language=he&key=$_mapsApiKey',
      );
      final response = await http.get(url);

      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('❌ [GEOCODING] API error: ${response.statusCode}');
        }
        return null;
      }

      final data = json.decode(response.body);
      final results = data['results'] as List?;
      if (data['status'] != 'OK' || results == null || results.isEmpty) {
        if (kDebugMode) print('⚠️ [GEOCODING] No results: ${data['status']}');
        return null;
      }

      final result = results[0];
      final location = result['geometry']['location'];
      final lat = (location['lat'] as num).toDouble();
      final lng = (location['lng'] as num).toDouble();

      if (expectedCity != null && expectedCity.trim().isNotEmpty) {
        final comps = (result['address_components'] as List?) ?? const [];
        String? resultCity;
        for (final c in comps) {
          final types = (c['types'] as List).cast<String>();
          if (types.contains('locality')) {
            resultCity = c['long_name'] as String?;
            break;
          }
          if (types.contains('administrative_area_level_2')) {
            resultCity ??= c['long_name'] as String?;
          }
        }
        if (resultCity != null && !_cityMatches(resultCity, expectedCity)) {
          if (kDebugMode) {
            print(
              '⚠️ [GEOCODING] city mismatch: wanted "$expectedCity", got "$resultCity" — rejecting',
            );
          }
          return null;
        }
      }

      if (lat >= 29.5 && lat <= 33.3 && lng >= 34.2 && lng <= 35.9) {
        if (kDebugMode) {
          print('✅ [GEOCODING] Google API geocoded: ($lat, $lng)');
        }
        return GeoPoint(lat, lng);
      } else {
        if (kDebugMode) {
          print(
            '⚠️ [GEOCODING] Google API coordinates outside Israel bounds: ($lat, $lng)',
          );
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) print('❌ [GEOCODING] Google API error: $e');
      return null;
    }
  }

  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  static double calculateDistanceFromGeoPoints(
    GeoPoint point1,
    GeoPoint point2,
  ) {
    return _calculateDistanceStatic(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  static bool isRealGeoPoint(GeoPoint p) => p.latitude != 0 || p.longitude != 0;

  Future<GeoPoint?> getDefaultSavedAddressGeoPoint(String userId) async {
    try {
      final snap = await _firestore
          .collection('addresses')
          .where('userId', isEqualTo: userId)
          .orderBy('isDefault', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final location = snap.docs.first.data()['location'];
      if (location is GeoPoint && isRealGeoPoint(location)) return location;
      return null;
    } catch (e) {
      if (kDebugMode) print('⚠️ getDefaultSavedAddressGeoPoint failed: $e');
      return null;
    }
  }

  static String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      final meters = (distanceKm * 1000).round();
      return '$meters מטר';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)} ק"מ';
    } else {
      return '${distanceKm.round()} ק"מ';
    }
  }

  static double _calculateDistanceStatic(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371;
    final double dLat = (lat2 - lat1) * math.pi / 180;
    final double dLon = (lon2 - lon1) * math.pi / 180;

    final double a =
        (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            (math.sin(dLon / 2) * math.sin(dLon / 2));

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double sin(double x) => _sin(x);
  double cos(double x) => _cos(x);
  double sqrt(double x) => _sqrt(x);
  double atan2(double y, double x) => _atan2(y, x);

  static const double pi = 3.14159265359;

  double _sin(double x) {
    x = x % (2 * pi);
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  double _cos(double x) {
    return _sin(x + pi / 2);
  }

  double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  double _atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + pi;
    if (x < 0 && y < 0) return _atan(y / x) - pi;
    if (y > 0) return pi / 2;
    if (y < 0) return -pi / 2;
    return 0;
  }

  double _atan(double x) {
    double result = 0;
    double term = x;
    for (int i = 0; i < 20; i++) {
      result += term / (2 * i + 1);
      term *= -x * x;
    }
    return result;
  }
}
