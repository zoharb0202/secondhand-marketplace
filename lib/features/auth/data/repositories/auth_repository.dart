import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/models/user_contact.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/legal_consent_service.dart';
import '../../../../core/constants/user_roles.dart';
import '../../../../core/services/notification_coordinator.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  static int _profileBootstrapInFlight = 0;

  Future<UserModel?> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    String? phoneNumber,
  }) async {
    _profileBootstrapInFlight++;
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        await userCredential.user!.updateDisplayName(displayName);

        try {
          await userCredential.user!.sendEmailVerification();
        } catch (e) {
          if (kDebugMode) print('⚠️ Failed to send verification email: $e');
        }

        final now = DateTime.now();
        final userModel = UserModel(
          id: userCredential.user!.uid,
          email: email,
          displayName: displayName,
          phoneNumber: phoneNumber,
          createdAt: now,
          termsAcceptedAt: now,
          isStoreOpen: true,
          sellerAvailability: SellerAvailability.online,
          role: UserRole.customer,
        );

        final outcome = await _createProfileIfAbsent(
          userCredential.user!.uid,
          userModel,
        );
        final storedProfile = outcome.created
            ? outcome.profile
            : await _reconcileRacedProfile(
                userCredential.user!.uid,
                desired: userModel,
                existing: outcome.profile,
              );

        await _writeContact(userCredential.user!.uid, userModel);

        try {
          await LegalConsentService().record(consentContext: 'signup');
        } catch (e) {
          if (kDebugMode) print('⚠️ consent record failed (non-fatal): $e');
        }

        return storedProfile;
      }
      return null;
    } catch (e) {
      rethrow;
    } finally {
      _profileBootstrapInFlight--;
    }
  }

  Future<UserModel?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        final userDoc = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(userCredential.user!.uid)
            .get()
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw Exception('Timeout getting user data from Firestore');
              },
            );

        if (userDoc.exists) {
          return UserModel.fromFirestore(userDoc);
        }
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel?> signInWithGoogle() async {
    _profileBootstrapInFlight++;
    try {
      final UserCredential userCredential;
      if (kIsWeb) {
        userCredential = await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await _auth.signInWithCredential(credential);
      }

      if (userCredential.user != null) {
        final userDoc = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(userCredential.user!.uid)
            .get();

        if (userDoc.exists) {
          return UserModel.fromFirestore(userDoc);
        } else {
          final now = DateTime.now();
          final userModel = UserModel(
            id: userCredential.user!.uid,
            email: userCredential.user!.email!,
            displayName: userCredential.user!.displayName,
            photoUrl: userCredential.user!.photoURL,
            createdAt: now,
            termsAcceptedAt: now,
            isStoreOpen: true,
            sellerAvailability: SellerAvailability.online,
            role: UserRole.customer,
          );

          final outcome = await _createProfileIfAbsent(
            userCredential.user!.uid,
            userModel,
          );

          if (outcome.created ||
              (userCredential.additionalUserInfo?.isNewUser ?? false)) {
            await _writeContact(userCredential.user!.uid, userModel);
            try {
              await LegalConsentService().record(consentContext: 'signup');
            } catch (e) {
              if (kDebugMode) print('⚠️ consent record failed (non-fatal): $e');
            }
          }

          return outcome.profile;
        }
      }
      return null;
    } catch (e) {
      rethrow;
    } finally {
      _profileBootstrapInFlight--;
    }
  }

  Future<UserModel?> signInAsGuest() async {
    _profileBootstrapInFlight++;
    try {
      final userCredential = await _auth.signInAnonymously();
      final user = userCredential.user;
      if (user == null) return null;
      final now = DateTime.now();
      final guest = UserModel(
        id: user.uid,
        email: '',
        displayName: 'אורח ${user.uid.substring(0, 4).toUpperCase()}',
        createdAt: now,
        termsAcceptedAt: now,
        isStoreOpen: true,
        sellerAvailability: SellerAvailability.online,
        role: UserRole.customer,
      );
      final outcome = await _createProfileIfAbsent(user.uid, guest);
      return outcome.profile;
    } finally {
      _profileBootstrapInFlight--;
    }
  }

  Future<void> signOut() async {
    await _guarded(
      'notification token',
      () => NotificationCoordinator.instance.prepareForSignOut(),
    );

    await Future.wait([_auth.signOut(), if (!kIsWeb) _googleSignIn.signOut()]);
  }

  Future<void> _guarded(String what, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (kDebugMode) print('⚠️ sign-out teardown "$what" failed: $e');
    }
  }

  Future<UserModel?> getUserData(String userId) async {
    try {
      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();

      if (userDoc.exists) {
        return UserModel.fromFirestore(userDoc);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Stream<UserModel?> getUserDataStream(String userId) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .snapshots()
        .asyncMap((snapshot) async {
          if (snapshot.exists) {
            final base = UserModel.fromFirestore(snapshot);
            try {
              final contact = UserContact.fromDoc(
                await UserContact.ref(userId).get(),
              );
              return base.copyWith(
                email: contact.email ?? base.email,
                phoneNumber: contact.phoneNumber ?? base.phoneNumber,
                address: contact.address ?? base.address,
                location: contact.location ?? base.location,
              );
            } catch (_) {
              return base;
            }
          } else {
            if (_profileBootstrapInFlight > 0) return null;

            final firebaseUser = _auth.currentUser;
            if (firebaseUser != null && firebaseUser.uid == userId) {
              final userModel = UserModel(
                id: userId,
                email: firebaseUser.email ?? '',
                displayName: firebaseUser.displayName ?? 'User',
                photoUrl: firebaseUser.photoURL,
                createdAt: DateTime.now(),
                isStoreOpen: true,
                sellerAvailability: null,
                role: UserRole.customer,
              );

              final outcome = await _createProfileIfAbsent(userId, userModel);
              return outcome.profile;
            }
            return null;
          }
        });
  }

  Future<void> updateUserData(
    String userId,
    Map<String, dynamic> data, {
    bool allowRestrictedKeys = false,
  }) async {
    try {
      if (!allowRestrictedKeys) {
        final blocked = data.keys
            .where(UserModel.clientImmutableUpdateKeys.contains)
            .toList();
        if (blocked.isNotEmpty) {
          throw ArgumentError(
            'updateUserData(users/$userId): the /users security rule forbids a '
            'client from changing ${blocked.join(', ')}. Send only the fields '
            'being edited (never a full toFirestore() map); admin/CF callers '
            'must pass allowRestrictedKeys: true.',
          );
        }
      }
      if (data.isEmpty) return;

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateProfile({
    String? displayName,
    String? phoneNumber,
    String? photoUrl,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }

      final Map<String, dynamic> updates = {};
      if (displayName != null) updates['displayName'] = displayName;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;

      if (updates.isNotEmpty) {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .update(updates);
      }

      if (phoneNumber != null) {
        await UserContact.ref(user.uid).set(
          UserContact(phoneNumber: phoneNumber).toMap(),
          SetOptions(merge: true),
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<({bool created, UserModel profile})> _createProfileIfAbsent(
    String uid,
    UserModel desired,
  ) async {
    final docRef = _firestore.collection(AppConstants.usersCollection).doc(uid);
    return _firestore.runTransaction<({bool created, UserModel profile})>((
      transaction,
    ) async {
      final snapshot = await transaction.get(docRef);
      if (snapshot.exists) {
        try {
          return (created: false, profile: UserModel.fromFirestore(snapshot));
        } catch (e) {
          if (kDebugMode) print('⚠️ Unparsable user doc $uid: $e');
          return (created: false, profile: desired);
        }
      }
      transaction.set(docRef, desired.toFirestore());
      return (created: true, profile: desired);
    });
  }

  Future<UserModel> _reconcileRacedProfile(
    String uid, {
    required UserModel desired,
    required UserModel existing,
  }) async {
    final docRef = _firestore.collection(AppConstants.usersCollection).doc(uid);
    final safeUpdates = desired.toFirestoreProfileUpdate();
    try {
      if (safeUpdates.isNotEmpty) await docRef.update(safeUpdates);
    } catch (e) {
      if (kDebugMode) print('⚠️ Could not apply signup profile fields: $e');
    }

    if (existing.role != desired.role && kDebugMode) {
      print(
        '⚠️ Profile for $uid was created with role ${existing.role.name}; '
        'the /users rule blocklists role, so this needs a server-side repair.',
      );
    }

    try {
      final fresh = await docRef.get();
      if (fresh.exists) return UserModel.fromFirestore(fresh);
    } catch (e) {
      if (kDebugMode) print('⚠️ Could not re-read user doc $uid: $e');
    }
    return existing;
  }

  Future<void> _writeContact(String uid, UserModel user) async {
    try {
      await UserContact.ref(uid).set(
        UserContact(
          email: user.email,
          phoneNumber: user.phoneNumber,
          address: user.address,
          location: user.location,
        ).toMap(),
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to write contact doc for $uid: $e');
    }
  }

  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .delete();

        await user.delete();
      }
    } catch (e) {
      rethrow;
    }
  }
}
