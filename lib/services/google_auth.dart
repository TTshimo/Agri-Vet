import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// "Continue with Google" through Firebase Authentication.
///
/// Needs, in the Firebase console: Google enabled under Authentication →
/// Sign-in method, and the app's SHA-1/SHA-256 fingerprints added under
/// Project settings → Android app (then a fresh google-services.json).
class GoogleAuth {
  GoogleAuth._();

  static final _google = GoogleSignIn(scopes: const ['email']);

  /// Signs in and returns the Firebase user, or null if the user closed
  /// the Google account picker. Creates a profile for first-time users.
  static Future<User?> signIn() async {
    final UserCredential result;
    if (kIsWeb) {
      result = await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
    } else {
      final credential = await _credential();
      if (credential == null) return null;
      result = await FirebaseAuth.instance.signInWithCredential(credential);
    }
    final user = result.user;
    if (user != null) await _ensureProfile(user);
    return user;
  }

  /// Confirms identity again (Firebase asks for this before deleting an
  /// account). Returns false if the user cancelled.
  static Future<bool> reauthenticate(User user) async {
    if (kIsWeb) {
      await user.reauthenticateWithPopup(GoogleAuthProvider());
      return true;
    }
    final credential = await _credential();
    if (credential == null) return false;
    await user.reauthenticateWithCredential(credential);
    return true;
  }

  /// True when this account signs in with Google (not a password).
  static bool usesGoogle(User user) =>
      user.providerData.any((p) => p.providerId == GoogleAuthProvider.PROVIDER_ID);

  /// Also forget the Google account on this phone, so the account picker
  /// shows next time instead of silently reusing the last account.
  static Future<void> signOut() async {
    if (kIsWeb) return;
    try {
      await _google.signOut();
    } catch (_) {
      // Not signed in with Google on this device.
    }
  }

  static Future<AuthCredential?> _credential() async {
    final account = await _google.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    return GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
  }

  /// Google users skip the registration form, so give them the same
  /// profile fields it creates. They can fill in farm details later.
  static Future<void> _ensureProfile(User user) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (snap.exists) return;
    await ref.set({
      'name': user.displayName ?? 'Farmer',
      'email': user.email ?? '',
      'phone': user.phoneNumber ?? '',
      'farmerType': 'both',
      'farmName': '',
      'location': '',
      'animalsKept': <String>[],
      'soilType': '',
      'waterSource': '',
      'yearsFarming': '',
      'photoUrl': user.photoURL ?? '',
      'signInMethod': 'google',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
