import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import 'user_profile_screen.dart';

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
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'Pals',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search pals...',
                      hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5), fontSize: 14),
                      prefixIcon: Icon(Icons.search,
                          color: Colors.white.withOpacity(0.6), size: 20),
                      suffixIcon: _query.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              child: Icon(Icons.close,
                                  color: Colors.white.withOpacity(0.6),
                                  size: 18),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.12),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ],
              ),
            ),
          ),

          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _palStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.greenDark),
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
                        Icon(
                          Icons.diversity_3_rounded,
                          size: 48,
                          color: AppColors.textSecondary.withOpacity(0.4),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No pals yet',
                          style: TextStyle(
                              fontSize: 15, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Head to Make a Pal to connect with farmers.',
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

                        return Column(
                          children: [
                            InkWell(
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
                                    horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: AppColors.greenLight,
                                      child: Text(
                                        _initials(name),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                              padding: const EdgeInsets.only(
                                                  top: 2),
                                              child: Text(
                                                location,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: AppColors.textSecondary,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Divider(
                                height: 1,
                                color: AppColors.border,
                                indent: 64),
                          ],
                        );
                      },
                    );
                  },
                  childCount: pals.length,
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
