import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';

class OrderRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const int sellerOrdersQueryLimit = 50;

  Future<OrderModel> createOrder({
    required String productId,
    required String sellerId,
    required String buyerId,
    required String productTitle,
    required String productImageUrl,
    required double productPrice,
    String? pickupAddress,
    GeoPoint? pickupLocation,
    String? pickupPhone,
    String? buyerNotes,
    String? paymentId,
    String? paymentMethod,
    String? offerId,
    List<OrderLineItem> additionalItems = const [],
    Map<String, int> quantities = const {},
  }) async {
    int qtyOf(String id) {
      final q = quantities[id] ?? 1;
      return q < 1 ? 1 : q;
    }

    final itemPrice =
        productPrice * qtyOf(productId) +
        additionalItems.fold<double>(
          0,
          (total, item) => total + item.price * qtyOf(item.productId),
        );
    final totalAmount = itemPrice;

    final now = DateTime.now();
    final isPaid = paymentId != null && paymentId.isNotEmpty;

    final allLineItems = [
      OrderLineItem(
        productId: productId,
        productTitle: productTitle,
        productImageUrl: productImageUrl,
        price: productPrice,
      ),
      ...additionalItems,
    ];

    final orderRef = _firestore.collection(AppConstants.ordersCollection).doc();
    final productRefs = allLineItems
        .map(
          (item) => _firestore
              .collection(AppConstants.productsCollection)
              .doc(item.productId),
        )
        .toList();

    final order = OrderModel(
      id: '',
      productId: productId,
      sellerId: sellerId,
      buyerId: buyerId,
      productTitle: productTitle,
      productImageUrl: productImageUrl,
      productPrice: productPrice,
      items: additionalItems.isEmpty ? const [] : allLineItems,
      productIds: additionalItems.isEmpty
          ? const []
          : allLineItems.map((e) => e.productId).toList(),
      pickupAddress: pickupAddress,
      pickupLocation: pickupLocation,
      pickupPhone: pickupPhone,
      buyerNotes: buyerNotes,
      offerId: offerId,
      itemPrice: itemPrice,
      totalAmount: totalAmount,
      status: isPaid ? OrderStatus.paid : OrderStatus.pending,
      createdAt: now,
      paidAt: isPaid ? now : null,
      paymentId: paymentId,
      paymentMethod: paymentMethod ?? OrderModel.paymentCard,
      statusHistory: [
        OrderStatusHistory(
          status: OrderStatus.pending,
          timestamp: now,
          note: 'הזמנה נוצרה',
        ),
        if (isPaid)
          OrderStatusHistory(
            status: OrderStatus.paid,
            timestamp: now,
            note: 'התשלום אושר',
          ),
      ],
    );

    final profiles = await Future.wait([
      _firestore.collection(AppConstants.usersCollection).doc(sellerId).get(),
      _firestore.collection(AppConstants.usersCollection).doc(buyerId).get(),
    ]);
    final sellerName =
        (profiles[0].data()?['displayName'] as String?) ?? 'מוכר';
    final buyerName = (profiles[1].data()?['displayName'] as String?) ?? 'קונה';

    await _firestore.runTransaction((transaction) async {
      final snaps = <DocumentSnapshot>[];
      for (final ref in productRefs) {
        snaps.add(await transaction.get(ref));
      }

      for (var i = 0; i < snaps.length; i++) {
        final snap = snaps[i];
        if (!snap.exists) throw Exception('המוצר לא נמצא');
        final data = snap.data() as Map<String, dynamic>;
        if (data['isSold'] == true || data['isActive'] == false) {
          throw Exception('המוצר כבר נמכר או שאינו זמין יותר');
        }
        if (data['isReserved'] == true) {
          final until = (data['reservedUntil'] as Timestamp?)?.toDate();
          final active = until != null && until.isAfter(DateTime.now());
          final isThisReservation =
              i == 0 &&
              offerId != null &&
              offerId == data['reservedForOfferId'];
          if (active && !isThisReservation) {
            throw Exception(
              'המוצר שמור כרגע לקונה אחר במסגרת הצעת מחיר שאושרה',
            );
          }
        }
      }

      final quantityByProductId = <String, int>{
        for (final ref in productRefs)
          if (qtyOf(ref.id) > 1) ref.id: qtyOf(ref.id),
      };

      transaction.set(orderRef, {
        ...order.toFirestore(),
        'sellerName': sellerName,
        'buyerName': buyerName,
        if (quantityByProductId.isNotEmpty)
          'quantityByProductId': quantityByProductId,
      });

      for (var i = 0; i < productRefs.length; i++) {
        final ref = productRefs[i];
        final data = snaps[i].data() as Map<String, dynamic>;

        if (data['stockTotal'] == null) {
          transaction.update(ref, {
            'isSold': true,
            'isActive': false,
            'soldViaOrderId': orderRef.id,
            'isReserved': false,
            'reservedForOfferId': null,
            'reservedUntil': null,
          });
          continue;
        }

        final remaining = (data['stockRemaining'] as num?)?.toInt() ?? 0;
        final take = qtyOf(ref.id);
        if (take > remaining) {
          throw Exception(
            remaining <= 0
                ? 'אזל המלאי של ${data['title'] ?? 'המוצר'}'
                : 'נותרו רק $remaining יחידות מ${data['title'] ?? 'המוצר'}',
          );
        }
        final next = remaining - take;
        transaction.update(ref, {
          'stockRemaining': next,
          'isSold': next == 0,
          'isActive': next > 0,
          'stockClaimedOrderIds': FieldValue.arrayUnion([orderRef.id]),
          'lastStockClaimOrderId': orderRef.id,
        });
      }
    });

    return order.copyWith(id: orderRef.id);
  }

  Stream<List<OrderModel>> getBuyerOrders(String userId) {
    return _firestore
        .collection(AppConstants.ordersCollection)
        .where('buyerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(sellerOrdersQueryLimit)
        .snapshots()
        .map((s) => s.docs.map(OrderModel.fromFirestore).toList());
  }

  Stream<List<OrderModel>> getSellerOrders(String userId) {
    return _firestore
        .collection(AppConstants.ordersCollection)
        .where('sellerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(sellerOrdersQueryLimit)
        .snapshots()
        .map((s) => s.docs.map(OrderModel.fromFirestore).toList());
  }

  Stream<OrderModel?> getOrder(String orderId) {
    return _firestore
        .collection(AppConstants.ordersCollection)
        .doc(orderId)
        .snapshots()
        .map((doc) => doc.exists ? OrderModel.fromFirestore(doc) : null);
  }

  Future<void> updateOrderStatus(
    String orderId,
    OrderStatus newStatus, {
    String? note,
  }) async {
    final now = DateTime.now();
    final history = OrderStatusHistory(
      status: newStatus,
      timestamp: now,
      note: note,
    );
    final updates = <String, dynamic>{
      'status': newStatus.name,
      'updatedAt': Timestamp.fromDate(now),
      'statusHistory': FieldValue.arrayUnion([history.toMap()]),
      switch (newStatus) {
        OrderStatus.paid => 'paidAt',
        OrderStatus.readyForPickup => 'readyAt',
        OrderStatus.completed => 'completedAt',
        OrderStatus.cancelled => 'cancelledAt',
        _ => 'updatedAt',
      }: Timestamp.fromDate(
        now,
      ),
    };
    await _firestore
        .collection(AppConstants.ordersCollection)
        .doc(orderId)
        .update(updates);
  }

  Future<void> markReadyForPickup(String orderId) => updateOrderStatus(
    orderId,
    OrderStatus.readyForPickup,
    note: 'המוכר אישר שהמוצר מוכן לאיסוף',
  );

  Future<void> confirmPickup(String orderId) => updateOrderStatus(
    orderId,
    OrderStatus.completed,
    note: 'הקונה אישר את איסוף המוצר',
  );

  Future<void> cancelOrder(String orderId, {String? reason}) =>
      updateOrderStatus(
        orderId,
        OrderStatus.cancelled,
        note: reason ?? 'הזמנה בוטלה',
      );
}
