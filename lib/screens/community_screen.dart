import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import 'make_pal_screen.dart';

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
      final content =
          (data['content'] ?? '').toString().toLowerCase();
      final tag = (data['tag'] ?? '').toString();

      final matchesSearch = _searchQuery.isEmpty ||
          content.contains(_searchQuery.toLowerCase());
      final matchesTag =
          _filterTag.isEmpty || tag == _filterTag;

      return matchesSearch && matchesTag;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    const tags = ['FMD', 'Crops', 'Livestock', 'General'];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Header ──
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.greenDark,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 16,
                20,
                16,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Community',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Share knowledge with other farmers',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.greenHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _openMakePal,
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.group_add_rounded,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Make a Pal',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _showNewPost,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.greenMid,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Post',
                                style: TextStyle(
                                  color: Colors.white,
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
                  const SizedBox(height: 12),

                  // Search bar
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search posts...',
                      hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5), fontSize: 14),
                      prefixIcon: Icon(Icons.search,
                          color: Colors.white.withOpacity(0.6), size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
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
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                  const SizedBox(height: 10),

                  // Tag filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          selected: _filterTag.isEmpty,
                          onTap: () => setState(() => _filterTag = ''),
                        ),
                        ...tags.map((t) => _FilterChip(
                              label: t,
                              selected: _filterTag == t,
                              onTap: () => setState(
                                  () => _filterTag = _filterTag == t ? '' : t),
                            )),
                      ],
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
                return const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.greenDark),
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
                          size: 48,
                          color: AppColors.textSecondary.withOpacity(0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty || _filterTag.isNotEmpty
                              ? 'No posts match your search'
                              : 'No posts yet',
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _searchQuery.isNotEmpty || _filterTag.isNotEmpty
                              ? 'Try a different keyword or tag'
                              : 'Be the first to share something.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
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
                      padding: EdgeInsets.fromLTRB(16, i == 0 ? 16 : 0, 16, 12),
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

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? AppColors.greenDark : Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── Post card ─────────────────────────────────────────────────────────────────

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

  /// Writes a notification into the post author's notifications
  /// subcollection. No-ops if acting on your own post (no point
  /// notifying yourself), and swallows errors so a failed notification
  /// write never blocks the actual like action — the like itself has
  /// already succeeded by the time this is called.
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
    } catch (_) {
      // Best-effort — never let a notification failure surface to the
      // user over a like that already succeeded.
    }
  }

  Future<void> _toggleLike() async {
    final ref =
        FirebaseFirestore.instance.collection('posts').doc(widget.postId);
    if (_isLiked) {
      await ref.update({'likes': FieldValue.arrayRemove([widget.uid])});
    } else {
      await ref.update({'likes': FieldValue.arrayUnion([widget.uid])});
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
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Delete comments subcollection first
    final commentsSnap = await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in commentsSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(
        FirebaseFirestore.instance.collection('posts').doc(widget.postId));
    await batch.commit();

    // Decrement user post count
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .update({'postCount': FieldValue.increment(-1)});
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
    final parts = name
        .trim()
        .split(' ')
        .where((p) => p.isNotEmpty)
        .toList();
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

    Color tagColor;
    Color tagBg;
    switch (tag) {
      case 'FMD':
        tagColor = AppColors.red;
        tagBg = AppColors.redLight;
        break;
      case 'Crops':
        tagColor = AppColors.greenText;
        tagBg = AppColors.greenLight;
        break;
      default:
        tagColor = AppColors.amberText;
        tagBg = AppColors.amberLight;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author row
                Row(
                  children: [
                    FutureBuilder<String>(
                      future: widget.getName(authorUid),
                      builder: (_, snap) {
                        final name = snap.data ?? 'Farmer';
                        return Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.greenLight,
                              child: Text(
                                _initials(name),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.greenDeep,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${widget.data['location'] ?? ''} · ${_timeAgo(ts)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
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
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: tagBg,
                          borderRadius: BorderRadius.circular(AppRadius.chip),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: tagColor,
                          ),
                        ),
                      ),

                    // Overflow menu (edit/delete for owner)
                    if (_isOwner)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert,
                            size: 18, color: AppColors.textSecondary),
                        onSelected: (value) {
                          if (value == 'edit') _editPost(context);
                          if (value == 'delete') _deletePost(context);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
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
                                Icon(Icons.delete_outline,
                                    size: 16, color: AppColors.red),
                                SizedBox(width: 8),
                                Text('Delete post',
                                    style: TextStyle(color: AppColors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Content
                Text(
                  widget.data['content'] ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),

                // Edited label
                if (widget.data['edited'] == true)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'edited',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 10),

                // Like + Comment actions
                Row(
                  children: [
                    GestureDetector(
                      onTap: _toggleLike,
                      child: Row(
                        children: [
                          Icon(
                            _isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 18,
                            color: _isLiked
                                ? AppColors.red
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${likes.length}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _showComments = !_showComments),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$commentCount ${commentCount == 1 ? 'reply' : 'replies'}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Comments section
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

// ── Comments ──────────────────────────────────────────────────────────────────

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

  // When set, this comment is a reply to a specific existing comment
  // (so we can notify that commenter, distinct from the post author).
  String? _replyingToCommentId;
  String? _replyingToUid;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Mirrors _PostCard._notifyAuthor: best-effort, never blocks the
  /// underlying action, never notifies yourself.
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
    } catch (_) {
      // Best-effort only.
    }
  }

  Future<void> _submitComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);

    try {
      if (_editingCommentId != null) {
        // Edit existing comment. The comment may have been deleted out
        // from under the editor (e.g. from another device) — guard
        // against updating a doc that no longer exists.
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
        // New comment
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
        final postRef = FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId);
        batch.update(postRef, {'commentCount': FieldValue.increment(1)});
        await batch.commit();

        // Notify: if this is a reply to a specific comment, notify that
        // commenter as a 'reply'; otherwise notify the post author as a
        // 'comment'. Never both — avoids double-notifying the post
        // author when they're also the one being replied to.
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
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
        borderRadius:
            BorderRadius.vertical(bottom: Radius.circular(AppRadius.card)),
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

              // If the comment currently being edited has disappeared
              // (deleted elsewhere), drop out of edit mode so we don't
              // try to submit an update to a missing document. Only
              // check this once we have live data, so a transient
              // loading/reconnect state doesn't falsely look like a
              // deletion.
              if (snap.hasData &&
                  _editingCommentId != null &&
                  !docs.any((d) => d.id == _editingCommentId)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _cancelEdit();
                });
              }

              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    'No replies yet. Be the first!',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
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

          // Edit/reply mode banner
          if (_editingCommentId != null || _replyingToCommentId != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              color: AppColors.amberLight,
              child: Row(
                children: [
                  Icon(
                    _editingCommentId != null
                        ? Icons.edit
                        : Icons.reply_rounded,
                    size: 14,
                    color: AppColors.amberText,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _editingCommentId != null
                          ? 'Editing reply'
                          : 'Replying to comment',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.amberText),
                    ),
                  ),
                  GestureDetector(
                    onTap: _cancelEdit,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.amberText,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          // Comment input
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: _editingCommentId != null
                          ? 'Edit your reply...'
                          : 'Write a reply...',
                      hintStyle: const TextStyle(fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _submitting ? null : _submitComment,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.greenDark,
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: _submitting
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 18),
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

// ── Comment tile ──────────────────────────────────────────────────────────────

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
    return Container(
      color: (isEditing || isReplyTarget)
          ? AppColors.amberLight.withOpacity(0.3)
          : null,
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
                backgroundColor: AppColors.greenLight,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.greenDeep,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (data['edited'] == true)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Text(
                              'edited',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary),
                            ),
                          ),
                        const Spacer(),
                        GestureDetector(
                          onTap: onReply,
                          child: const Padding(
                            padding: EdgeInsets.only(left: 10),
                            child: Icon(Icons.reply_rounded,
                                size: 14, color: AppColors.textSecondary),
                          ),
                        ),
                        if (isOwner)
                          Row(
                            children: [
                              GestureDetector(
                                onTap: onEdit,
                                child: const Padding(
                                  padding: EdgeInsets.only(left: 10),
                                  child: Icon(Icons.edit_outlined,
                                      size: 14,
                                      color: AppColors.textSecondary),
                                ),
                              ),
                              GestureDetector(
                                onTap: onDelete,
                                child: const Padding(
                                  padding: EdgeInsets.only(left: 10),
                                  child: Icon(Icons.delete_outline,
                                      size: 14, color: AppColors.red),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data['content'] ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
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

// ── Post sheet (create + edit) ────────────────────────────────────────────────

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
    _controller =
        TextEditingController(text: widget.existingData?['content'] ?? '');
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
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.existingPostId)
            .update({
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
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .update({'postCount': FieldValue.increment(1)});
      }

      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  _isEdit ? 'Edit post' : 'New post',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close_rounded,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _controller,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'What\'s happening on your farm?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Tag selector
            Row(
              children: [
                const Text('Tag:',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(width: 10),
                ...['FMD', 'Crops', 'Livestock', 'General'].map((t) {
                  final selected = _tag == t;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _tag = selected ? '' : t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.greenDark
                              : AppColors.background2,
                          borderRadius:
                              BorderRadius.circular(AppRadius.chip),
                          border: Border.all(
                            color: selected
                                ? AppColors.greenDark
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          t,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: selected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: 'Your location (optional)',
                prefixIcon:
                    const Icon(Icons.location_on_outlined, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              onChanged: (v) => _location = v,
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isEdit ? 'Save changes' : 'Post'),
            ),
          ],
        ),
      ),
    );
  }
}