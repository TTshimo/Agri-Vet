import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_profile_screen.dart';

/// AgroLens palette — matcha green / almond / white, light module variant.
class _C {
  static const matchaDark = Color(0xFF374530);
  static const matcha = Color(0xFF5C7148);
  static const matchaLight = Color(0xFFD6E0C4);
  static const almond = Color(0xFFF6EFE2);
  static const ink = Color(0xFF2B2820);
  static const inkSoft = Color(0xFF726C5C);
  static const rust = Color(0xFFC1703E);
  static const hairline = Color(0xFFEDE6D6);
}

/// Bottom wave finishing off the dark matcha header band — same shape
/// used across the other restyled screens for a consistent silhouette.
class _HeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height * 0.62)
      ..cubicTo(
        size.width * 0.32, size.height,
        size.width * 0.66, size.height * 0.4,
        size.width, size.height * 0.68,
      )
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

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
      backgroundColor: _C.almond,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: ClipPath(
              clipper: _HeaderWaveClipper(),
              child: Container(
                color: _C.matchaDark,
                padding: EdgeInsets.fromLTRB(
                  8,
                  MediaQuery.of(context).padding.top + 8,
                  16,
                  40,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded,
                          color: _C.almond, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Pal requests',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: _C.almond,
                      ),
                    ),
                  ],
                ),
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
                return SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: _C.matcha),
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
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: _C.matchaLight.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 26,
                            color: _C.matcha.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No pal requests',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: _C.ink),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Requests from other farmers will show up here.',
                          style: TextStyle(fontSize: 12.5, color: _C.inkSoft),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverList(
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

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _openProfile,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _C.matchaLight,
                    child: Text(
                      widget.initials(name),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _C.matchaDark,
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
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: _C.ink,
                          ),
                        ),
                        if (location.toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              location,
                              style: TextStyle(fontSize: 11.5, color: _C.inkSoft),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_busy)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _C.rust),
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
                              color: _C.rust,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Accept',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _C.almond,
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
                              color: _C.almond,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: _C.hairline),
                            ),
                            child: Text(
                              'Delete',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _C.inkSoft,
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
        );
      },
    );
  }
}