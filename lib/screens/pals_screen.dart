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
  static const muted = Color(0xFFB8AE97);
}

/// Bottom wave finishing off the dark matcha header band — same shape
/// used across the other restyled screens for a consistent silhouette.
class _HeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height * 0.68)
      ..cubicTo(
        size.width * 0.32, size.height,
        size.width * 0.66, size.height * 0.44,
        size.width, size.height * 0.72,
      )
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class PalsScreen extends StatefulWidget {
  const PalsScreen({super.key});

  @override
  State<PalsScreen> createState() => _PalsScreenState();
}

class _PalsScreenState extends State<PalsScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Stream<List<Map<String, dynamic>>> _palStream() {
    return FirebaseFirestore.instance
        .collection('pals')
        .where('uid', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              return {
                'palId': doc.id,
                'otherUid': data['otherUid'],
                'createdAt': data['createdAt'],
              };
            }).toList());
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
                  16,
                  MediaQuery.of(context).padding.top + 8,
                  16,
                  36,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.arrow_back_ios_new_rounded,
                              color: _C.almond, size: 18),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            'Pals',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: _C.almond,
                            ),
                          ),
                        ),
                        const SizedBox(width: 34),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchController,
                      style: TextStyle(color: _C.almond, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search pals...',
                        hintStyle: TextStyle(
                            color: _C.almond.withOpacity(0.5), fontSize: 14),
                        prefixIcon: Icon(Icons.search,
                            color: _C.almond.withOpacity(0.6), size: 20),
                        suffixIcon: _query.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                child: Icon(Icons.close,
                                    color: _C.almond.withOpacity(0.6),
                                    size: 18),
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.12),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ],
                ),
              ),
            ),
          ),

          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _palStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: _C.matcha),
                  ),
                );
              }

              final pals = snapshot.data ?? [];

              if (pals.isEmpty) {
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
                            Icons.diversity_3_rounded,
                            size: 26,
                            color: _C.matcha.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No pals yet',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: _C.ink),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Head to Make a Pal to connect with farmers.',
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
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(pals[i]['otherUid'])
                            .get(),
                        builder: (context, userSnap) {
                          final data =
                              userSnap.data?.data() as Map<String, dynamic>?;
                          final name = data?['name'] ?? 'Farmer';
                          final location = data?['location'] ?? '';

                          if (_query.isNotEmpty &&
                              !name.toString().toLowerCase().contains(
                                  _query.toLowerCase())) {
                            return const SizedBox.shrink();
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UserProfileScreen(
                                    profileUid: pals[i]['otherUid'],
                                  ),
                                ),
                              ),
                              child: Padding(
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
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                              padding: const EdgeInsets.only(
                                                  top: 2),
                                              child: Text(
                                                location,
                                                style: TextStyle(
                                                    fontSize: 11.5,
                                                    color: _C.inkSoft),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: _C.muted,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    childCount: pals.length,
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