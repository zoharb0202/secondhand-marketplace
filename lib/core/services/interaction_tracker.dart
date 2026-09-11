import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/product_model.dart';

class InteractionType {
  static const String viewDetail = 'view_detail';
  static const String dwell = 'dwell';
  static const String like = 'like';
  static const String unlike = 'unlike';
  static const String search = 'search';
  static const String addToCart = 'add_to_cart';
  static const String removeFromCart = 'remove_from_cart';
  static const String purchase = 'purchase';
  static const String offerMade = 'offer_made';
  static const String share = 'share';
  static const String chatStarted = 'chat_started';

  static const Set<String> _weak = {viewDetail, dwell};
  static bool isWeak(String type) => _weak.contains(type);
}

class InteractionTracker {
  InteractionTracker._internal();
  static final InteractionTracker _instance = InteractionTracker._internal();
  factory InteractionTracker() => _instance;

  static const int _flushSize = 10;
  static const Duration _flushInterval = Duration(seconds: 20);
  static const int _maxDwellMs = 120000;
  static const int _minDwellMs = 2000;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('user_interactions');

  final Map<String, _PendingWrite> _pending = {};

  final Map<String, DocumentReference<Map<String, dynamic>>> _dwellRefs = {};

  final Map<String, int> _dwellMaxMs = {};

  final Set<String> _viewedProductIds = {};

  Timer? _flushTimer;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  void track(
    String type, {
    ProductModel? product,
    String? productId,
    String? category,
    String? subcategory,
    String? brand,
    double? price,
    String? sellerId,
    String? condition,
    String? city,
    bool? isBargain,
    String? query,
    int? dwellMs,
  }) {
    try {
      final uid = _uid;
      if (uid == null) return;

      final resolvedProductId = product?.id ?? productId;

      if (type == InteractionType.dwell) {
        _bufferDwell(
          uid,
          resolvedProductId,
          dwellMs ?? 0,
          product: product,
          category: category,
          subcategory: subcategory,
          brand: brand,
          price: price,
          sellerId: sellerId,
          condition: condition,
          city: city,
          isBargain: isBargain,
        );
        return;
      }

      final event = _buildEvent(
        uid,
        type,
        product: product,
        productId: resolvedProductId,
        category: category,
        subcategory: subcategory,
        brand: brand,
        price: price,
        sellerId: sellerId,
        condition: condition,
        city: city,
        isBargain: isBargain,
        query: query,
      );

      if (!InteractionType.isWeak(type)) {
        unawaited(_writeImmediate(event));
        return;
      }

      if (resolvedProductId == null) return;
      if (!_viewedProductIds.add(resolvedProductId)) {
        return;
      }
      _pending['view_detail:$resolvedProductId'] = _PendingWrite(
        _col.doc(),
        event,
      );
      _scheduleFlush();
    } catch (e) {
      if (kDebugMode) debugPrint('InteractionTracker.track failed: $e');
    }
  }

  void _bufferDwell(
    String uid,
    String? productId,
    int dwellMs, {
    ProductModel? product,
    String? category,
    String? subcategory,
    String? brand,
    double? price,
    String? sellerId,
    String? condition,
    String? city,
    bool? isBargain,
  }) {
    if (dwellMs < _minDwellMs) return;
    if (productId == null) return;
    final capped = dwellMs > _maxDwellMs ? _maxDwellMs : dwellMs;

    final priorMax = _dwellMaxMs[productId] ?? 0;
    final value = capped > priorMax ? capped : priorMax;
    _dwellMaxMs[productId] = value;

    final ref = _dwellRefs.putIfAbsent(productId, () => _col.doc());
    final event = _buildEvent(
      uid,
      InteractionType.dwell,
      product: product,
      productId: productId,
      category: category,
      subcategory: subcategory,
      brand: brand,
      price: price,
      sellerId: sellerId,
      condition: condition,
      city: city,
      isBargain: isBargain,
      dwellMs: value,
    );
    _pending['dwell:$productId'] = _PendingWrite(ref, event);
    _scheduleFlush();
  }

  Map<String, dynamic> _buildEvent(
    String uid,
    String type, {
    ProductModel? product,
    String? productId,
    String? category,
    String? subcategory,
    String? brand,
    double? price,
    String? sellerId,
    String? condition,
    String? city,
    bool? isBargain,
    String? query,
    int? dwellMs,
  }) {
    final event = <String, dynamic>{
      'userId': uid,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final pid = product?.id ?? productId;
    if (pid != null) event['productId'] = pid;

    final cat = category ?? product?.category.name;
    if (cat != null) event['category'] = cat;

    final sub = subcategory ?? product?.subcategory;
    if (sub != null) event['subcategory'] = sub;

    final br = brand ?? product?.brand;
    if (br != null) event['brand'] = br;

    final pr = price ?? product?.price;
    if (pr != null) event['price'] = pr;

    final seller = sellerId ?? product?.sellerId;
    if (seller != null) event['sellerId'] = seller;

    final cond = condition ?? product?.condition.name;
    if (cond != null) event['condition'] = cond;

    final town = city ?? product?.city;
    if (town != null && town.isNotEmpty) event['city'] = town;

    final bargain = isBargain ?? product?.isBargain;
    if (bargain != null) event['isBargain'] = bargain;

    if (query != null) event['query'] = query;
    if (dwellMs != null) event['dwellMs'] = dwellMs;

    return event;
  }

  void _scheduleFlush() {
    if (_pending.length >= _flushSize) {
      _flushTimer?.cancel();
      _flushTimer = null;
      unawaited(_flush());
      return;
    }
    _flushTimer ??= Timer(_flushInterval, () {
      _flushTimer = null;
      unawaited(_flush());
    });
  }

  Future<void> _writeImmediate(Map<String, dynamic> event) async {
    try {
      await _col.add(event);
    } catch (e) {
      if (kDebugMode) debugPrint('InteractionTracker write failed: $e');
    }
  }

  Future<void> _flush() async {
    if (_pending.isEmpty) return;
    final writes = _pending.values.toList();
    _pending.clear();
    try {
      final batch = _firestore.batch();
      for (final w in writes) {
        batch.set(w.ref, w.data, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (e) {
      if (kDebugMode) debugPrint('InteractionTracker flush failed: $e');
    }
  }
}

class _PendingWrite {
  final DocumentReference<Map<String, dynamic>> ref;
  final Map<String, dynamic> data;
  _PendingWrite(this.ref, this.data);
}

final interactionTrackerProvider = Provider<InteractionTracker>((ref) {
  return InteractionTracker();
});
