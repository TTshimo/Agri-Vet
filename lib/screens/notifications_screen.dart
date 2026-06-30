import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import 'user_profile_screen.dart';

enum NotificationType {
  like,
  comment,
  reply,
  palRequest,
  palAccept,
  msgRequest,
  msgAccept,
  unknown,
}

NotificationType _typeFromString(String? raw) {
  switch (raw) {
    case 'like':
      return NotificationType.like;
    case 'comment':
      return NotificationType.comment;
    case 'reply':
      return NotificationType.reply;
    case 'pal_request':
      return NotificationType.palRequest;
    case 'pal_accept':
      return NotificationType.palAccept;
    case 'msg_request':
      return NotificationType.msgRequest;
    case 'msg_accept':
      return NotificationType.msgAccept;
    default:
      return NotificationType.unknown;
  }
}

class NotificationsScreen extends StatefulWidget {
  final void Function(String postId)? onOpenPost;

  const NotificationsScreen({super.key, this.onOpenPost});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('d MMM').format(dt);
  }

  Future<void> _markRead(String itemId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(_uid)
        .collection('items')
        .doc(itemId)
        .update({'read': true});
  }

  Future<void> _markAllRead(List<QueryDocumentSnapshot> docs) async {
    final unread = docs.where((d) =>
        (d.data() as Map<String, dynamic>)['read'] != true);
    if (unread.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in unread) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  void _handleTap(String itemId, Map<String, dynamic> data) {
    _markRead(itemId);
    final type = _typeFromString(data['type']);
    final fromUid = data['fromUid'] ?? '';

    switch (type) {
      case NotificationType.like:
      case NotificationType.comment:
      case NotificationType.reply:
        final postId = data['postId'] as String?;
        if (postId != null && widget.onOpenPost != null) {
          widget.onOpenPost!(postId);
        } else {
          Navigator.pop(context);
        }
        break;

      case NotificationType.palRequest:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(
              profileUid: fromUid,
              incomingRequestId: data['requestId'] as String?,
            ),
          ),
        );
        break;

      case NotificationType.palAccept:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(profileUid: fromUid),
          ),
        );
        break;

      case NotificationType.msgRequest:
      case NotificationType.msgAccept:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(profileUid: fromUid),
          ),
        );
        break;

      case NotificationType.unknown:
        break;
    }
  }

  IconData _iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.like:
        return Icons.favorite_rounded;
      case NotificationType.comment:
        return Icons.chat_bubble_rounded;
      case NotificationType.reply:
        return Icons.reply_rounded;
      case NotificationType.palRequest:
        return Icons.person_add_alt_1_rounded;
      case NotificationType.palAccept:
        return Icons.diversity_3_rounded;
      case NotificationType.msgRequest:
        return Icons.mark_email_unread_rounded;
      case NotificationType.msgAccept:
        return Icons.check_circle_rounded;
      case NotificationType.unknown:
        return Icons.notifications_rounded;
    }
  }

  Color _iconColorFor(NotificationType type) {
    switch (type) {
      case NotificationType.like:
        return AppColors.red;
      case NotificationType.palRequest:
      case NotificationType.palAccept:
        return AppColors.greenDark;
      case NotificationType.msgRequest:
      case NotificationType.msgAccept:
        return AppColors.amberText;
      default:
        return AppColors.textSecondary;
    }
  }

  String _messageFor(NotificationType type, String fromName) {
    switch (type) {
      case NotificationType.like:
        return '$fromName liked your post';
      case NotificationType.comment:
        return '$fromName commented on your post';
      case NotificationType.reply:
        return '$fromName replied to your comment';
      case NotificationType.palRequest:
        return '$fromName sent you a pal request';
      case NotificationType.palAccept:
        return '$fromName accepted your pal request';
      case NotificationType.msgRequest:
        return '$fromName sent you a message request';
      case NotificationType.msgAccept:
        return '$fromName accepted your message request';
      case NotificationType.unknown:
        return 'New notification';
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final itemsRef = FirebaseFirestore.instance
        .collection('notifications')
        .doc(_uid)
        .collection('items')
        .orderBy('createdAt', descending: true)
        .limit(100);

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
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: itemsRef.snapshots(),
                    builder: (context, snapshot) {
                      final docs = snapshot.data?.docs ?? [];
                      final hasUnread = docs.any((d) =>
                          (d.data() as Map<String, dynamic>)['read'] != true);
                      if (!hasUnread) return const SizedBox.shrink();
                      return TextButton(
                        onPressed: () => _markAllRead(docs),
                        child: const Text(
                          'Mark all read',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          StreamBuilder<QuerySnapshot>(
            stream: itemsRef.snapshots(),
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
                          Icons.notifications_none_rounded,
                          size: 48,
                          color: AppColors.textSecondary.withOpacity(0.4),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No notifications yet',
                          style: TextStyle(
                              fontSize: 15, color: AppColors.textSecondary),
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
                    final type = _typeFromString(data['type']);
                    final fromName = data['fromName'] ?? 'Farmer';
                    final isRead = data['read'] == true;
                    final ts = data['createdAt'] as Timestamp?;

                    return InkWell(
                      onTap: () => _handleTap(doc.id, data),
                      child: Container(
                        color: isRead
                            ? Colors.transparent
                            : AppColors.greenLight.withOpacity(0.25),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: AppColors.greenLight,
                                        child: Text(
                                          _initials(fromName),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.greenDeep,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: -2,
                                        bottom: -2,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: AppColors.background,
                                                width: 2),
                                          ),
                                          child: Icon(
                                            _iconFor(type),
                                            size: 11,
                                            color: _iconColorFor(type),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _messageFor(type, fromName),
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: isRead
                                            ? FontWeight.w400
                                            : FontWeight.w500,
                                        color: AppColors.textPrimary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _timeAgo(ts),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
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
                        ),
                      ),
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
