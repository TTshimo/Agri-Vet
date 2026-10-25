import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'make_pal_screen.dart';
import '../theme/palette.dart';

// Self-contained palette for the redesign — matcha green / almond / rust.
// Matches the palette used across the other redesigned screens. Fold into
// a shared AppColors in main.dart later if you want it app-wide.
/// FMD/Livestock read as urgent (rust), Crops/General/anything else reads
/// calm (matcha) — same two-tone accent logic used on every other screen.
bool _isUrgentTag(String tag) => tag == 'FMD' || tag == 'Livestock';

/// Alternates avatar color by uid so the feed doesn't look monotone,
/// without needing any real per-user color data.
({Color bg, Color fg}) _avatarColors(String uid) {
  final even = uid.isEmpty || uid.hashCode.isEven;
  return even
      ? (bg: Bg.matchaTint, fg: Fg.matchaDark)
      : (bg: Bg.rustBg, fg: Fg.rust);
}

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  final _nameCache = <String, String>{};
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterTag = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<String> _getDisplayName(String uid) async {
    if (_nameCache.containsKey(uid)) return _nameCache[uid]!;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final name = doc.data()?['name'] ?? 'Farmer';
    _nameCache[uid] = name;
    return name;
  }

  void _showNewPost() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PostSheet(uid: _uid),
    );
  }

  void _openMakePal() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MakePalScreen()),
    );
  }

  List<QueryDocumentSnapshot> _filtered(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final content = (data['content'] ?? '').toString().toLowerCase();
      final tag = (data['tag'] ?? '').toString();

      final matchesSearch =
          _searchQuery.isEmpty || content.contains(_searchQuery.toLowerCase());
      final matchesTag = _filterTag.isEmpty || tag == _filterTag;

      return matchesSearch && matchesTag;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    const tags = ['FMD', 'Crops', 'Livestock', 'General'];

    return Scaffold(
      backgroundColor: Bg.almond,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _BottomFieldWavePainter()),
          ),
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _WavyHeader(
                  height: MediaQuery.of(context).padding.top + 96,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      MediaQuery.of(context).padding.top + 20,
                      20,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Community',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Fg.almond,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Share knowledge with other farmers',
                          style: TextStyle(fontSize: 12, color: Fg.matchaTint),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _GlassCard(
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, color: Fg.inkSoft, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(color: Fg.ink, fontSize: 13),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'Search posts...',
                              hintStyle: TextStyle(color: Fg.inkSoft, fontSize: 13),
                            ),
                            onChanged: (v) => setState(() => _searchQuery = v),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: Icon(Icons.close_rounded, color: Fg.inkSoft, size: 16),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: _TagFilterChip(
                          label: 'All',
                          selected: _filterTag.isEmpty,
                          onTap: () => setState(() => _filterTag = ''),
                        ),
                      ),
                      ...tags.map(
                        (t) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: _TagFilterChip(
                              label: t,
                              selected: _filterTag == t,
                              onTap: () =>
                                  setState(() => _filterTag = _filterTag == t ? '' : t),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Feed ──
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .orderBy('createdAt', descending: true)
                    .limit(50)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(color: Fg.matcha),
                      ),
                    );
                  }

                  final allDocs = snapshot.data?.docs ?? [];
                  final docs = _filtered(allDocs);

                  if (docs.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty || _filterTag.isNotEmpty
                                  ? Icons.search_off_rounded
                                  : Icons.people_outline_rounded,
                              size: 44,
                              color: Fg.inkSoft.withOpacity(0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty || _filterTag.isNotEmpty
                                  ? 'No posts match your search'
                                  : 'No posts yet',
                              style: TextStyle(fontSize: 15, color: Fg.inkSoft),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _searchQuery.isNotEmpty || _filterTag.isNotEmpty
                                  ? 'Try a different keyword or tag'
                                  : 'Be the first to share something.',
                              style: TextStyle(fontSize: 13, color: Fg.inkSoft),
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
                        return Padding(
                          padding: EdgeInsets.fromLTRB(16, i == 0 ? 10 : 0, 16, 12),
                          child: _PostCard(
                            postId: doc.id,
                            data: data,
                            uid: _uid,
                            getName: _getDisplayName,
                          ),
                        );
                      },
                      childCount: docs.length,
                    ),
                  );
                },
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),

          // Stacked floating buttons, WhatsApp-style: smaller secondary
          // action above the larger primary one.
          Positioned(
            right: 18,
            bottom: 20,
            child: Column(
              children: [
                _CircleFab(
                  size: 44,
                  background: Bg.almond,
                  border: Bg.surface.withOpacity(0.9),
                  icon: Icons.group_add_rounded,
                  iconColor: Fg.matchaDark,
                  onTap: _openMakePal,
                ),
                const SizedBox(height: 12),
                _CircleFab(
                  size: 56,
                  background: Bg.rust,
                  icon: Icons.add_rounded,
                  iconColor: Fg.almond,
                  iconSize: 24,
                  onTap: _showNewPost,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Header with a soft wavy bottom edge instead of a hard rectangle, so it
/// blends into the field-wave background. Shared shape with the other
/// redesigned screens.
class _WavyHeader extends StatelessWidget {
  const _WavyHeader({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipPath(
            clipper: _WavyHeaderClipper(),
            child: Container(color: Bg.matchaHeader.withOpacity(0.88)),
          ),
          child,
        ],
      ),
    );
  }
}

class _WavyHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.774)
      ..cubicTo(w * 0.806, h * 0.955, w * 0.639, h * 0.697, w * 0.458, h * 0.839)
      ..cubicTo(w * 0.292, h * 0.968, w * 0.153, h * 0.903, 0, h * 0.968)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Single soft horizon wash at the bottom of the screen.
class _BottomFieldWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Bg.matchaTint.withOpacity(0.5);
    final path = Path()
      ..moveTo(0, size.height * 0.82)
      ..cubicTo(size.width * 0.17, size.height * 0.76, size.width * 0.36,
          size.height * 0.86, size.width * 0.56, size.height * 0.79)
      ..cubicTo(size.width * 0.72, size.height * 0.74, size.width * 0.86,
          size.height * 0.78, size.width, size.height * 0.76)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Frosted glass surface with a glossy highlight band across the top.
class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.borderColor,
    this.glossTint,
    this.padding = const EdgeInsets.all(13),
    this.borderRadius = 16,
  });

  final Widget child;
  final Color? borderColor;
  final Color? glossTint;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: Bg.surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? Bg.surface.withOpacity(0.85),
              width: 0.8,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: FractionallySizedBox(
                  heightFactor: 0.44,
                  child: Container(
                    decoration: BoxDecoration(
                      color: (glossTint ?? Bg.surface).withOpacity(0.4),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(borderRadius),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleFab extends StatelessWidget {
  final double size;
  final Color background;
  final Color? border;
  final IconData icon;
  final Color iconColor;
  final double iconSize;
  final VoidCallback onTap;

  const _CircleFab({
    required this.size,
    required this.background,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.border,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            border: border != null ? Border.all(color: border!, width: 0.8) : null,
          ),
          child: Icon(icon, color: iconColor, size: iconSize),
        ),
      ),
    );
  }
}

