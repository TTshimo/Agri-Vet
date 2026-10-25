import 'package:cloud_firestore/cloud_firestore.dart';

/// Deletes everything a user created, from the app itself (free plan, no
/// Cloud Functions). Run it right before deleting the login, while the user
/// is still signed in; the Firestore rules allow each of these deletes.
class AccountCleanup {
  AccountCleanup._();

  static final _db = FirebaseFirestore.instance;

  static Future<void> deleteAllDataOf(String uid) async {
    final refs = <DocumentReference>[];

    Future<void> collect(Query<Map<String, dynamic>> query) async {
      final snap = await query.get();
      refs.addAll(snap.docs.map((d) => d.reference));
    }

    // My posts, with every comment on them.
    final posts = await _db.collection('posts').where('uid', isEqualTo: uid).get();
    for (final post in posts.docs) {
      await collect(post.reference.collection('comments'));
      refs.add(post.reference);
    }
    // My comments on other people's posts.
    await collect(_db.collectionGroup('comments').where('uid', isEqualTo: uid));

    await collect(_db.collection('diagnoses').where('uid', isEqualTo: uid));
    await collect(_db.collection('palRequests').where('fromUid', isEqualTo: uid));
    await collect(_db.collection('palRequests').where('toUid', isEqualTo: uid));
    await collect(_db.collection('pals').where('uid', isEqualTo: uid));
    await collect(_db.collection('pals').where('otherUid', isEqualTo: uid));

    // My conversations, with their messages.
    final convs = await _db
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .get();
    for (final conv in convs.docs) {
      await collect(conv.reference.collection('messages'));
      refs.add(conv.reference);
    }

    await collect(_db.collection('notifications').doc(uid).collection('items'));
    await collect(_db.collection('users').doc(uid).collection('private'));
    refs.add(_db.collection('users').doc(uid));

    // Firestore batches hold up to 500 writes; children are listed before
    // their parents, so order is kept across batches.
    final seen = <String>{};
    final unique = refs.where((r) => seen.add(r.path)).toList();
    for (var i = 0; i < unique.length; i += 400) {
      final batch = _db.batch();
      for (final ref in unique.skip(i).take(400)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }
}
