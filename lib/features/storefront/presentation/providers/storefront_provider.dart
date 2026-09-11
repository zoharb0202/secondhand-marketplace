import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/models/seller_storefront_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/storefront_repository.dart';
import '../../domain/storefront_validator.dart';

final storefrontRepositoryProvider = Provider<StorefrontRepository>((ref) {
  return StorefrontRepository();
});

final sellerStorefrontProvider =
    StreamProvider.family<StorefrontCustomization?, String>((ref, sellerId) {
      return FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .snapshots()
          .map((doc) {
            if (!doc.exists) return null;

            final data = doc.data();
            if (data == null || data['storefrontCustomization'] == null) {
              return null;
            }

            try {
              return StorefrontCustomization.fromMap(
                data['storefrontCustomization'] as Map<String, dynamic>,
              );
            } catch (e) {
              if (kDebugMode) {
                print('❌ Error parsing storefront customization: $e');
              }
              return null;
            }
          });
    });

final myStorefrontProvider = StreamProvider<StorefrontCustomization?>((
  ref,
) async* {
  final user = ref.watch(authStateProvider).value;

  if (user == null) {
    yield null;
    return;
  }

  await for (final customization
      in ref.watch(sellerStorefrontProvider(user.uid).future).asStream()) {
    yield customization;
  }
});

final validateCustomizationProvider =
    Provider.family<ValidationResult, StorefrontCustomization>(
      (ref, customization) =>
          StorefrontValidator.validateCustomization(customization),
    );
