import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/enums.dart';
import '../../core/utils/geohash.dart';
import 'availability_window.dart';
import 'opening_hours.dart';
import 'image_variants.dart';

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  return null;
}

class ProductModel {
  final String id;
  final String sellerId;
  final String title;
  final String description;
  final double price;
  final ProductCategory category;
  final String? subcategory;
  final String? brand;
  final ProductCondition condition;
  final List<String> imageUrls;

  final List<ProductImageVariants> imageVariants;

  final List<String> videoUrls;
  final DateTime createdAt;
  final DateTime? updatedAt;

  final GeoPoint location;
  final String city;
  final String? neighborhood;

  final String? geohash;

  final String? pickupAddressId;

  final bool isAvailableNow;

  final List<AvailabilityWindow>? sellerAvailabilityWindows;

  final int viewCount;
  final int likeCount;
  final List<String> likedByUserIds;

  final bool isActive;
  final bool isSold;

  final bool isReserved;
  final String? reservedForOfferId;
  final DateTime? reservedUntil;

  final DateTime? flashDealEndTime;
  final double? originalPrice;

  final String? categoryId;
  final String? subCategoryId;
  final Map<String, dynamic>? specificFields;

  final int? stockTotal;
  final int? stockRemaining;
  final List<String> stockClaimedOrderIds;
  final String? lastStockClaimOrderId;

  final double? retailEstimate;
  final int? bargainDiscountPercent;
  final bool isBargain;

  ProductModel({
    required this.id,
    required this.sellerId,
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    this.subcategory,
    this.brand,
    required this.condition,
    required this.imageUrls,
    this.imageVariants = const [],
    this.videoUrls = const [],
    required this.createdAt,
    this.updatedAt,
    required this.location,
    required this.city,
    this.neighborhood,
    this.geohash,
    this.pickupAddressId,
    this.isAvailableNow = true,
    this.sellerAvailabilityWindows,
    this.viewCount = 0,
    this.likeCount = 0,
    this.likedByUserIds = const [],
    this.isActive = true,
    this.isSold = false,
    this.isReserved = false,
    this.reservedForOfferId,
    this.reservedUntil,
    this.flashDealEndTime,
    this.originalPrice,
    this.categoryId,
    this.subCategoryId,
    this.specificFields,
    this.stockTotal,
    this.stockRemaining,
    this.stockClaimedOrderIds = const [],
    this.lastStockClaimOrderId,
    this.retailEstimate,
    this.bargainDiscountPercent,
    this.isBargain = false,
  });

  static GeoPoint _parseGeoPoint(dynamic value) {
    if (value == null) return const GeoPoint(0, 0);
    if (value is GeoPoint) return value;
    if (value is Map) {
      final lat = (value['_latitude'] ?? value['latitude'] ?? 0).toDouble();
      final lng = (value['_longitude'] ?? value['longitude'] ?? 0).toDouble();
      return GeoPoint(lat, lng);
    }
    return const GeoPoint(0, 0);
  }

  static List<AvailabilityWindow>? _parseSellerWindows(dynamic raw) {
    if (raw is! List) return null;
    return AvailabilityWindow.parseList(raw);
  }

  static String? geohashForLocation(GeoPoint location) {
    if (location.latitude == 0 && location.longitude == 0) return null;
    return GeoHash.encode(
      location.latitude,
      location.longitude,
      precision: kProductGeohashPrecision,
    );
  }

  String? get derivedGeohash => geohashForLocation(location);

  static ProductCategory _parseCategory(dynamic value) {
    if (value == null) return ProductCategory.other;
    final categoryStr = value.toString();

    if (categoryStr == 'home') return ProductCategory.homeGarden;

    try {
      return ProductCategory.values.byName(categoryStr);
    } catch (e) {
      return ProductCategory.other;
    }
  }

  static ProductCondition _parseCondition(dynamic value) {
    if (value == null) return ProductCondition.good;
    try {
      return ProductCondition.values.byName(value.toString());
    } catch (e) {
      return ProductCondition.good;
    }
  }

