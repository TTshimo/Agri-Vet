import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Makes sure every signed-in user has a profile doc (users/{uid}).
///
/// Accounts made before the registration form wrote one, or by Google
/// sign-in, could be missing it; then Profile said "Your name", posts showed
/// "Farmer", and post/diagnosis counters failed to save.
class ProfileService {
  ProfileService._();

  static Future<void> ensureProfile(User user, {String signInMethod = 'password'}) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (snap.exists && (snap.data()?['name'] as String?)?.trim().isNotEmpty == true) {
      return;
    }
    final emailName = (user.email ?? '').split('@').first;
    await ref.set({
      if (!snap.exists) ...{
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
        'signInMethod': signInMethod,
        'createdAt': FieldValue.serverTimestamp(),
      },
      // A profile with no name shows as "Farmer" everywhere; use the
      // Google name, or the email's first part, until they set one.
      'name': (user.displayName?.trim().isNotEmpty == true)
          ? user.displayName!.trim()
          : emailName,
    }, SetOptions(merge: true));
  }
}
