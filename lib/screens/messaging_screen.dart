import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';
import '../theme/palette.dart';

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

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
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

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  void _startNewConversation() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewConversationSheet(currentUid: _uid),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Bg.almond,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: ClipPath(
              clipper: _HeaderWaveClipper(),
              child: Container(
                color: Bg.matchaDark,
                // Same header as the other pages opened from Profile
                // (Settings, Notifications, Pals): back arrow + 17px title.
                padding: EdgeInsets.fromLTRB(
                  8,
                  MediaQuery.of(context).padding.top + 8,
                  16,
                  40,
                ),
                child: Row(
                  children: [
                    if (Navigator.of(context).canPop())
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                            color: Fg.almond, size: 18),
                        onPressed: () => Navigator.pop(context),
                      )
                    else
                      const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Messages',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Fg.almond,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _startNewConversation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Bg.rust,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined,
                                color: Fg.almond, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'New',
                              style: TextStyle(
                                color: Fg.almond,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Conversations list
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('conversations')
                .where('participants', arrayContains: _uid)
                .orderBy('lastMessageAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: Fg.matcha),
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
                            color: Bg.matchaLight.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 26,
                            color: Fg.matcha.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Fg.ink),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap New to start a conversation.',
                          style: TextStyle(fontSize: 13, color: Fg.inkSoft),
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: _startNewConversation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: Bg.rust,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Start a conversation',
                              style: TextStyle(
                                color: Fg.almond,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
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

                      // Figure out the other participant
                      final participants =
                          List<String>.from(data['participants'] ?? []);
                      final otherUid = participants.firstWhere(
                          (id) => id != _uid,
                          orElse: () => '');
                      final unreadCount =
                          (data['unreadCounts'] as Map<String, dynamic>?)?[_uid] ??
                              0;

                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(otherUid)
                            .get(),
                        builder: (_, snap) {
                          final otherName = snap.data?.data() != null
                              ? (snap.data!.data()
                                      as Map<String, dynamic>)['name'] ??
                                  'Farmer'
                              : 'Farmer';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Bg.surface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                      conversationId: doc.id,
                                      currentUid: _uid,
                                      otherUid: otherUid,
                                      otherName: otherName,
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: Bg.matchaLight,
                                      child: Text(
                                        _initials(otherName),
                                        style: TextStyle(
                                          fontSize: 13,
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
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  otherName,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: unreadCount > 0
                                                        ? FontWeight.w600
                                                        : FontWeight.w500,
                                                    color: Fg.ink,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                _timeAgo(data['lastMessageAt']
                                                    as Timestamp?),
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  color: unreadCount > 0
                                                      ? Fg.rust
                                                      : Fg.inkSoft,
                                                  fontWeight: unreadCount > 0
                                                      ? FontWeight.w600
                                                      : FontWeight.w400,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  data['lastMessage'] ?? '',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    color: unreadCount > 0
                                                        ? Fg.ink
                                                        : Fg.inkSoft,
                                                    fontWeight: unreadCount > 0
                                                        ? FontWeight.w500
                                                        : FontWeight.w400,
                                                  ),
                                                ),
                                              ),
                                              if (unreadCount > 0)
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                      left: 8),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 7,
                                                          vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Bg.rust,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                  ),
                                                  child: Text(
                                                    '$unreadCount',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Fg.almond,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
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

class _NewConversationSheet extends StatefulWidget {
  final String currentUid;
  const _NewConversationSheet({required this.currentUid});

  @override
  State<_NewConversationSheet> createState() => _NewConversationSheetState();
}

class _NewConversationSheetState extends State<_NewConversationSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Future<void> _openOrCreateConversation(
      String otherUid, String otherName) async {
    // Check if conversation already exists
    final existing = await FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: widget.currentUid)
        .get();

    String? conversationId;
    for (final doc in existing.docs) {
      final participants =
          List<String>.from(doc.data()['participants'] ?? []);
      if (participants.contains(otherUid)) {
        conversationId = doc.id;
        break;
      }
    }

    if (conversationId == null) {
      final ref =
          await FirebaseFirestore.instance.collection('conversations').add({
        'participants': [widget.currentUid, otherUid],
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCounts': {widget.currentUid: 0, otherUid: 0},
      });
      conversationId = ref.id;
    }

    if (mounted) {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversationId!,
            currentUid: widget.currentUid,
            otherUid: otherUid,
            otherName: otherName,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: Bg.almond,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Bg.hairline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'New message',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Fg.ink,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close_rounded, color: Fg.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: Fg.ink, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search farmers...',
                hintStyle: TextStyle(color: Fg.inkSoft, fontSize: 14),
                prefixIcon: Icon(Icons.search, size: 20, color: Fg.inkSoft),
                filled: true,
                fillColor: Bg.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Bg.hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Bg.hairline),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 12),

          // User list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                final filtered = docs.where((doc) {
                  if (doc.id == widget.currentUid) return false;
                  final name = ((doc.data() as Map<String, dynamic>)['name'] ??
                          '')
                      .toString()
                      .toLowerCase();
                  return _query.isEmpty ||
                      name.contains(_query.toLowerCase());
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      _query.isNotEmpty
                          ? 'No farmers found'
                          : 'No other users yet',
                      style: TextStyle(fontSize: 14, color: Fg.inkSoft),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, i) {
                    final data =
                        filtered[i].data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'Farmer';
                    final uid = filtered[i].id;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Bg.matchaLight,
                        child: Text(
                          _initials(name),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Fg.matchaDark,
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Fg.ink,
                        ),
                      ),
                      subtitle: data['location'] != null
                          ? Text(
                              data['location'],
                              style: TextStyle(fontSize: 12, color: Fg.inkSoft),
                            )
                          : null,
                      onTap: () =>
                          _openOrCreateConversation(uid, name),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}