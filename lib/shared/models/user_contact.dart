import 'package:cloud_firestore/cloud_firestore.dart';

class UserContact {
  final String? email;
  final String? phoneNumber;
  final String? address;
  final GeoPoint? location;

  const UserContact({
    this.email,
    this.phoneNumber,
    this.address,
    this.location,
  });

  static const UserContact empty = UserContact();

  static DocumentReference<Map<String, dynamic>> ref(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('private')
          .doc('contact');

  factory UserContact.fromDoc(DocumentSnapshot doc) {
    if (!doc.exists) return empty;
    final data = (doc.data() as Map<String, dynamic>?) ?? const {};
    return UserContact(
      email: data['email'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      address: data['address'] as String?,
      location: data['location'] as GeoPoint?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (email != null) 'email': email,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (address != null) 'address': address,
      if (location != null) 'location': location,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  UserContact copyWith({
    String? email,
    String? phoneNumber,
    String? address,
    GeoPoint? location,
  }) {
    return UserContact(
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      location: location ?? this.location,
    );
  }
}
