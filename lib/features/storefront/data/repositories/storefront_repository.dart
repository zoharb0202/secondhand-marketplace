import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/models/seller_storefront_model.dart';

class StorefrontRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<StorefrontCustomization?> getStorefrontCustomization(
    String sellerId,
  ) async {
    try {
      final userDoc = await _firestore.collection('users').doc(sellerId).get();

      if (!userDoc.exists) return null;

      final data = userDoc.data();
      if (data == null || data['storefrontCustomization'] == null) {
        return null;
      }

      return StorefrontCustomization.fromMap(
        data['storefrontCustomization'] as Map<String, dynamic>,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching storefront customization: $e');
      }
      rethrow;
    }
  }

  Stream<StorefrontCustomization?> getStorefrontCustomizationStream(
    String sellerId,
  ) {
    return _firestore.collection('users').doc(sellerId).snapshots().map((doc) {
      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null || data['storefrontCustomization'] == null) {
        return null;
      }

      return StorefrontCustomization.fromMap(
        data['storefrontCustomization'] as Map<String, dynamic>,
      );
    });
  }

  Future<void> updateStorefrontCustomization(
    String sellerId,
    StorefrontCustomization customization,
  ) async {
    try {
      await _firestore.collection('users').doc(sellerId).update({
        'storefrontCustomization': customization.toMap(),
      });
      if (kDebugMode) {
        print('✅ Storefront customization updated');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating storefront customization: $e');
      }
      rethrow;
    }
  }

  Future<String> uploadLogo(String sellerId, XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();

      if (bytes.length > AppConstants.maxImageSizeMB * 1024 * 1024) {
        throw Exception(
          'גודל התמונה גדול מדי. מקסימום ${AppConstants.maxImageSizeMB}MB',
        );
      }

      final ref = _storage.ref().child(
        '${AppConstants.storefrontAssetsPath}/$sellerId/logo.jpg',
      );

      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

      final downloadUrl = await ref.getDownloadURL();
      if (kDebugMode) {
        print('✅ Logo uploaded: $downloadUrl');
      }
      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error uploading logo: $e');
      }
      rethrow;
    }
  }

  Future<String> uploadBanner(String sellerId, XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();

      if (bytes.length > AppConstants.maxImageSizeMB * 1024 * 1024) {
        throw Exception(
          'גודל התמונה גדול מדי. מקסימום ${AppConstants.maxImageSizeMB}MB',
        );
      }

      final ref = _storage.ref().child(
        '${AppConstants.storefrontAssetsPath}/$sellerId/banner.jpg',
      );

      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

      final downloadUrl = await ref.getDownloadURL();
      if (kDebugMode) {
        print('✅ Banner uploaded: $downloadUrl');
      }
      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error uploading banner: $e');
      }
      rethrow;
    }
  }

  Future<void> deleteLogo(String sellerId) async {
    try {
      final ref = _storage.ref().child(
        '${AppConstants.storefrontAssetsPath}/$sellerId/logo.jpg',
      );

      await ref.delete();
      if (kDebugMode) {
        print('✅ Logo deleted');
      }
    } catch (e) {
      if (e.toString().contains('object-not-found')) {
        if (kDebugMode) {
          print('ℹ️ Logo file not found, nothing to delete');
        }
      } else {
        if (kDebugMode) {
          print('❌ Error deleting logo: $e');
        }
        rethrow;
      }
    }
  }

  Future<void> deleteBanner(String sellerId) async {
    try {
      final ref = _storage.ref().child(
        '${AppConstants.storefrontAssetsPath}/$sellerId/banner.jpg',
      );

      await ref.delete();
      if (kDebugMode) {
        print('✅ Banner deleted');
      }
    } catch (e) {
      if (e.toString().contains('object-not-found')) {
        if (kDebugMode) {
          print('ℹ️ Banner file not found, nothing to delete');
        }
      } else {
        if (kDebugMode) {
          print('❌ Error deleting banner: $e');
        }
        rethrow;
      }
    }
  }

  Future<void> deleteStorefrontCustomization(String sellerId) async {
    try {
      await Future.wait([deleteLogo(sellerId), deleteBanner(sellerId)]);

      await _firestore.collection('users').doc(sellerId).update({
        'storefrontCustomization': FieldValue.delete(),
      });

      if (kDebugMode) {
        print('✅ Storefront customization deleted');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting storefront customization: $e');
      }
      rethrow;
    }
  }
}
