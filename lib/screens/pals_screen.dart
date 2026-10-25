import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_profile_screen.dart';
import '../theme/palette.dart';
import '../theme/header_wave.dart';


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
      backgroundColor: Bg.almond,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: ClipPath(
              clipper: const HeaderWaveClipper(),
              child: Container(
                color: Bg.matchaDark,
                padding: EdgeInsets.fromLTRB(
                  16,
                  MediaQuery.of(context).padding.top + 8,
                  16,
                  56,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.arrow_back_ios_new_rounded,
                              color: Fg.almond, size: 18),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            'Pals',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Fg.almond,
                            ),
                          ),
                        ),
                        const SizedBox(width: 34),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchController,
                      style: TextStyle(color: Fg.almond, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search pals...',
                        hintStyle: TextStyle(
                            color: Fg.almond.withOpacity(0.5), fontSize: 14),
                        prefixIcon: Icon(Icons.search,
                            color: Fg.almond.withOpacity(0.6), size: 20),
                        suffixIcon: _query.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                child: Icon(Icons.close,
                                    color: Fg.almond.withOpacity(0.6),
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
                    child: CircularProgressIndicator(color: Fg.matcha),
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
                            color: Bg.matchaLight.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.diversity_3_rounded,
                            size: 26,
                            color: Fg.matcha.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No pals yet',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Fg.ink),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Head to Make a Pal to connect with farmers.',
                          style: TextStyle(fontSize: 12.5, color: Fg.inkSoft),
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
                              color: Bg.surface,
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
                                      backgroundColor: Bg.matchaLight,
                                      child: Text(
                                        _initials(name),
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: Fg.matchaDark,
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
                                              color: Fg.ink,
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
                                                    color: Fg.inkSoft),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: Fg.muted,
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