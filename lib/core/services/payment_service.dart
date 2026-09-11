import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_constants.dart';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> initialize({required String publishableKey}) async {
    Stripe.publishableKey = publishableKey;
    try {
      await Stripe.instance.applySettings();
      if (kDebugMode) {
        print('✅ Stripe initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Stripe initialization failed: $e');
      }
    }
  }

  Future<String?> createPaymentIntent({
    required double amount,
    required String currency,
    required List<String> orderIds,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      if (orderIds.isEmpty) {
        throw Exception('orderIds must not be empty');
      }

      final amountInCents = (amount * 100).round();

      if (kDebugMode) {
        print(
          '💳 Creating payment intent for ₪$amount ($amountInCents agorot) covering ${orderIds.length} order(s)',
        );
      }

      final paymentDoc = await _firestore.collection('payment_intents').add({
        'userId': user.uid,
        'orderIds': orderIds,
        'amount': amountInCents,
        'currency': currency,
        'metadata': metadata ?? {},
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      final doc = await paymentDoc
          .snapshots()
          .firstWhere((snapshot) {
            final data = snapshot.data();
            return data != null &&
                (data['clientSecret'] != null || data['error'] != null);
          })
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw Exception('Timeout waiting for payment intent'),
          );

      final data = doc.data()!;
      if (data['error'] != null) {
        throw Exception('Payment intent creation failed: ${data['error']}');
      }

      if (kDebugMode) {
        print('✅ Payment intent created with client secret');
      }
      return data['clientSecret'] as String;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating payment intent: $e');
      }
      return null;
    }
  }

  Future<PaymentResult> processPayment({
    required double amount,
    required String currency,
    required List<String> orderIds,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final clientSecret = await createPaymentIntent(
        amount: amount,
        currency: currency,
        orderIds: orderIds,
        metadata: metadata,
      );

      if (clientSecret == null) {
        return PaymentResult(
          success: false,
          error: 'Failed to create payment intent',
        );
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: AppConstants.appName,
          style: ThemeMode.system,
          billingDetailsCollectionConfiguration:
              const BillingDetailsCollectionConfiguration(
                name: CollectionMode.always,
                phone: CollectionMode.always,
              ),
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      if (kDebugMode) {
        print('✅ Payment successful');
      }

      return PaymentResult(
        success: true,
        paymentIntentId: clientSecret.split('_secret').first,
      );
    } on StripeException catch (e) {
      if (kDebugMode) {
        print('❌ Stripe error: ${e.error.message}');
      }
      return PaymentResult(
        success: false,
        error: e.error.message ?? 'Payment failed',
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Payment error: $e');
      }
      return PaymentResult(success: false, error: 'Payment failed: $e');
    }
  }
}

class PaymentResult {
  final bool success;
  final String? error;
  final String? paymentIntentId;

  PaymentResult({required this.success, this.error, this.paymentIntentId});
}
