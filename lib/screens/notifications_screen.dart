import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';
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
  static const danger = Color(0xFFC94C3F);
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

enum NotificationType {
  like,
  comment,
  reply,
  palRequest,
  palAccept,
  msgRequest,
  msgAccept,
  message,
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
    case 'message':
      return NotificationType.message;
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
      case NotificationType.message:
        final conversationId = data['conversationId'] as String?;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => conversationId != null
                ? ChatScreen(
                    conversationId: conversationId,
                    currentUid: _uid,
                    otherUid: fromUid,
                    otherName: (data['fromName'] as String?) ?? 'Farmer',
                  )
                : UserProfileScreen(profileUid: fromUid),
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
      case NotificationType.message:
        return Icons.chat_rounded;
      case NotificationType.unknown:
        return Icons.notifications_rounded;
    }
  }

  Color _iconColorFor(NotificationType type) {
    switch (type) {
      case NotificationType.like:
        return _C.danger;
      case NotificationType.palRequest:
      case NotificationType.palAccept:
        return _C.matcha;
      case NotificationType.msgRequest:
      case NotificationType.msgAccept:
      case NotificationType.message:
        return _C.rust;
      default:
        return _C.inkSoft;
    }
  }

  String _messageFor(NotificationType type, String fromName,
      [Map<String, dynamic>? data]) {
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
      case NotificationType.message:
        final preview = (data?['preview'] as String?) ?? '';
        return preview.isEmpty
            ? '$fromName sent you a message'
            : '$fromName: $preview';
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
                    Expanded(
                      child: Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: _C.almond,
                        ),
                      ),
                    ),
                    StreamBuilder<QuerySnapshot>(
                      stream: itemsRef.snapshots(),
                      builder: (context, snapshot) {
                        final docs = snapshot.data?.docs ?? [];
                        final hasUnread = docs.any((d) =>
                            (d.data() as Map<String, dynamic>)['read'] !=
                            true);
                        if (!hasUnread) return const SizedBox.shrink();
                        return TextButton(
                          onPressed: () => _markAllRead(docs),
                          child: Text(
                            'Mark all read',
                            style: TextStyle(
                              color: _C.matchaLight,
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
          ),

          StreamBuilder<QuerySnapshot>(
            stream: itemsRef.snapshots(),
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
                            Icons.notifications_none_rounded,
                            size: 26,
                            color: _C.matcha.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No notifications yet',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: _C.ink),
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
                      final type = _typeFromString(data['type']);
                      final fromName = data['fromName'] ?? 'Farmer';
                      final isRead = data['read'] == true;
                      final ts = data['createdAt'] as Timestamp?;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isRead
                              ? Colors.white
                              : _C.matchaLight.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(16),
                          border: isRead
                              ? null
                              : Border.all(
                                  color: _C.matcha.withOpacity(0.25)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _handleTap(doc.id, data),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: _C.matchaLight,
                                      child: Text(
                                        _initials(fromName),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _C.matchaDark,
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
                                              color: _C.almond, width: 2),
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
                                    _messageFor(type, fromName, data),
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: isRead
                                          ? FontWeight.w400
                                          : FontWeight.w500,
                                      color: _C.ink,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _timeAgo(ts),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _C.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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