  factory ProductModel.fromMap(Map<String, dynamic> data, String id) {
    return ProductModel(
      id: id,
      sellerId: data['sellerId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      category: _parseCategory(data['category']),
      subcategory: data['subcategory'],
      brand: data['brand'],
      condition: _parseCondition(data['condition']),
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      imageVariants: ProductImageVariants.listFrom(data['imageVariants']),
      videoUrls: List<String>.from(data['videoUrls'] ?? []),
      createdAt: _parseDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(data['updatedAt']),
      location: _parseGeoPoint(data['location']),
      city: data['city'] ?? '',
      neighborhood: data['neighborhood'],
      geohash: data['geohash'] as String?,
      pickupAddressId: data['pickupAddressId'],
      isAvailableNow: data['isAvailableNow'] ?? true,
      sellerAvailabilityWindows: _parseSellerWindows(
        data[kProductSellerHoursField],
      ),
      viewCount: data['viewCount'] ?? 0,
      likeCount: data['likeCount'] ?? 0,
      likedByUserIds: List<String>.from(data['likedByUserIds'] ?? []),
      isActive: data['isActive'] ?? true,
      isSold: data['isSold'] ?? false,
      isReserved: data['isReserved'] ?? false,
      reservedForOfferId: data['reservedForOfferId'],
      reservedUntil: _parseDateTime(data['reservedUntil']),
      flashDealEndTime: _parseDateTime(data['flashDealEndTime']),
      originalPrice: data['originalPrice']?.toDouble(),
      categoryId: data['categoryId'],
      subCategoryId: data['subCategoryId'],
      specificFields: data['specificFields'] != null
          ? Map<String, dynamic>.from(data['specificFields'])
          : null,
      stockTotal: (data['stockTotal'] as num?)?.toInt(),
      stockRemaining: (data['stockRemaining'] as num?)?.toInt(),
      stockClaimedOrderIds: List<String>.from(
        data['stockClaimedOrderIds'] ?? [],
      ),
      lastStockClaimOrderId: data['lastStockClaimOrderId'],
      retailEstimate: (data['retailEstimate'] as num?)?.toDouble(),
      bargainDiscountPercent: (data['bargainDiscountPercent'] as num?)?.toInt(),
      isBargain: data['isBargain'] == true,
    );
  }

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductModel(
      id: doc.id,
      sellerId: data['sellerId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      category: _parseCategory(data['category']),
      subcategory: data['subcategory'],
      brand: data['brand'],
      condition: _parseCondition(data['condition']),
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      imageVariants: ProductImageVariants.listFrom(data['imageVariants']),
      videoUrls: List<String>.from(data['videoUrls'] ?? []),
      createdAt: _parseDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(data['updatedAt']),
      location: _parseGeoPoint(data['location']),
      city: data['city'] ?? '',
      neighborhood: data['neighborhood'],
      geohash: data['geohash'] as String?,
      pickupAddressId: data['pickupAddressId'],
      isAvailableNow: data['isAvailableNow'] ?? true,
      sellerAvailabilityWindows: _parseSellerWindows(
        data[kProductSellerHoursField],
      ),
      viewCount: data['viewCount'] ?? 0,
      likeCount: data['likeCount'] ?? 0,
      likedByUserIds: List<String>.from(data['likedByUserIds'] ?? []),
      isActive: data['isActive'] ?? true,
      isSold: data['isSold'] ?? false,
      isReserved: data['isReserved'] ?? false,
      reservedForOfferId: data['reservedForOfferId'],
      reservedUntil: _parseDateTime(data['reservedUntil']),
      flashDealEndTime: _parseDateTime(data['flashDealEndTime']),
      originalPrice: data['originalPrice']?.toDouble(),
      categoryId: data['categoryId'],
      subCategoryId: data['subCategoryId'],
      specificFields: data['specificFields'] != null
          ? Map<String, dynamic>.from(data['specificFields'])
          : null,
      stockTotal: (data['stockTotal'] as num?)?.toInt(),
      stockRemaining: (data['stockRemaining'] as num?)?.toInt(),
      stockClaimedOrderIds: List<String>.from(
        data['stockClaimedOrderIds'] ?? [],
      ),
      lastStockClaimOrderId: data['lastStockClaimOrderId'],
      retailEstimate: (data['retailEstimate'] as num?)?.toDouble(),
      bargainDiscountPercent: (data['bargainDiscountPercent'] as num?)?.toInt(),
      isBargain: data['isBargain'] == true,
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'sellerId': sellerId,
      'title': title,
      'description': description,
      'price': price,
      'category': category.name,
      'subcategory': subcategory,
      'brand': brand,
      'condition': condition.name,
      'imageUrls': imageUrls,
      'videoUrls': videoUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'location': location,
      'city': city,
      'neighborhood': neighborhood,
      'pickupAddressId': pickupAddressId,
      'isAvailableNow': isAvailableNow,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'likedByUserIds': likedByUserIds,
      'isActive': isActive,
      'isSold': isSold,
      'isReserved': isReserved,
      'reservedForOfferId': reservedForOfferId,
      'reservedUntil': reservedUntil != null
          ? Timestamp.fromDate(reservedUntil!)
          : null,
      'flashDealEndTime': flashDealEndTime != null
          ? Timestamp.fromDate(flashDealEndTime!)
          : null,
      'originalPrice': originalPrice,
      'categoryId': categoryId,
      'subCategoryId': subCategoryId,
      'specificFields': specificFields,
    };

    final derived = derivedGeohash;
    if (derived != null) map['geohash'] = derived;

    final mirror = sellerAvailabilityWindows;
    if (mirror != null) {
      map[kProductSellerHoursField] = mirror.map((w) => w.toMap()).toList();
    }

    if (stockTotal != null) map['stockTotal'] = stockTotal;
    if (stockRemaining != null) map['stockRemaining'] = stockRemaining;
    if (stockClaimedOrderIds.isNotEmpty) {
      map['stockClaimedOrderIds'] = stockClaimedOrderIds;
    }
    if (lastStockClaimOrderId != null) {
      map['lastStockClaimOrderId'] = lastStockClaimOrderId;
    }

    return map;
  }

  ProductModel copyWith({
    String? id,
    String? sellerId,
    String? title,
    String? description,
    double? price,
    ProductCategory? category,
    String? subcategory,
    String? brand,
    ProductCondition? condition,
    List<String>? imageUrls,
    List<ProductImageVariants>? imageVariants,
    List<String>? videoUrls,
    DateTime? createdAt,
    DateTime? updatedAt,
    GeoPoint? location,
    String? city,
    String? neighborhood,
    String? pickupAddressId,
    bool? isAvailableNow,
    List<AvailabilityWindow>? sellerAvailabilityWindows,
    int? viewCount,
    int? likeCount,
    List<String>? likedByUserIds,
    bool? isActive,
    bool? isSold,
    bool? isReserved,
    String? reservedForOfferId,
    DateTime? reservedUntil,
    DateTime? flashDealEndTime,
    double? originalPrice,
    String? categoryId,
    String? subCategoryId,
    Map<String, dynamic>? specificFields,
    int? stockTotal,
    int? stockRemaining,
    List<String>? stockClaimedOrderIds,
    String? lastStockClaimOrderId,
    double? retailEstimate,
    int? bargainDiscountPercent,
    bool? isBargain,
  }) {
    return ProductModel(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      brand: brand ?? this.brand,
      condition: condition ?? this.condition,
      imageUrls: imageUrls ?? this.imageUrls,
      imageVariants: imageVariants ?? this.imageVariants,
      videoUrls: videoUrls ?? this.videoUrls,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      location: location ?? this.location,
      city: city ?? this.city,
      neighborhood: neighborhood ?? this.neighborhood,
      geohash: geohashForLocation(location ?? this.location),
      pickupAddressId: pickupAddressId ?? this.pickupAddressId,
      isAvailableNow: isAvailableNow ?? this.isAvailableNow,
      sellerAvailabilityWindows:
          sellerAvailabilityWindows ?? this.sellerAvailabilityWindows,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      likedByUserIds: likedByUserIds ?? this.likedByUserIds,
      isActive: isActive ?? this.isActive,
      isSold: isSold ?? this.isSold,
      isReserved: isReserved ?? this.isReserved,
      reservedForOfferId: reservedForOfferId ?? this.reservedForOfferId,
      reservedUntil: reservedUntil ?? this.reservedUntil,
      flashDealEndTime: flashDealEndTime ?? this.flashDealEndTime,
      originalPrice: originalPrice ?? this.originalPrice,
      categoryId: categoryId ?? this.categoryId,
      subCategoryId: subCategoryId ?? this.subCategoryId,
      specificFields: specificFields ?? this.specificFields,
      stockTotal: stockTotal ?? this.stockTotal,
      stockRemaining: stockRemaining ?? this.stockRemaining,
      stockClaimedOrderIds: stockClaimedOrderIds ?? this.stockClaimedOrderIds,
      lastStockClaimOrderId:
          lastStockClaimOrderId ?? this.lastStockClaimOrderId,
      retailEstimate: retailEstimate ?? this.retailEstimate,
      bargainDiscountPercent:
          bargainDiscountPercent ?? this.bargainDiscountPercent,
      isBargain: isBargain ?? this.isBargain,
    );
  }

  String? imageUrlAt(
    int index, {
    ImageVariant variant = ImageVariant.original,
  }) => resolveProductImageUrl(
    imageUrls: imageUrls,
    index: index,
    variant: variant,
    storedVariants: imageVariants,
  );

  String? get thumbnailUrl => imageUrlAt(0, variant: ImageVariant.thumb);

  String? get mediumImageUrl => imageUrlAt(0, variant: ImageVariant.medium);

  bool? sellerIsOpenAt(DateTime at) {
    final windows = sellerAvailabilityWindows;
    if (windows == null) return null;
    return isOpenAt(windows, at);
  }

  bool get hasRetailAnchor => retailEstimate != null && retailEstimate! > 0;

  bool get isReservationExpired =>
      isReserved &&
      reservedUntil != null &&
      DateTime.now().isAfter(reservedUntil!);

  bool get _isStatusAvailableForSale =>
      !isSold && (!isReserved || isReservationExpired);

  bool get hasStock => stockTotal != null;

  int get unitsAvailable =>
      hasStock ? (stockRemaining ?? 0) : (_isStatusAvailableForSale ? 1 : 0);

  bool get isAvailableForSale =>
      _isStatusAvailableForSale && unitsAvailable > 0;

  static const int _kLowStockMinInitial = 3;
  static const int _kLowStockRemainingCeiling = 2;

  bool get showsLowStockHint {
    final total = stockTotal;
    final remaining = stockRemaining;
    if (total == null || remaining == null) return false;
    return total >= _kLowStockMinInitial &&
        remaining >= 1 &&
        remaining <= _kLowStockRemainingCeiling;
  }
}
