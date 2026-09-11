import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/map_style.dart';
import '../../../../core/widgets/nav_bar_clearance.dart';
import '../../../../shared/models/product_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/product_repository.dart';
import '../providers/product_provider.dart';
import 'product_detail_page.dart';

class _Placed {
  final ProductModel product;
  final LatLng pos;
  const _Placed(this.product, this.pos);
}

class _Cluster {
  final List<_Placed> items;
  final LatLng position;
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  const _Cluster({
    required this.items,
    required this.position,
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  int get count => items.length;
  bool get isSingle => items.length == 1;

  bool get isDegenerate => (maxLat - minLat) < 1e-6 && (maxLng - minLng) < 1e-6;

  String get id =>
      isSingle ? 'p_${items.first.product.id}' : 'c_${items.first.product.id}';

  factory _Cluster.fromItems(List<_Placed> items) {
    var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    var sumLat = 0.0, sumLng = 0.0;
    for (final item in items) {
      final lat = item.pos.latitude;
      final lng = item.pos.longitude;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
      sumLat += lat;
      sumLng += lng;
    }
    return _Cluster(
      items: items,
      position: LatLng(sumLat / items.length, sumLng / items.length),
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
    );
  }
}

class ProductMapPage extends ConsumerStatefulWidget {
  const ProductMapPage({super.key});

  @override
  ConsumerState<ProductMapPage> createState() => _ProductMapPageState();
}

class _ProductMapPageState extends ConsumerState<ProductMapPage> {
  static const double _kInitialRadiusKm = 2.0;
  static const double _kInitialZoom = 14.0;

  static const double _kMinQueryRadiusKm = 0.6;
  static const double _kMaxQueryRadiusKm = 25.0;

  static const Duration _kCameraDebounce = Duration(milliseconds: 350);

  static const double _kClusterCellPx = 78;

  static const double _kIndividualMarkerZoom = 16.0;

  static const int _kMaxMarkers = 90;

  static const int _kMaxRetainedProducts = 600;
  static const int _kMaxIconCache = 240;

  static const int _kMaxConcurrentIconRenders = 4;

  static const int _kMaxQueuedIconRenders = 60;

  static const LatLng _kFallbackCenter = LatLng(32.0853, 34.7818);
  static const Duration _kCenterResolveTimeout = Duration(milliseconds: 2500);

  ProductModel? _selected;

  List<ProductModel>? _clusterStrip;

  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();

  String _query = '';

  final Map<String, ProductModel> _loaded = {};

  bool _loading = false;
  Object? _loadError;
  bool _viewportTooWide = false;
  bool _servedFromLegacyScan = false;

  bool _lastQueryComplete = true;

  Timer? _debounce;
  int _loadSeq = 0;
  LatLng? _lastQueryCenter;
  double _lastQueryRadiusKm = 0;

  LatLng? _initialCenter;
  bool _centerResolveTimedOut = false;
  Timer? _centerTimer;

  final Map<String, Uint8List> _png = {};
  final Map<int, Uint8List> _clusterPng = {};
  final Set<String> _loadingIcons = {};
  final Set<int> _loadingClusterIcons = {};
  final List<ProductModel> _iconQueue = [];
  int _iconRendersInFlight = 0;

  double _zoom = _kInitialZoom;
  double _markerWidth = 66;

  static const double _cardWH = (92.0 + 42.0 + 11.0) / 132.0;

  @override
  void initState() {
    super.initState();
    _centerTimer = Timer(_kCenterResolveTimeout, () {
      if (mounted) setState(() => _centerResolveTimedOut = true);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _centerTimer?.cancel();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  double _widthForZoom(double zoom) =>
      (34 + (zoom - 10) * 13).clamp(38.0, 150.0);

  bool _hasCoords(ProductModel p) =>
      p.location.latitude != 0 || p.location.longitude != 0;

  GeoPoint? _geoOf(ProductModel p) {
    if (_hasCoords(p)) return p.location;
    return LocationService.cityCentroidFor(p.city);
  }

  LatLng? _resolvePosition(ProductModel p) {
    if (_hasCoords(p)) {
      return LatLng(p.location.latitude, p.location.longitude);
    }
    final GeoPoint? centroid = LocationService.cityCentroidFor(p.city);
    if (centroid == null) return null;
    final int hash = p.id.hashCode;
    final double dLat = ((hash & 0xFF) / 255.0 - 0.5) * 0.012;
    final double dLng = (((hash >> 8) & 0xFF) / 255.0 - 0.5) * 0.012;
    return LatLng(centroid.latitude + dLat, centroid.longitude + dLng);
  }

  LatLng? _resolveInitialCenter() {
    if (_initialCenter != null) return _initialCenter;

    final address = ref.watch(primaryAddressProvider);
    if (address != null && LocationService.isRealGeoPoint(address.location)) {
      return _initialCenter = LatLng(
        address.location.latitude,
        address.location.longitude,
      );
    }

    final gps = ref.watch(userGeoPointProvider).valueOrNull;
    if (gps != null && LocationService.isRealGeoPoint(gps)) {
      return _initialCenter = LatLng(gps.latitude, gps.longitude);
    }

    if (_centerResolveTimedOut) return _initialCenter = _kFallbackCenter;
    return null;
  }

  void _scheduleLoad({bool immediate = false}) {
    _debounce?.cancel();
    if (immediate) {
      _loadViewport();
      return;
    }
    _debounce = Timer(_kCameraDebounce, _loadViewport);
  }

  Future<void> _loadViewport({bool forceRefresh = false}) async {
    final controller = _mapController;
    if (controller == null || !mounted) return;

    LatLngBounds bounds;
    try {
      bounds = await controller.getVisibleRegion();
    } catch (_) {
      return;
    }
    if (!mounted) return;

    final sw = bounds.southwest;
    final ne = bounds.northeast;
    if (sw.latitude == ne.latitude && sw.longitude == ne.longitude) return;

    final center = LatLng(
      (sw.latitude + ne.latitude) / 2,
      (sw.longitude + ne.longitude) / 2,
    );
    final corner = GeoPoint(ne.latitude, ne.longitude);
    final rawRadiusKm = LocationService.calculateDistanceFromGeoPoints(
      GeoPoint(center.latitude, center.longitude),
      corner,
    );
    await _loadAround(center, rawRadiusKm, forceRefresh: forceRefresh);
  }

  Future<void> _loadAround(
    LatLng center,
    double requestedRadiusKm, {
    bool forceRefresh = false,
  }) async {
    if (!mounted) return;

    final centerGeo = GeoPoint(center.latitude, center.longitude);
    final tooWide = requestedRadiusKm > _kMaxQueryRadiusKm;
    final radiusKm = requestedRadiusKm
        .clamp(_kMinQueryRadiusKm, _kMaxQueryRadiusKm)
        .toDouble();

    if (!forceRefresh && _isAlreadyCovered(center, radiusKm)) {
      if (_viewportTooWide != tooWide) {
        setState(() => _viewportTooWide = tooWide);
      }
      return;
    }

    final seq = ++_loadSeq;
    setState(() {
      _loading = true;
      _loadError = null;
      _viewportTooWide = tooWide;
    });

    try {
      final GeoProductPage page = await ref
          .read(productRepositoryProvider)
          .getProductsNear(
            center: centerGeo,
            radiusKm: radiusKm,
            filters: _mapFilters(),
            forceRefresh: forceRefresh,
          );
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _mergeResults(
          page.products,
          centerGeo,
          radiusKm,
          authoritative: page.complete,
        );
        _servedFromLegacyScan = page.servedFromLegacyScan;
        _lastQueryComplete = page.complete;
        _lastQueryCenter = center;
        _lastQueryRadiusKm = radiusKm;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  ProductFilters _mapFilters() => ref
      .read(activeFiltersProvider)
      .copyWith(
        maxDistance: null,
        userLocation: ref.read(userGeoPointProvider).valueOrNull,
      );

  bool _isAlreadyCovered(LatLng center, double radiusKm) {
    final last = _lastQueryCenter;
    if (last == null) return false;
    if (!_lastQueryComplete) return false;
    final moved = LocationService.calculateDistanceFromGeoPoints(
      GeoPoint(last.latitude, last.longitude),
      GeoPoint(center.latitude, center.longitude),
    );
    return moved + radiusKm <= _lastQueryRadiusKm;
  }

  void _mergeResults(
    List<ProductModel> fresh,
    GeoPoint center,
    double radiusKm, {
    required bool authoritative,
  }) {
    if (authoritative) {
      final freshIds = {for (final p in fresh) p.id};
      _loaded.removeWhere((id, product) {
        if (freshIds.contains(id)) return false;
        final geo = _geoOf(product);
        if (geo == null) return false;
        return LocationService.calculateDistanceFromGeoPoints(center, geo) <=
            radiusKm;
      });
    }
    for (final product in fresh) {
      _loaded[product.id] = product;
    }
    _trimRetained(center);
  }

  void _trimRetained(GeoPoint center) {
    if (_loaded.length <= _kMaxRetainedProducts) return;
    final byDistance = _loaded.values.toList()
      ..sort((a, b) {
        final ga = _geoOf(a);
        final gb = _geoOf(b);
        if (ga == null) return 1;
        if (gb == null) return -1;
        return LocationService.calculateDistanceFromGeoPoints(
          center,
          ga,
        ).compareTo(LocationService.calculateDistanceFromGeoPoints(center, gb));
      });
    for (final product in byDistance.skip(_kMaxRetainedProducts)) {
      _loaded.remove(product.id);
      _png.remove(product.id);
    }
  }

  ({double lat, double lng}) _cellDegrees(double zoom, double latitude) {
    final cosLat = math.max(math.cos(latitude * math.pi / 180.0).abs(), 0.05);
    final metersPerPixel = 156543.03392 * cosLat / math.pow(2, zoom);
    final meters = metersPerPixel * _kClusterCellPx;
    final latDeg = meters / 111320.0;
    return (lat: latDeg, lng: latDeg / cosLat);
  }

  List<_Cluster> _bucket(List<_Placed> placed, double cellLat, double cellLng) {
    final buckets = <String, List<_Placed>>{};
    for (final item in placed) {
      final iLat = (item.pos.latitude / cellLat).floor();
      final iLng = (item.pos.longitude / cellLng).floor();
      buckets.putIfAbsent('$iLat:$iLng', () => <_Placed>[]).add(item);
    }
    return [for (final items in buckets.values) _Cluster.fromItems(items)];
  }

  List<_Cluster> _clusterize(
    List<_Placed> placed,
    double zoom,
    double latitude,
  ) {
    if (placed.isEmpty) return const <_Cluster>[];

    if (zoom >= _kIndividualMarkerZoom && placed.length <= _kMaxMarkers) {
      return [
        for (final item in placed) _Cluster.fromItems([item]),
      ];
    }

    var cell = _cellDegrees(zoom, latitude);
    var clusters = _bucket(placed, cell.lat, cell.lng);
    var guard = 0;
    while (clusters.length > _kMaxMarkers && guard++ < 8) {
      cell = (lat: cell.lat * 1.7, lng: cell.lng * 1.7);
      clusters = _bucket(placed, cell.lat, cell.lng);
    }
    return clusters;
  }

  void _onClusterTap(_Cluster cluster) {
    setState(() {
      _selected = null;
      _clusterStrip = [for (final item in cluster.items) item.product];
    });
    _frameCluster(cluster);
  }

  Future<void> _frameCluster(_Cluster cluster) async {
    final controller = _mapController;
    if (controller == null) return;
    if (cluster.isDegenerate) {
      await controller.animateCamera(CameraUpdate.newLatLng(cluster.position));
      return;
    }
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(cluster.minLat, cluster.minLng),
          northeast: LatLng(cluster.maxLat, cluster.maxLng),
        ),
        70,
      ),
    );
  }

  void _ensureIcons(List<_Cluster> clusters) {
    final visible = <String>{};
    for (final cluster in clusters) {
      if (!cluster.isSingle) {
        _ensureClusterIcon(cluster.count);
        continue;
      }
      final product = cluster.items.first.product;
      visible.add(product.id);
      if (_png.containsKey(product.id) || _loadingIcons.contains(product.id)) {
        continue;
      }
      _loadingIcons.add(product.id);
      _iconQueue.add(product);
    }
    while (_iconQueue.length > _kMaxQueuedIconRenders) {
      _loadingIcons.remove(_iconQueue.removeAt(0).id);
    }
    _pruneIconCache(visible);
    _pumpIconQueue();
  }

  void _pruneIconCache(Set<String> visible) {
    if (_png.length <= _kMaxIconCache) return;
    _png.removeWhere((id, _) => !visible.contains(id));
  }

  void _pumpIconQueue() {
    while (_iconRendersInFlight < _kMaxConcurrentIconRenders &&
        _iconQueue.isNotEmpty) {
      final product = _iconQueue.removeLast();
      _iconRendersInFlight++;
      _renderCardPng(product)
          .then((bytes) {
            if (!mounted) return;
            setState(() {
              _png[product.id] = bytes;
              _loadingIcons.remove(product.id);
            });
          })
          .catchError((Object _) {
            _loadingIcons.remove(product.id);
          })
          .whenComplete(() {
            _iconRendersInFlight--;
            if (mounted) _pumpIconQueue();
          });
    }
  }

  void _ensureClusterIcon(int count) {
    if (_clusterPng.containsKey(count) ||
        _loadingClusterIcons.contains(count)) {
      return;
    }
    _loadingClusterIcons.add(count);
    _renderClusterPng(count)
        .then((bytes) {
          if (!mounted) return;
          setState(() {
            _clusterPng[count] = bytes;
            _loadingClusterIcons.remove(count);
          });
        })
        .catchError((Object _) {
          _loadingClusterIcons.remove(count);
        });
  }

  BitmapDescriptor _iconFor(String id) {
    final bytes = _png[id];
    if (bytes == null) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose);
    }
    return BitmapDescriptor.bytes(
      bytes,
      width: _markerWidth,
      height: _markerWidth * _cardWH,
    );
  }

  double _clusterDiameter(int count) =>
      (40 + math.log(count) * 9).clamp(40.0, 76.0);

  BitmapDescriptor _clusterIconFor(int count) {
    final bytes = _clusterPng[count];
    if (bytes == null) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
    final d = _clusterDiameter(count);
    return BitmapDescriptor.bytes(bytes, width: d, height: d);
  }

  Future<Uint8List> _renderClusterPng(int count) async {
    const double scale = 3.0;
    final double d = _clusterDiameter(count);
    final double r = d / 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale);

    final center = Offset(r, r);
    canvas.drawCircle(
      center,
      r,
      Paint()..color = AppColors.primary.withValues(alpha: 0.20),
    );
    canvas.drawCircle(center, r - 3, Paint()..color = Colors.white);
    canvas.drawCircle(center, r - 5, Paint()..color = AppColors.primary);

    final label = count > 999 ? '999+' : '$count';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: label.length >= 4 ? 12 : (label.length == 3 ? 14 : 16),
          fontWeight: FontWeight.w800,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.rtl,
      maxLines: 1,
    )..layout();
    tp.paint(canvas, Offset(r - tp.width / 2, r - tp.height / 2));

    final rendered = await recorder.endRecording().toImage(
      (d * scale).round(),
      (d * scale).round(),
    );
    final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<Uint8List> _renderCardPng(ProductModel p) async {
    const double w = 132;
    const double imgH = 92;
    const double labelH = 42;
    const double tail = 11;
    const double pad = 5;
    const double scale = 2.5;
    final double h = imgH + labelH + tail;

    ui.Image? img;
    if (p.imageUrls.isNotEmpty) {
      try {
        final resp = await http
            .get(Uri.parse(p.imageUrls.first))
            .timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          final codec = await ui.instantiateImageCodec(
            resp.bodyBytes,
            targetWidth: (w * scale).round(),
          );
          img = (await codec.getNextFrame()).image;
        }
      } catch (_) {}
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale);

    final cardRect = Rect.fromLTWH(0, 0, w, imgH + labelH);
    final cardRRect = RRect.fromRectAndRadius(
      cardRect,
      const Radius.circular(16),
    );
    canvas.drawShadow(Path()..addRRect(cardRRect), Colors.black45, 3, false);
    canvas.drawRRect(cardRRect, Paint()..color = Colors.white);

    final imgRect = Rect.fromLTWH(pad, pad, w - 2 * pad, imgH - pad);
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(imgRect, const Radius.circular(12)),
    );
    if (img != null) {
      paintImage(
        canvas: canvas,
        rect: imgRect,
        image: img,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      );
    } else {
      canvas.drawRect(imgRect, Paint()..color = const Color(0xFFECECEC));
    }
    canvas.restore();

