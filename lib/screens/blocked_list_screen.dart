import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  static const muted = Color(0xFFB8AE97);
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

class BlockedListScreen extends StatefulWidget {
  const BlockedListScreen({super.key});

  @override
  State<BlockedListScreen> createState() => _BlockedListScreenState();
}

class _BlockedListScreenState extends State<BlockedListScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  final _unblocking = <String>{};

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Future<void> _unblock(String otherUid) async {
    setState(() => _unblocking.add(otherUid));
    try {
      await FirebaseFirestore.instance.collection('users').doc(_uid).update({
        'blockedUids': FieldValue.arrayRemove([otherUid]),
      });
    } finally {
      if (mounted) setState(() => _unblocking.remove(otherUid));
    }
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
                      'Blocked farmers',
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

          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: _C.matcha),
                  ),
                );
              }

              final data = snapshot.data?.data() as Map<String, dynamic>?;
              final blocked = List<String>.from(data?['blockedUids'] ?? []);

              if (blocked.isEmpty) {
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
                            Icons.block_rounded,
                            size: 26,
                            color: _C.matcha.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No blocked farmers',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: _C.ink),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Farmers you block will show up here.',
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
                      final otherUid = blocked[i];
                      final isUnblocking = _unblocking.contains(otherUid);

                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(otherUid)
                            .get(),
                        builder: (context, userSnap) {
                          final userData =
                              userSnap.data?.data() as Map<String, dynamic>?;
                          final name = userData?['name'] ?? 'Farmer';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: _C.matchaLight,
                                  child: Text(
                                    _initials(name),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: _C.matchaDark,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      color: _C.ink,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                isUnblocking
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _C.rust,
                                        ),
                                      )
                                    : GestureDetector(
                                        onTap: () => _unblock(otherUid),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: _C.rust.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                                color:
                                                    _C.rust.withOpacity(0.4)),
                                          ),
                                          child: Text(
                                            'Unblock',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: _C.rust,
                                            ),
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    childCount: blocked.length,
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