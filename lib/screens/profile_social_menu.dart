import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import 'make_pal_screen.dart';
import 'pal_requests_screen.dart';
import 'pals_screen.dart';
import 'blocked_list_screen.dart';
import 'notifications_screen.dart';
import 'messaging_screen.dart';

class ProfileSocialMenu extends StatelessWidget {
  final Color cardColor;
  final Color borderColor;

  const ProfileSocialMenu({
    super.key,
    required this.cardColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          _MenuRow(
            icon: Icons.notifications_none_rounded,
            label: 'Notifications',
            borderColor: borderColor,
            countStream: FirebaseFirestore.instance
                .collection('notifications')
                .doc(uid)
                .collection('items')
                .where('read', isEqualTo: false)
                .snapshots()
                .map((s) => s.docs.length),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
          Divider(height: 1, color: borderColor, indent: 56),
          _MenuRow(
            icon: Icons.person_add_alt_1_rounded,
            label: 'Pal Requests',
            borderColor: borderColor,
            countStream: FirebaseFirestore.instance
                .collection('palRequests')
                .where('toUid', isEqualTo: uid)
                .where('status', isEqualTo: 'pending')
                .snapshots()
                .map((s) => s.docs.length),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PalRequestsScreen()),
            ),
          ),
          Divider(height: 1, color: borderColor, indent: 56),
          _MenuRow(
            icon: Icons.diversity_3_rounded,
            label: 'Pals',
            borderColor: borderColor,
            countStream: FirebaseFirestore.instance
                .collection('pals')
                .where('uid', isEqualTo: uid)
                .snapshots()
                .map((s) => s.docs.length),
            showCountAlways: true, // total, not just "unseen"
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PalsScreen()),
            ),
          ),
          Divider(height: 1, color: borderColor, indent: 56),
          _MenuRow(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Messages',
            borderColor: borderColor,
            countStream: FirebaseFirestore.instance
                .collection('conversations')
                .where('participants', arrayContains: uid)
                .snapshots()
                .map((s) => s.docs.fold<int>(0, (sum, doc) {
                      final data = doc.data();
                      final unread =
                          (data['unreadCounts'] as Map<String, dynamic>?)?[uid] ??
                              0;
                      return sum + (unread as num).toInt();
                    })),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MessagingScreen()),
            ),
          ),
          Divider(height: 1, color: borderColor, indent: 56),
          _MenuRow(
            icon: Icons.block_rounded,
            label: 'Blocked Farmers',
            borderColor: borderColor,
            countStream: null, // no badge needed for this one
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BlockedListScreen()),
            ),
          ),
          Divider(height: 1, color: borderColor, indent: 56),
          _MenuRow(
            icon: Icons.group_add_rounded,
            label: 'Make a Pal',
            borderColor: borderColor,
            countStream: null,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MakePalScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color borderColor;
  final Stream<int>? countStream;
  final bool showCountAlways;
  final VoidCallback onTap;

  const _MenuRow({
    required this.icon,
    required this.label,
    required this.borderColor,
    required this.countStream,
    required this.onTap,
    this.showCountAlways = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.greenDark),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (countStream != null)
              StreamBuilder<int>(
                stream: countStream,
                builder: (context, snap) {
                  final count = snap.data ?? 0;
                  if (count == 0 && !showCountAlways) {
                    return const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textSecondary, size: 20);
                  }
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: showCountAlways
                              ? borderColor.withOpacity(0.5)
                              : AppColors.greenDark,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: showCountAlways
                                ? AppColors.textSecondary
                                : Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textSecondary, size: 20),
                    ],
                  );
                },
              )
            else
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