    final titleTp = TextPainter(
      text: TextSpan(
        text: p.title,
        style: const TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
      textDirection: TextDirection.rtl,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: w - 2 * pad - 2);
    titleTp.paint(canvas, Offset(pad + 1, imgH + 3));

    final priceTp = TextPainter(
      text: TextSpan(
        text: '₪${p.price.toStringAsFixed(0)}',
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.rtl,
      maxLines: 1,
    )..layout(maxWidth: w - 2 * pad - 2);
    priceTp.paint(canvas, Offset(pad + 1, imgH + 20));

    final tailPath = Path()
      ..moveTo(w / 2 - tail, imgH + labelH - 1)
      ..lineTo(w / 2 + tail, imgH + labelH - 1)
      ..lineTo(w / 2, imgH + labelH + tail)
      ..close();
    canvas.drawPath(tailPath, Paint()..color = Colors.white);

    final rendered = await recorder.endRecording().toImage(
      (w * scale).round(),
      (h * scale).round(),
    );
    final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  static const Map<String, List<String>> _synonyms = {
    'אייפון': ['iphone', 'apple', 'אפל'],
    'אפל': ['apple', 'iphone'],
    'סמסונג': ['samsung', 'galaxy', 'גלקסי'],
    'גלקסי': ['galaxy', 'samsung'],
    'מקבוק': ['macbook', 'apple'],
    'לפטופ': ['laptop', 'מחשב נייד'],
    'אוזניות': ['headphones', 'airpods', 'earbuds', 'buds'],
    'נעליים': ['shoes', 'sneakers', 'נעלי'],
    'נייקי': ['nike'],
    'אדידס': ['adidas'],
    'טלוויזיה': ['tv', 'טי.וי'],
    'שעון': ['watch', 'ساعة'],
  };

  static const Set<String> _stopwords = {
    'עד',
    'מתחת',
    'מעל',
    'ל',
    'של',
    'ב',
    'את',
    'שח',
    'ש"ח',
    '₪',
    'שקל',
    'שקלים',
    'under',
    'above',
    'from',
    'to',
    'the',
  };

  ({List<String> tokens, double? maxPrice, double? minPrice}) _parseQuery(
    String raw,
  ) {
    var q = raw.toLowerCase().trim();
    double? maxPrice, minPrice;

    RegExpMatch? m;
    if ((m = RegExp(
          r'(?:עד|מתחת\s*ל?|under)\s*₪?\s*(\d[\d,]*)',
        ).firstMatch(q)) !=
        null) {
      maxPrice = double.tryParse(m!.group(1)!.replaceAll(',', ''));
      q = q.replaceRange(m.start, m.end, ' ');
    }
    if ((m = RegExp(r'(?:מעל|above|from|מ)\s*₪?\s*(\d[\d,]*)').firstMatch(q)) !=
        null) {
      minPrice = double.tryParse(m!.group(1)!.replaceAll(',', ''));
      q = q.replaceRange(m.start, m.end, ' ');
    }

    final tokens = q
        .split(RegExp(r'[\s,]+'))
        .map((t) => t.trim())
        .where((t) => t.length >= 2 && !_stopwords.contains(t))
        .toList();
    return (tokens: tokens, maxPrice: maxPrice, minPrice: minPrice);
  }

  bool _matchesParsedQuery(
    ProductModel p,
    ({List<String> tokens, double? maxPrice, double? minPrice})? parsed,
  ) {
    if (parsed == null) return true;
    if (parsed.maxPrice != null && p.price > parsed.maxPrice!) return false;
    if (parsed.minPrice != null && p.price < parsed.minPrice!) return false;
    if (parsed.tokens.isEmpty) return true;

    final text = [
      p.title,
      p.description,
      p.brand ?? '',
      p.subcategory ?? '',
      p.city,
    ].join(' ').toLowerCase();

    for (final tok in parsed.tokens) {
      final hit =
          text.contains(tok) ||
          (_synonyms[tok]?.any((s) => text.contains(s)) ?? false);
      if (!hit) return false;
    }
    return true;
  }

  Future<void> _fitTo(List<_Placed> placed) async {
    if (_mapController == null || placed.isEmpty) return;
    if (placed.length == 1) {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(placed.first.pos, 14),
      );
      return;
    }
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final pl in placed) {
      minLat = pl.pos.latitude < minLat ? pl.pos.latitude : minLat;
      maxLat = pl.pos.latitude > maxLat ? pl.pos.latitude : maxLat;
      minLng = pl.pos.longitude < minLng ? pl.pos.longitude : minLng;
      maxLng = pl.pos.longitude > maxLng ? pl.pos.longitude : maxLng;
    }
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60,
      ),
    );
  }

  void _onCameraIdle() {
    final w = _widthForZoom(_zoom);
    if ((w - _markerWidth).abs() >= 4) {
      setState(() => _markerWidth = w);
    } else {
      setState(() {});
    }
    _scheduleLoad();
  }

  double _bottomOverlayInset(BuildContext context) =>
      NavBarClearance.of(context) + 16;

  @override
  Widget build(BuildContext context) {
    ref.listen(activeFiltersProvider, (_, __) {
      _lastQueryCenter = null;
      _scheduleLoad(immediate: true);
    });

    final mapFilterCount = ref
        .watch(activeFiltersProvider)
        .copyWith(maxDistance: null)
        .activeFilterCount;
    void clearFilters() {
      final notifier = ref.read(activeFiltersProvider.notifier);
      final keptMaxDistance = notifier.state.maxDistance;
      notifier.state = notifier.state.clear().copyWith(
        maxDistance: keptMaxDistance,
      );
    }

    final center = _resolveInitialCenter();
    if (center == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('מפת מוצרים')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final userId = ref.watch(
      currentUserProvider.select((asyncUser) => asyncUser.value?.id),
    );

    final trimmedQuery = _query.trim();
    final parsed = trimmedQuery.isEmpty ? null : _parseQuery(_query);

    final placed = <_Placed>[];
    for (final product in _loaded.values) {
      if (userId != null && product.sellerId == userId) continue;
      if (!product.isActive || product.isSold) continue;
      if (!_matchesParsedQuery(product, parsed)) continue;
      final pos = _resolvePosition(product);
      if (pos != null) placed.add(_Placed(product, pos));
    }

    final clusters = _clusterize(placed, _zoom, center.latitude);

    Widget? buildNotice() {
      if (_loadError != null) {
        return _MapNotice(
          text: 'שגיאה בטעינת המפה: $_loadError',
          isError: true,
          actionLabel: 'נסו שוב',
          onAction: () => _loadViewport(forceRefresh: true),
        );
      }
      if (!_loading && placed.isEmpty) {
        if (mapFilterCount > 0) {
          return _MapNotice(
            text: 'אין באזור הזה מוצרים שמתאימים לסינון',
            actionLabel: 'נקה סינון',
            onAction: clearFilters,
          );
        }
        if (trimmedQuery.isNotEmpty) {
          return const _MapNotice(
            text: 'לא נמצאו מוצרים לחיפוש הזה באזור הזה — נסו להתרחק במפה',
          );
        }
        return const _MapNotice(
          text: 'אין מוצרים להצגה באזור הזה — נסו להזיז את המפה',
        );
      }
      if (_viewportTooWide || !_lastQueryComplete) {
        return const _MapNotice(
          text: 'התקרבו במפה כדי לראות את כל המוצרים באזור',
        );
      }
      if (_servedFromLegacyScan) {
        return const _MapNotice(
          text: 'תצוגת המפה חלקית — חלק מהמוצרים עדיין ללא מיקום מדויק',
        );
      }
      return null;
    }

    final notice = buildNotice();
    final showFilterBanner = mapFilterCount > 0 && placed.isNotEmpty;

    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureIcons(clusters));

    final markers = <Marker>{
      for (final cluster in clusters)
        if (cluster.isSingle)
          Marker(
            markerId: MarkerId(cluster.id),
            position: cluster.items.first.pos,
            anchor: const Offset(0.5, 1.0),
            icon: _iconFor(cluster.items.first.product.id),
            onTap: () => setState(() {
              _selected = cluster.items.first.product;
              _clusterStrip = null;
            }),
          )
        else
          Marker(
            markerId: MarkerId(cluster.id),
            position: cluster.position,
            anchor: const Offset(0.5, 0.5),
            icon: _clusterIconFor(cluster.count),
            onTap: () => _onClusterTap(cluster),
          ),
    };

    final bottomInset = _bottomOverlayInset(context);
    final clusterStrip = _clusterStrip;

    return Scaffold(
      appBar: AppBar(title: const Text('מפת מוצרים')),
      body: Stack(
        children: [
          GoogleMap(
            style: kMapStyleWhiteCity,
            initialCameraPosition: CameraPosition(
              target: center,
              zoom: _kInitialZoom,
            ),
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            padding: const EdgeInsets.only(top: 72),
            onMapCreated: (c) {
              _mapController = c;
              _loadAround(center, _kInitialRadiusKm);
            },
            onCameraMove: (pos) => _zoom = pos.zoom,
            onCameraIdle: _onCameraIdle,
            onTap: (_) => setState(() {
              _selected = null;
              _clusterStrip = null;
            }),
          ),

          if (_loading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),

          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: _SearchBar(
              controller: _searchController,
              resultCount: trimmedQuery.isEmpty ? null : placed.length,
              onChanged: (v) => setState(() => _query = v),
              onClear: () => setState(() {
                _query = '';
                _searchController.clear();
              }),
              onSubmitted: (_) => _fitTo(placed),
            ),
          ),

          if (showFilterBanner || notice != null)
            Positioned(
              top: 66,
              left: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showFilterBanner)
                    _FilterBanner(count: mapFilterCount, onClear: clearFilters),
                  if (notice != null) notice,
                ],
              ),
            ),

          if (_selected != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: bottomInset,
              child: _ProductPreviewCard(
                product: _selected!,
                onClose: () => setState(() => _selected = null),
                onOpen: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailPage(productId: _selected!.id),
                  ),
                ),
              ),
            ),

          if (clusterStrip != null && clusterStrip.isNotEmpty)
            Positioned(
              left: 8,
              right: 8,
              bottom: bottomInset,
              child: _ClusterStrip(
                key: ValueKey(
                  '${clusterStrip.length}_${clusterStrip.first.id}',
                ),
                products: clusterStrip,
                onClose: () => setState(() => _clusterStrip = null),
                onOpen: (product) => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailPage(productId: product.id),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MapNotice extends StatelessWidget {
  final String text;
  final bool isError;

  final String? actionLabel;
  final VoidCallback? onAction;

  const _MapNotice({
    required this.text,
    this.isError = false,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.only(top: 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isError ? AppColors.error : null,
                  ),
                ),
              ),
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(width: 8),
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ClusterStrip extends StatelessWidget {
  static const double _cardWidth = 132;
  static const double _cardHeight = 132;

  final List<ProductModel> products;
  final VoidCallback onClose;
  final ValueChanged<ProductModel> onOpen;

  const _ClusterStrip({
    super.key,
    required this.products,
    required this.onClose,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1, end: 0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Transform.translate(
        offset: Offset(0, t * 48),
        child: Opacity(opacity: 1 - t, child: child),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).cardColor,
          child: Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 14, left: 4),
                  child: Row(
                    children: [
                      Text(
                        products.length == 1
                            ? 'מוצר אחד כאן'
                            : '${products.length} מוצרים כאן',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'החליקו לצדדים ובחרו מוצר',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        tooltip: 'סגירה',
                        visualDensity: VisualDensity.compact,
                        onPressed: onClose,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: _cardHeight,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: products.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => _buildCard(products[i]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(ProductModel product) {
    return SizedBox(
      width: _cardWidth,
      child: Material(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onOpen(product),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  width: _cardWidth,
                  child: product.imageUrls.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrls.first,
                          fit: BoxFit.cover,
                          memCacheWidth: 320,
                          placeholder: (_, __) =>
                              const ColoredBox(color: AppColors.surfaceVariant),
                          errorWidget: (_, __, ___) => const ColoredBox(
                            color: AppColors.surfaceVariant,
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              size: 20,
                            ),
                          ),
                        )
                      : const ColoredBox(
                          color: AppColors.surfaceVariant,
                          child: Icon(Icons.inventory_2_outlined, size: 20),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₪${product.price.toStringAsFixed(0)}',
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterBanner extends StatelessWidget {
  final int count;
  final VoidCallback onClear;

  const _FilterBanner({required this.count, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.only(top: 8),
        color: AppColors.primary.withValues(alpha: 0.10),
        child: Padding(
          padding: const EdgeInsets.only(right: 12, left: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.filter_alt_outlined,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                count == 1 ? 'סינון אחד פעיל' : '$count סינונים פעילים',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              TextButton(
                onPressed: onClear,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('נקה', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final int? resultCount;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.resultCount,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(14),
      color: Theme.of(context).cardColor,
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search, color: AppColors.textSecondary),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              decoration: const InputDecoration(
                hintText: 'חיפוש במפה — לדוגמה: אייפון עד 2000',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 8,
                ),
              ),
            ),
          ),
          if (resultCount != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '$resultCount תוצאות',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          if (hasText)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: onClear,
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _ProductPreviewCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  const _ProductPreviewCard({
    required this.product,
    required this.onClose,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: product.imageUrls.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrls.first,
                          fit: BoxFit.cover,
                          memCacheWidth: 200,
                          placeholder: (_, __) =>
                              Container(color: AppColors.surfaceVariant),
                          errorWidget: (_, __, ___) => const ColoredBox(
                            color: AppColors.surfaceVariant,
                            child: Icon(Icons.image_not_supported_outlined),
                          ),
                        )
                      : const ColoredBox(
                          color: AppColors.surfaceVariant,
                          child: Icon(Icons.inventory_2_outlined),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      product.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₪${product.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            product.city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