class _TagFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TagFilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Bg.matchaHeader : Bg.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(999),
          border: selected ? null : Border.all(color: Bg.surface.withOpacity(0.85)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: selected ? Fg.almond : Fg.ink,
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> data;
  final String uid;
  final Future<String> Function(String) getName;

  const _PostCard({
    required this.postId,
    required this.data,
    required this.uid,
    required this.getName,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _showComments = false;

  bool get _isLiked {
    final likes = List<String>.from(widget.data['likes'] ?? []);
    return likes.contains(widget.uid);
  }

  bool get _isOwner => widget.data['uid'] == widget.uid;

  Future<void> _notifyAuthor(String type) async {
    final authorUid = widget.data['uid'] ?? '';
    if (authorUid.isEmpty || authorUid == widget.uid) return;

    try {
      final myName = await widget.getName(widget.uid);
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(authorUid)
          .collection('items')
          .add({
        'type': type,
        'fromUid': widget.uid,
        'fromName': myName,
        'postId': widget.postId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    final ref = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
    if (_isLiked) {
      await ref.update({
        'likes': FieldValue.arrayRemove([widget.uid])
      });
    } else {
      await ref.update({
        'likes': FieldValue.arrayUnion([widget.uid])
      });
      await _notifyAuthor('like');
    }
  }

  Future<void> _deletePost(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete post?'),
        content:
            const Text('This will permanently remove your post and all replies.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Fg.rust),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final commentsSnap = await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in commentsSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(FirebaseFirestore.instance.collection('posts').doc(widget.postId));
    await batch.commit();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .set({'postCount': FieldValue.increment(-1)}, SetOptions(merge: true));
  }

  void _editPost(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PostSheet(
        uid: widget.uid,
        existingPostId: widget.postId,
        existingData: widget.data,
      ),
    );
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(dt);
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final likes = List<String>.from(widget.data['likes'] ?? []);
    final commentCount = widget.data['commentCount'] ?? 0;
    final tag = widget.data['tag'] ?? '';
    final ts = widget.data['createdAt'] as Timestamp?;
    final authorUid = widget.data['uid'] ?? '';
    final accent = _isUrgentTag(tag) ? Bg.rust : Bg.matcha;
    final avatar = _avatarColors(authorUid);

    return _GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FutureBuilder<String>(
                      future: widget.getName(authorUid),
                      builder: (_, snap) {
                        final name = snap.data ?? 'Farmer';
                        return Row(
                          children: [
                            CircleAvatar(
                              radius: 17,
                              backgroundColor: avatar.bg,
                              child: Text(
                                _initials(name),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: avatar.fg,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: Fg.ink,
                                  ),
                                ),
                                Text(
                                  '${widget.data['location'] ?? ''} · ${_timeAgo(ts)}',
                                  style: TextStyle(fontSize: 10.5, color: Fg.inkSoft),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    const Spacer(),
                    if (tag.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: accent,
                          ),
                        ),
                      ),
                    if (_isOwner)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, size: 18, color: Fg.inkSoft),
                        onSelected: (value) {
                          if (value == 'edit') _editPost(context);
                          if (value == 'delete') _deletePost(context);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 16),
                                SizedBox(width: 8),
                                Text('Edit post'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 16, color: Fg.rust),
                                const SizedBox(width: 8),
                                Text('Delete post', style: TextStyle(color: Fg.rust)),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  widget.data['content'] ?? '',
                  style: TextStyle(fontSize: 13.5, color: Fg.ink, height: 1.5),
                ),
                if (widget.data['edited'] == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('edited',
                        style: TextStyle(fontSize: 11, color: Fg.inkSoft)),
                  ),
                const SizedBox(height: 12),
                Divider(height: 1, color: Bg.surface.withOpacity(0.7)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _toggleLike,
                      child: Row(
                        children: [
                          Icon(
                            _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 17,
                            color: _isLiked ? Fg.rust : Fg.inkSoft,
                          ),
                          const SizedBox(width: 4),
                          Text('${likes.length}',
                              style: TextStyle(fontSize: 12.5, color: Fg.inkSoft)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => setState(() => _showComments = !_showComments),
                      child: Row(
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 17, color: Fg.inkSoft),
                          const SizedBox(width: 4),
                          Text(
                            '$commentCount ${commentCount == 1 ? 'reply' : 'replies'}',
                            style: TextStyle(fontSize: 12.5, color: Fg.inkSoft),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_showComments)
            _CommentsSection(
              postId: widget.postId,
              postAuthorUid: authorUid,
              uid: widget.uid,
              getName: widget.getName,
            ),
        ],
      ),
    );
  }
}

class _CommentsSection extends StatefulWidget {
  final String postId;
  final String postAuthorUid;
  final String uid;
  final Future<String> Function(String) getName;

  const _CommentsSection({
    required this.postId,
    required this.postAuthorUid,
    required this.uid,
    required this.getName,
  });

  @override
  State<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<_CommentsSection> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _editingCommentId;

  String? _replyingToCommentId;
  String? _replyingToUid;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _notify(String targetUid, String type) async {
    if (targetUid.isEmpty || targetUid == widget.uid) return;
    try {
      final myName = await widget.getName(widget.uid);
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(targetUid)
          .collection('items')
          .add({
        'type': type,
        'fromUid': widget.uid,
        'fromName': myName,
        'postId': widget.postId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> _submitComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);

    try {
      if (_editingCommentId != null) {
        final commentRef = FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .doc(_editingCommentId);
        final snap = await commentRef.get();
        if (snap.exists) {
          await commentRef.update({'content': text, 'edited': true});
        }
        setState(() => _editingCommentId = null);
      } else {
        final batch = FirebaseFirestore.instance.batch();
        final commentRef = FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .doc();
        batch.set(commentRef, {
          'uid': widget.uid,
          'content': text,
          'createdAt': FieldValue.serverTimestamp(),
        });
        final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
        batch.update(postRef, {'commentCount': FieldValue.increment(1)});
        await batch.commit();

        if (_replyingToCommentId != null && _replyingToUid != null) {
          await _notify(_replyingToUid!, 'reply');
        } else {
          await _notify(widget.postAuthorUid, 'comment');
        }

        setState(() {
          _replyingToCommentId = null;
          _replyingToUid = null;
        });
      }
      _controller.clear();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(commentId));
    batch.update(
      FirebaseFirestore.instance.collection('posts').doc(widget.postId),
      {'commentCount': FieldValue.increment(-1)},
    );
    await batch.commit();
  }

  void _startEdit(String commentId, String currentContent) {
    setState(() {
      _editingCommentId = commentId;
      _replyingToCommentId = null;
      _replyingToUid = null;
    });
    _controller.text = currentContent;
  }

  void _startReply(String commentId, String commenterUid) {
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToUid = commenterUid;
      _editingCommentId = null;
    });
    _controller.text = '';
  }

  void _cancelEdit() {
    setState(() {
      _editingCommentId = null;
      _replyingToCommentId = null;
      _replyingToUid = null;
    });
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        border: Border(top: BorderSide(color: Bg.surface.withOpacity(0.7))),
      ),
      child: Column(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .doc(widget.postId)
                .collection('comments')
                .orderBy('createdAt')
                .snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];

              if (snap.hasData &&
                  _editingCommentId != null &&
                  !docs.any((d) => d.id == _editingCommentId)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _cancelEdit();
                });
              }

              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text('No replies yet. Be the first!',
                      style: TextStyle(fontSize: 13, color: Fg.inkSoft)),
                );
              }
              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final isOwner = data['uid'] == widget.uid;
                  return _CommentTile(
                    commentId: doc.id,
                    data: data,
                    getName: widget.getName,
                    isOwner: isOwner,
                    isEditing: _editingCommentId == doc.id,
                    isReplyTarget: _replyingToCommentId == doc.id,
                    onEdit: () => _startEdit(doc.id, data['content'] ?? ''),
                    onDelete: () => _deleteComment(doc.id),
                    onReply: () => _startReply(doc.id, data['uid'] ?? ''),
                  );
                }).toList(),
              );
            },
          ),
          if (_editingCommentId != null || _replyingToCommentId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              color: Bg.rustBg.withOpacity(0.6),
              child: Row(
                children: [
                  Icon(
                    _editingCommentId != null ? Icons.edit : Icons.reply_rounded,
                    size: 14,
                    color: Fg.rust,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _editingCommentId != null ? 'Editing reply' : 'Replying to comment',
                      style: TextStyle(fontSize: 12, color: Fg.rust),
                    ),
                  ),
                  GestureDetector(
                    onTap: _cancelEdit,
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                          fontSize: 12, color: Fg.rust, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Bg.surface.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Bg.surface.withOpacity(0.85)),
                    ),
                    child: TextField(
                      controller: _controller,
                      style: TextStyle(fontSize: 13, color: Fg.ink),
                      decoration: InputDecoration(
                        hintText:
                            _editingCommentId != null ? 'Edit your reply...' : 'Write a reply...',
                        hintStyle: TextStyle(fontSize: 13, color: Fg.inkSoft),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _submitting ? null : _submitComment,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: Bg.rust, shape: BoxShape.circle),
                    child: _submitting
                        ? Padding(
                            padding: const EdgeInsets.all(10),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Fg.almond),
                          )
                        : Icon(Icons.send_rounded, color: Fg.almond, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final String commentId;
  final Map<String, dynamic> data;
  final Future<String> Function(String) getName;
  final bool isOwner;
  final bool isEditing;
  final bool isReplyTarget;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReply;

  const _CommentTile({
    required this.commentId,
    required this.data,
    required this.getName,
    required this.isOwner,
    required this.isEditing,
    required this.onEdit,
    required this.onDelete,
    required this.onReply,
    this.isReplyTarget = false,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = _avatarColors(data['uid'] ?? '');
    return Container(
      color: (isEditing || isReplyTarget) ? Bg.rustBg.withOpacity(0.4) : null,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: FutureBuilder<String>(
        future: getName(data['uid'] ?? ''),
        builder: (_, snap) {
          final name = snap.data ?? 'Farmer';
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: avatar.bg,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: avatar.fg),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(name,
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600, color: Fg.ink)),
                        if (data['edited'] == true)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text('edited',
                                style: TextStyle(fontSize: 10, color: Fg.inkSoft)),
                          ),
                        const Spacer(),
                        GestureDetector(
                          onTap: onReply,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Icon(Icons.reply_rounded, size: 14, color: Fg.inkSoft),
                          ),
                        ),
                        if (isOwner)
                          Row(
                            children: [
                              GestureDetector(
                                onTap: onEdit,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 10),
                                  child:
                                      Icon(Icons.edit_outlined, size: 14, color: Fg.inkSoft),
                                ),
                              ),
                              GestureDetector(
                                onTap: onDelete,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 10),
                                  child: Icon(Icons.delete_outline, size: 14, color: Fg.rust),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data['content'] ?? '',
                      style: TextStyle(fontSize: 13, color: Fg.ink, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// New/edit post — a glass sheet sliding up over the feed, closed with an
/// X rather than a back arrow since composing is a quick, interruptive
/// action rather than its own destination (unlike Make a Pal).
class _PostSheet extends StatefulWidget {
  final String uid;
  final String? existingPostId;
  final Map<String, dynamic>? existingData;

  const _PostSheet({
    required this.uid,
    this.existingPostId,
    this.existingData,
  });

  @override
  State<_PostSheet> createState() => _PostSheetState();
}

class _PostSheetState extends State<_PostSheet> {
  late final TextEditingController _controller;
  late final TextEditingController _locationController;
  late String _tag;
  late String _location;
  bool _submitting = false;

  bool get _isEdit => widget.existingPostId != null;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.existingData?['content'] ?? '');
    _tag = widget.existingData?['tag'] ?? '';
    _location = widget.existingData?['location'] ?? '';
    _locationController = TextEditingController(text: _location);
  }

  @override
  void dispose() {
    _controller.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);

    try {
      if (_isEdit) {
        await FirebaseFirestore.instance.collection('posts').doc(widget.existingPostId).update({
          'content': text,
          'tag': _tag,
          'location': _location,
          'edited': true,
          'editedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseFirestore.instance.collection('posts').add({
          'uid': widget.uid,
          'content': text,
          'tag': _tag,
          'location': _location,
          'likes': [],
          'commentCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
        // The post is saved; a failed counter bump must not keep the sheet open.
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.uid)
              .set({'postCount': FieldValue.increment(1)}, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Post count not updated: $e');
        }
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Post failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not post. Check your connection and try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const tags = ['FMD', 'Crops', 'Livestock', 'General'];

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: Bg.almond,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Bg.matcha.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              children: [
                Text(
                  _isEdit ? 'Edit post' : 'New post',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Fg.ink),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Bg.matcha.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.close_rounded, color: Fg.inkSoft, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _GlassCard(
              borderRadius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: TextField(
                controller: _controller,
                maxLines: 4,
                style: TextStyle(fontSize: 13.5, color: Fg.ink),
                decoration: InputDecoration(
                  hintText: "What's happening on your farm?",
                  hintStyle: TextStyle(fontSize: 13.5, color: Fg.inkSoft),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text('Tag:', style: TextStyle(fontSize: 13, color: Fg.inkSoft)),
                const SizedBox(width: 10),
                ...tags.map((t) {
                  final selected = _tag == t;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _tag = selected ? '' : t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected ? Bg.matchaHeader : Bg.surface.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color:
                                selected ? Bg.matchaHeader : Bg.surface.withOpacity(0.85),
                          ),
                        ),
                        child: Text(
                          t,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: selected ? Fg.almond : Fg.inkSoft,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 14),
            _GlassCard(
              borderRadius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 17, color: Fg.inkSoft),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _locationController,
                      style: TextStyle(fontSize: 13.5, color: Fg.ink),
                      decoration: InputDecoration(
                        hintText: 'Your location (optional)',
                        hintStyle: TextStyle(fontSize: 13.5, color: Fg.inkSoft),
                        border: InputBorder.none,
                      ),
                      onChanged: (v) => _location = v,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Bg.rust,
                  foregroundColor: Fg.almond,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _submitting
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Fg.almond),
                      )
                    : Text(
                        _isEdit ? 'Save changes' : 'Post',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}