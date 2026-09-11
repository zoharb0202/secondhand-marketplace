import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/enums.dart';
import '../../core/constants/user_roles.dart';
import 'availability_window.dart';

class UserModel {
  final String id;
  final String email;
  final String? displayName;
  final String? phoneNumber;
  final String? photoUrl;

  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? termsAcceptedAt;

  final GeoPoint? location;
  final String? address;
  final String? city;

  final SellerAvailability? sellerAvailability;
  final List<AvailabilityWindow> availabilityWindows;
  final bool isStoreOpen;
  final bool isSellerVerified;
  final double? sellerRating;
  final int totalReviews;
  final int totalSales;

  final String? bio;
  final List<String> favoriteProductIds;
  final List<String> followingSellerIds;

  final bool isAdmin;
  final UserRole role;

  final bool isActive;

  UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.phoneNumber,
    this.photoUrl,
    required this.createdAt,
    this.updatedAt,
    this.termsAcceptedAt,
    this.location,
    this.address,
    this.city,
    this.sellerAvailability,
    this.availabilityWindows = const [],
    this.isStoreOpen = true,
    this.isSellerVerified = false,
    this.sellerRating,
    this.totalReviews = 0,
    this.totalSales = 0,
    this.bio,
    this.favoriteProductIds = const [],
    this.followingSellerIds = const [],
    this.isAdmin = false,
    this.role = UserRole.customer,
    this.isActive = true,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      phoneNumber: data['phoneNumber'],
      photoUrl: data['photoUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      termsAcceptedAt: data['termsAcceptedAt'] != null
          ? (data['termsAcceptedAt'] as Timestamp).toDate()
          : null,
      location: data['location'],
      address: data['address'],
      city: data['city'],
      sellerAvailability: data['sellerAvailability'] != null
          ? SellerAvailability.values.byName(data['sellerAvailability'])
          : null,
      availabilityWindows:
          (data['availabilityWindows'] as List<dynamic>?)
              ?.map(
                (w) => AvailabilityWindow.fromMap(w as Map<String, dynamic>),
              )
              .toList() ??
          [],
      isStoreOpen: data['isStoreOpen'] ?? true,
      isSellerVerified: data['isSellerVerified'] ?? false,
      sellerRating: data['sellerRating']?.toDouble(),
      totalReviews: data['totalReviews'] ?? 0,
      totalSales: data['totalSales'] ?? 0,
      bio: data['bio'],
      favoriteProductIds: List<String>.from(data['favoriteProductIds'] ?? []),
      followingSellerIds: List<String>.from(data['followingSellerIds'] ?? []),
      isAdmin: data['isAdmin'] ?? false,
      role: UserRoleHelper.fromString(data['role']),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'termsAcceptedAt': termsAcceptedAt != null
          ? Timestamp.fromDate(termsAcceptedAt!)
          : null,
      'city': city,
      'sellerAvailability': sellerAvailability?.name,
      'availabilityWindows': availabilityWindows.map((w) => w.toMap()).toList(),
      'isStoreOpen': isStoreOpen,
      'isSellerVerified': isSellerVerified,
      'sellerRating': sellerRating ?? 0,
      'totalReviews': totalReviews,
      'totalSales': totalSales,
      'bio': bio,
      'favoriteProductIds': favoriteProductIds,
      'followingSellerIds': followingSellerIds,
      'isAdmin': isAdmin,
      'role': role.name,
      'isActive': isActive,
    };
  }

  static const Set<String> clientImmutableUpdateKeys = {
    'role',
    'isAdmin',
    'rating',
    'totalRatings',
    'totalReviews',
    'sellerRating',
    'sellerReviewCount',
    'totalSales',
    'isSellerVerified',
    'isActive',
  };

  Map<String, dynamic> toFirestoreProfileUpdate() {
    final updates = <String, dynamic>{
      'displayName': displayName,
      'photoUrl': photoUrl,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'termsAcceptedAt': termsAcceptedAt != null
          ? Timestamp.fromDate(termsAcceptedAt!)
          : null,
      'city': city,
      'sellerAvailability': sellerAvailability?.name,
      'availabilityWindows': availabilityWindows.isEmpty
          ? null
          : availabilityWindows.map((w) => w.toMap()).toList(),
      'isStoreOpen': isStoreOpen,
      'bio': bio,
      'favoriteProductIds': favoriteProductIds.isEmpty
          ? null
          : favoriteProductIds,
      'followingSellerIds': followingSellerIds.isEmpty
          ? null
          : followingSellerIds,
    };
    updates.removeWhere(
      (key, value) => value == null || clientImmutableUpdateKeys.contains(key),
    );
    return updates;
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? phoneNumber,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? termsAcceptedAt,
    GeoPoint? location,
    String? address,
    String? city,
    SellerAvailability? sellerAvailability,
    List<AvailabilityWindow>? availabilityWindows,
    bool? isStoreOpen,
    bool? isSellerVerified,
    double? sellerRating,
    int? totalReviews,
    int? totalSales,
    String? bio,
    List<String>? favoriteProductIds,
    List<String>? followingSellerIds,
    bool? isAdmin,
    UserRole? role,
    bool? isActive,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      termsAcceptedAt: termsAcceptedAt ?? this.termsAcceptedAt,
      location: location ?? this.location,
      address: address ?? this.address,
      city: city ?? this.city,
      sellerAvailability: sellerAvailability ?? this.sellerAvailability,
      availabilityWindows: availabilityWindows ?? this.availabilityWindows,
      isStoreOpen: isStoreOpen ?? this.isStoreOpen,
      isSellerVerified: isSellerVerified ?? this.isSellerVerified,
      sellerRating: sellerRating ?? this.sellerRating,
      totalReviews: totalReviews ?? this.totalReviews,
      totalSales: totalSales ?? this.totalSales,
      bio: bio ?? this.bio,
      favoriteProductIds: favoriteProductIds ?? this.favoriteProductIds,
      followingSellerIds: followingSellerIds ?? this.followingSellerIds,
      isAdmin: isAdmin ?? this.isAdmin,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
    );
  }
}
