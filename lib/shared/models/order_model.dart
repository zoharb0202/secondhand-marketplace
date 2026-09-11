import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/enums.dart';

class OrderLineItem {
  final String productId;
  final String productTitle;
  final String productImageUrl;
  final double price;

  const OrderLineItem({
    required this.productId,
    required this.productTitle,
    required this.productImageUrl,
    required this.price,
  });

  factory OrderLineItem.fromMap(Map<String, dynamic> map) {
    return OrderLineItem(
      productId: map['productId'] ?? '',
      productTitle: map['productTitle'] ?? '',
      productImageUrl: map['productImageUrl'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'productTitle': productTitle,
    'productImageUrl': productImageUrl,
    'price': price,
  };
}

class OrderModel {
  final String id;
  final String productId;
  final String sellerId;
  final String buyerId;

  final String? orderNumber;

  final String productTitle;
  final String productImageUrl;
  final double productPrice;

  final String? pickupAddress;
  final GeoPoint? pickupLocation;
  final String? pickupPhone;
  final String? buyerNotes;
  final String? offerId;

  final double itemPrice;
  final double totalAmount;

  final OrderStatus status;

  final DateTime? buyerConfirmedAt;
  final String? disputeStatus;
  final String? disputeTicketId;

  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? paidAt;
  final DateTime? readyAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  final String? paymentId;
  final String? paymentMethod;
  final String? stripePaymentIntentId;

  final List<OrderStatusHistory> statusHistory;

  final List<OrderLineItem> items;
  final List<String> productIds;

  OrderModel({
    required this.id,
    required this.productId,
    required this.sellerId,
    required this.buyerId,
    this.orderNumber,
    required this.productTitle,
    required this.productImageUrl,
    required this.productPrice,
    this.pickupAddress,
    this.pickupLocation,
    this.pickupPhone,
    this.buyerNotes,
    this.offerId,
    required this.itemPrice,
    required this.totalAmount,
    required this.status,
    this.buyerConfirmedAt,
    this.disputeStatus,
    this.disputeTicketId,
    required this.createdAt,
    this.updatedAt,
    this.paidAt,
    this.readyAt,
    this.completedAt,
    this.cancelledAt,
    this.paymentId,
    this.paymentMethod,
    this.stripePaymentIntentId,
    this.statusHistory = const [],
    this.items = const [],
    this.productIds = const [],
  });

  List<OrderLineItem> get lineItems => items.isNotEmpty
      ? items
      : [
          OrderLineItem(
            productId: productId,
            productTitle: productTitle,
            productImageUrl: productImageUrl,
            price: itemPrice,
          ),
        ];

  bool get isMultiItem => items.length > 1;

  static const String paymentCard = 'credit_card';
  static const String paymentOnPickup = 'pay_on_pickup';

  bool get isPayOnPickup => paymentMethod == paymentOnPickup;

  bool get canMarkReady =>
      status == OrderStatus.paid ||
      (status == OrderStatus.pending && isPayOnPickup);

  bool get isPickupRevealed =>
      status == OrderStatus.paid ||
      status == OrderStatus.readyForPickup ||
      status == OrderStatus.completed;

  bool get isActive =>
      status == OrderStatus.pending ||
      status == OrderStatus.paid ||
      status == OrderStatus.readyForPickup;

  static DateTime? _date(dynamic v) => v is Timestamp ? v.toDate() : null;

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrderModel(
      id: doc.id,
      productId: data['productId'] ?? '',
      sellerId: data['sellerId'] ?? '',
      buyerId: data['buyerId'] ?? '',
      orderNumber: data['orderNumber'] as String?,
      productTitle: data['productTitle'] ?? '',
      productImageUrl: data['productImageUrl'] ?? '',
      productPrice: (data['productPrice'] ?? 0).toDouble(),
      pickupAddress: data['pickupAddress'],
      pickupLocation: data['pickupLocation'],
      pickupPhone: data['pickupPhone'],
      buyerNotes: data['buyerNotes'],
      offerId: data['offerId'],
      itemPrice: (data['itemPrice'] ?? 0).toDouble(),
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      status: OrderStatus.fromName(data['status'] as String?),
      buyerConfirmedAt: _date(data['buyerConfirmedAt']),
      disputeStatus: data['disputeStatus'] as String?,
      disputeTicketId: data['disputeTicketId'] as String?,
      createdAt: _date(data['createdAt']) ?? DateTime.now(),
      updatedAt: _date(data['updatedAt']),
      paidAt: _date(data['paidAt']),
      readyAt: _date(data['readyAt']),
      completedAt: _date(data['completedAt']),
      cancelledAt: _date(data['cancelledAt']),
      paymentId: data['paymentId'],
      paymentMethod: data['paymentMethod'],
      stripePaymentIntentId: data['stripePaymentIntentId'],
      statusHistory:
          (data['statusHistory'] as List?)
              ?.whereType<Map>()
              .map(
                (e) => OrderStatusHistory.fromMap(Map<String, dynamic>.from(e)),
              )
              .toList() ??
          const [],
      items:
          (data['items'] as List?)
              ?.whereType<Map>()
              .map((e) => OrderLineItem.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      productIds:
          (data['productIds'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }

  static Timestamp? _ts(DateTime? d) =>
      d != null ? Timestamp.fromDate(d) : null;

  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'sellerId': sellerId,
      'buyerId': buyerId,
      'productTitle': productTitle,
      'productImageUrl': productImageUrl,
      'productPrice': productPrice,
      'pickupAddress': pickupAddress,
      'pickupLocation': pickupLocation,
      'pickupPhone': pickupPhone,
      'buyerNotes': buyerNotes,
      if (offerId != null) 'offerId': offerId,
      'itemPrice': itemPrice,
      'totalAmount': totalAmount,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': _ts(updatedAt),
      'paidAt': _ts(paidAt),
      'readyAt': _ts(readyAt),
      'completedAt': _ts(completedAt),
      'cancelledAt': _ts(cancelledAt),
      'paymentId': paymentId,
      'paymentMethod': paymentMethod,
      'stripePaymentIntentId': stripePaymentIntentId,
      'statusHistory': statusHistory.map((e) => e.toMap()).toList(),
      if (items.isNotEmpty) 'items': items.map((e) => e.toMap()).toList(),
      if (productIds.isNotEmpty) 'productIds': productIds,
    };
  }

  OrderModel copyWith({
    String? id,
    OrderStatus? status,
    String? pickupAddress,
    GeoPoint? pickupLocation,
    String? pickupPhone,
    String? buyerNotes,
    double? totalAmount,
    DateTime? updatedAt,
    DateTime? paidAt,
    DateTime? readyAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? paymentId,
    String? paymentMethod,
    String? stripePaymentIntentId,
    List<OrderStatusHistory>? statusHistory,
  }) {
    return OrderModel(
      id: id ?? this.id,
      productId: productId,
      sellerId: sellerId,
      buyerId: buyerId,
      orderNumber: orderNumber,
      productTitle: productTitle,
      productImageUrl: productImageUrl,
      productPrice: productPrice,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      pickupPhone: pickupPhone ?? this.pickupPhone,
      buyerNotes: buyerNotes ?? this.buyerNotes,
      offerId: offerId,
      itemPrice: itemPrice,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      buyerConfirmedAt: buyerConfirmedAt,
      disputeStatus: disputeStatus,
      disputeTicketId: disputeTicketId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      paidAt: paidAt ?? this.paidAt,
      readyAt: readyAt ?? this.readyAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      paymentId: paymentId ?? this.paymentId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      stripePaymentIntentId:
          stripePaymentIntentId ?? this.stripePaymentIntentId,
      statusHistory: statusHistory ?? this.statusHistory,
      items: items,
      productIds: productIds,
    );
  }
}

class OrderStatusHistory {
  final OrderStatus status;
  final DateTime timestamp;
  final String? note;

  OrderStatusHistory({
    required this.status,
    required this.timestamp,
    this.note,
  });

  factory OrderStatusHistory.fromMap(Map<String, dynamic> map) {
    return OrderStatusHistory(
      status: OrderStatus.fromName(map['status'] as String?),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: map['note'],
    );
  }

  Map<String, dynamic> toMap() => {
    'status': status.name,
    'timestamp': Timestamp.fromDate(timestamp),
    'note': note,
  };
}
