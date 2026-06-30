import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import 'user_profile_screen.dart';

class PalRequestsScreen extends StatefulWidget {
  const PalRequestsScreen({super.key});

  @override
  State<PalRequestsScreen> createState() => _PalRequestsScreenState();
}

class _PalRequestsScreenState extends State<PalRequestsScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  static String _palDocId(String owner, String other) => '${owner}_$other';

  Future<void> _acceptRequest(
      String requestId, String fromUid, String fromName) async {
    final fs = FirebaseFirestore.instance;
    final myPalId = _palDocId(_uid, fromUid);
    final theirPalId = _palDocId(fromUid, _uid);

    final batch = fs.batch();
    batch.set(fs.collection('pals').doc(myPalId), {
      'uid': _uid,
      'otherUid': fromUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(fs.collection('pals').doc(theirPalId), {
      'uid': fromUid,
      'otherUid': _uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.delete(fs.collection('palRequests').doc(requestId));
    await batch.commit();

    // Notify the original requester that their request was accepted.
    final meDoc = await fs.collection('users').doc(_uid).get();
    final myName = meDoc.data()?['name'] ?? 'Farmer';
    await fs.collection('notifications').doc(fromUid).collection('items').add({
      'type': 'pal_accept',
      'fromUid': _uid,
      'fromName': myName,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteRequest(String requestId) async {
    await FirebaseFirestore.instance
        .collection('palRequests')
        .doc(requestId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.greenDark,
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.of(context).padding.top + 8,
                16,
                16,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Pal Requests',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('palRequests')
                .where('toUid', isEqualTo: _uid)
                .where('status', isEqualTo: 'pending')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.greenDark),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 48,
                          color: AppColors.textSecondary.withOpacity(0.4),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No pal requests',
                          style: TextStyle(
                              fontSize: 15, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Requests from other farmers will show up here.',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final doc = docs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    return _RequestRow(
                      requestId: doc.id,
                      fromUid: data['fromUid'] ?? '',
                      onAccept: (name) =>
                          _acceptRequest(doc.id, data['fromUid'] ?? '', name),
                      onDelete: () => _deleteRequest(doc.id),
                      initials: _initials,
                    );
                  },
                  childCount: docs.length,
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

// ── Individual request row ───────────────────────────────────────────────────

class _RequestRow extends StatefulWidget {
  final String requestId;
  final String fromUid;
  final void Function(String fromName) onAccept;
  final VoidCallback onDelete;
  final String Function(String) initials;

  const _RequestRow({
    required this.requestId,
    required this.fromUid,
    required this.onAccept,
    required this.onDelete,
    required this.initials,
  });

  @override
  State<_RequestRow> createState() => _RequestRowState();
}

class _RequestRowState extends State<_RequestRow> {
  bool _busy = false;

  Future<void> _handleAccept(String name) async {
    setState(() => _busy = true);
    try {
      widget.onAccept(name);
    } finally {
      // No need to reset _busy — the row disappears once the request
      // doc is deleted and the stream above rebuilds the list.
    }
  }

  Future<void> _handleDelete() async {
    setState(() => _busy = true);
    try {
      widget.onDelete();
    } finally {
      // Row disappears via stream once deleted.
    }
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          profileUid: widget.fromUid,
          incomingRequestId: widget.requestId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.fromUid)
          .get(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        final name = data?['name'] ?? 'Farmer';
        final location = data?['location'] ?? '';

        return Column(
          children: [
            InkWell(
              onTap: _openProfile,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.greenLight,
                      child: Text(
                        widget.initials(name),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.greenDeep,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (location.toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                location,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_busy)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => _handleAccept(name),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: AppColors.greenDark,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.chip),
                              ),
                              child: const Text(
                                'Accept',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: _handleDelete,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: AppColors.background2,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.chip),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Text(
                                'Delete',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.border, indent: 64),
          ],
        );
      },
    );
  }
}
