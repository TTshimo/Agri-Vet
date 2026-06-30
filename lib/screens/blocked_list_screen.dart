import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';

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
                    'Blocked Farmers',
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

          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.greenDark),
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
                        Icon(
                          Icons.block_rounded,
                          size: 48,
                          color: AppColors.textSecondary.withOpacity(0.4),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No blocked farmers',
                          style: TextStyle(
                              fontSize: 15, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Farmers you block will show up here.',
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

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor:
                                        AppColors.border.withOpacity(0.6),
                                    child: Text(
                                      _initials(name),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  isUnblocking
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : GestureDetector(
                                          onTap: () => _unblock(otherUid),
                                          child: Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 7),
                                            decoration: BoxDecoration(
                                              color: AppColors.background2,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppRadius.chip),
                                              border: Border.all(
                                                  color: AppColors.border),
                                            ),
                                            child: const Text(
                                              'Unblock',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color:
                                                    AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ),
                                ],
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
                  childCount: blocked.length,
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
