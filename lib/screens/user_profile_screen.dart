import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import '../theme/palette.dart';
import '../theme/header_wave.dart';


enum _PalState {
  loading,
  none, // strangers
  requestSent, // I sent a pal request, awaiting them
  requestReceived, // they sent me a pal request, awaiting me
  pals,
  blockedByMe,
  blockedByThem,
}

class UserProfileScreen extends StatefulWidget {
  final String profileUid;

  final String? incomingRequestId;

  const UserProfileScreen({
    super.key,
    required this.profileUid,
    this.incomingRequestId,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  _PalState _palState = _PalState.loading;
  String? _outgoingRequestId; // palRequests doc id if I'm the sender
  String? _incomingRequestId; // palRequests doc id if they're the sender
  String? _myPalDocId; // pals doc id (mine) if already pals

  String? _pendingConversationId;
  bool _pendingConversationIsMine = false; // did I send the first message?

  bool _loadingRelationship = true;
  bool _actionInFlight = false;

  static String _palDocId(String owner, String other) => '${owner}_$other';

  @override
  void initState() {
    super.initState();
    _loadRelationship();
  }

  Future<void> _loadRelationship() async {
    final fs = FirebaseFirestore.instance;

    final meDoc = await fs.collection('users').doc(_currentUid).get();
    final themDoc = await fs.collection('users').doc(widget.profileUid).get();
    final myBlocked = List<String>.from(meDoc.data()?['blockedUids'] ?? []);
    final theirBlocked =
        List<String>.from(themDoc.data()?['blockedUids'] ?? []);

    if (myBlocked.contains(widget.profileUid)) {
      setState(() {
        _palState = _PalState.blockedByMe;
        _loadingRelationship = false;
      });
      return;
    }
    if (theirBlocked.contains(_currentUid)) {
      setState(() {
        _palState = _PalState.blockedByThem;
        _loadingRelationship = false;
      });
      return;
    }

    final palId = _palDocId(_currentUid, widget.profileUid);
    final palSnap = await fs.collection('pals').doc(palId).get();
    if (palSnap.exists) {
      setState(() {
        _palState = _PalState.pals;
        _myPalDocId = palId;
        _loadingRelationship = false;
      });
      return;
    }

    // Pending pal request either direction.
    if (widget.incomingRequestId != null) {
      setState(() {
        _palState = _PalState.requestReceived;
        _incomingRequestId = widget.incomingRequestId;
        _loadingRelationship = false;
      });
      return;
    }

    final sentQuery = await fs
        .collection('palRequests')
        .where('fromUid', isEqualTo: _currentUid)
        .where('toUid', isEqualTo: widget.profileUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (sentQuery.docs.isNotEmpty) {
      setState(() {
        _palState = _PalState.requestSent;
        _outgoingRequestId = sentQuery.docs.first.id;
        _loadingRelationship = false;
      });
      return;
    }

    final receivedQuery = await fs
        .collection('palRequests')
        .where('fromUid', isEqualTo: widget.profileUid)
        .where('toUid', isEqualTo: _currentUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (receivedQuery.docs.isNotEmpty) {
      setState(() {
        _palState = _PalState.requestReceived;
        _incomingRequestId = receivedQuery.docs.first.id;
        _loadingRelationship = false;
      });
      return;
    }

    setState(() {
      _palState = _PalState.none;
      _loadingRelationship = false;
    });

    await _loadPendingConversation();
  }

  Future<void> _loadPendingConversation() async {
    final fs = FirebaseFirestore.instance;
    final existing = await fs
        .collection('conversations')
        .where('participants', arrayContains: _currentUid)
        .where('status', isEqualTo: 'pending')
        .get();

    for (final doc in existing.docs) {
      final participants = List<String>.from(doc.data()['participants'] ?? []);
      if (participants.contains(widget.profileUid)) {
        if (!mounted) return;
        setState(() {
          _pendingConversationId = doc.id;
          _pendingConversationIsMine =
              (doc.data()['requestedBy'] ?? '') == _currentUid;
        });
        return;
      }
    }
  }

  Future<void> _sendPalRequest() async {
    setState(() => _actionInFlight = true);
    try {
      final ref = await FirebaseFirestore.instance.collection('palRequests').add({
        'fromUid': _currentUid,
        'toUid': widget.profileUid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _notify('pal_request', requestId: ref.id);
      if (!mounted) return;
      setState(() {
        _palState = _PalState.requestSent;
        _outgoingRequestId = ref.id;
      });
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  Future<void> _cancelPalRequest() async {
    if (_outgoingRequestId == null) return;
    setState(() => _actionInFlight = true);
    try {
      await FirebaseFirestore.instance
          .collection('palRequests')
          .doc(_outgoingRequestId)
          .delete();
      if (!mounted) return;
      setState(() {
        _palState = _PalState.none;
        _outgoingRequestId = null;
      });
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  Future<void> _acceptPalRequest() async {
    if (_incomingRequestId == null) return;
    setState(() => _actionInFlight = true);
    try {
      final fs = FirebaseFirestore.instance;
      final myPalId = _palDocId(_currentUid, widget.profileUid);
      final theirPalId = _palDocId(widget.profileUid, _currentUid);
      final batch = fs.batch();
      batch.set(fs.collection('pals').doc(myPalId), {
        'uid': _currentUid,
        'otherUid': widget.profileUid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(fs.collection('pals').doc(theirPalId), {
        'uid': widget.profileUid,
        'otherUid': _currentUid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(
        fs.collection('palRequests').doc(_incomingRequestId),
        {'status': 'accepted'},
      );
      await batch.commit();
      await fs.collection('palRequests').doc(_incomingRequestId).delete();
      await _notify('pal_accept');
      if (!mounted) return;
      setState(() {
        _palState = _PalState.pals;
        _myPalDocId = myPalId;
        _incomingRequestId = null;
      });
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  Future<void> _deletePalRequest() async {
    if (_incomingRequestId == null) return;
    setState(() => _actionInFlight = true);
    try {
      await FirebaseFirestore.instance
          .collection('palRequests')
          .doc(_incomingRequestId)
          .delete();
      if (!mounted) return;
      setState(() {
        _palState = _PalState.none;
        _incomingRequestId = null;
      });
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  Future<void> _block() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Block this pal?'),
        content: const Text(
            'You\'ll no longer be able to message each other or see each '
            'other\'s posts and comments. They won\'t be notified.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Fg.danger),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _actionInFlight = true);
    try {
      final fs = FirebaseFirestore.instance;
      final batch = fs.batch();
      batch.update(fs.collection('users').doc(_currentUid), {
        'blockedUids': FieldValue.arrayUnion([widget.profileUid]),
      });
      if (_myPalDocId != null) {
        batch.delete(fs.collection('pals').doc(_myPalDocId));
        batch.delete(
            fs.collection('pals').doc(_palDocId(widget.profileUid, _currentUid)));
      }
      await batch.commit();
      if (!mounted) return;
      setState(() => _palState = _PalState.blockedByMe);
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  Future<void> _unblock() async {
    setState(() => _actionInFlight = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .update({
        'blockedUids': FieldValue.arrayRemove([widget.profileUid]),
      });
      if (!mounted) return;
      setState(() => _palState = _PalState.none);
      await _loadRelationship();
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  Future<void> _sendMessageRequest() async {
    setState(() => _actionInFlight = true);
    try {
      final fs = FirebaseFirestore.instance;
      final convRef = fs.collection('conversations').doc();
      await convRef.set({
        'participants': [_currentUid, widget.profileUid],
        'status': 'pending',
        'requestedBy': _currentUid,
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCounts': {_currentUid: 0, widget.profileUid: 0},
        'archivedBy': <String>[],
      });
      await _notify('msg_request', conversationId: convRef.id);
      if (!mounted) return;
      setState(() {
        _pendingConversationId = convRef.id;
        _pendingConversationIsMine = true;
      });
      _openConversation(convRef.id);
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  Future<void> _unsendMessageRequest() async {
    if (_pendingConversationId == null) return;
    setState(() => _actionInFlight = true);
    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(_pendingConversationId)
          .delete();
      if (!mounted) return;
      setState(() {
        _pendingConversationId = null;
        _pendingConversationIsMine = false;
      });
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  Future<void> _notify(String type,
      {String? requestId, String? conversationId, String? postId}) async {
    final meDoc =
        await FirebaseFirestore.instance.collection('users').doc(_currentUid).get();
    final myName = meDoc.data()?['name'] ?? 'Farmer';
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(widget.profileUid)
        .collection('items')
        .add({
      'type': type,
      'fromUid': _currentUid,
      'fromName': myName,
      if (requestId != null) 'requestId': requestId,
      if (conversationId != null) 'conversationId': conversationId,
      if (postId != null) 'postId': postId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void _openConversation(String conversationId) async {
    final themDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.profileUid)
        .get();
    final otherName = themDoc.data()?['name'] ?? 'Farmer';
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversationId,
          currentUid: _currentUid,
          otherUid: widget.profileUid,
          otherName: otherName,
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts =
        name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Bg.almond,
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.profileUid)
            .get(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return Center(
              child: CircularProgressIndicator(color: Fg.matcha),
            );
          }
          final data = snap.data!.data() as Map<String, dynamic>? ?? {};
          final name = data['name'] ?? 'Farmer';
          final bio = data['bio'] ?? '';
          final location = data['location'] ?? '';
          final postCount = data['postCount'] ?? 0;

          return CustomScrollView(
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
                              icon: Icon(Icons.arrow_back_ios_new_rounded,
                                  color: Fg.almond, size: 18),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Spacer(),
                          ],
                        ),
                        const SizedBox(height: 4),
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Bg.matcha,
                          child: Text(
                            _initials(name),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Fg.almond,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            color: Fg.almond,
                          ),
                        ),
                        if (location.toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 14, color: Fg.matchaLight),
                              const SizedBox(width: 4),
                              Text(
                                location,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Fg.matchaLight,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (bio.toString().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              bio,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Fg.almond.withOpacity(0.85),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '$postCount ${postCount == 1 ? 'post' : 'posts'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Fg.matchaLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _buildActionArea(),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    'Posts',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Fg.ink,
                    ),
                  ),
                ),
              ),

              _buildPostsList(),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionArea() {
    if (_loadingRelationship) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Fg.matcha),
          ),
        ),
      );
    }

    switch (_palState) {
      case _PalState.blockedByMe:
        return Column(
          children: [
            const _InfoBanner(
                icon: Icons.block_rounded,
                text: 'You\'ve blocked this farmer.'),
            const SizedBox(height: 10),
            _ActionButton(
              label: 'Unblock',
              filled: false,
              loading: _actionInFlight,
              onTap: _unblock,
            ),
          ],
        );

      case _PalState.blockedByThem:
        return const _InfoBanner(
          icon: Icons.info_outline_rounded,
          text: 'This profile isn\'t available.',
        );

      case _PalState.pals:
        return Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'Message',
                filled: true,
                loading: false,
                onTap: () => _openOrCreateAcceptedConversation(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                label: 'Block',
                filled: false,
                danger: true,
                loading: _actionInFlight,
                onTap: _block,
              ),
            ),
          ],
        );

      case _PalState.requestSent:
        return _ActionButton(
          label: 'Cancel pal request',
          filled: false,
          loading: _actionInFlight,
          onTap: _cancelPalRequest,
        );

      case _PalState.requestReceived:
        return Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'Accept',
                filled: true,
                loading: _actionInFlight,
                onTap: _acceptPalRequest,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                label: 'Delete request',
                filled: false,
                loading: _actionInFlight,
                onTap: _deletePalRequest,
              ),
            ),
          ],
        );

      case _PalState.none:
        if (_pendingConversationId != null) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'Add pal',
                      filled: true,
                      loading: _actionInFlight,
                      onTap: _sendPalRequest,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _InfoBanner(
                icon: Icons.schedule_rounded,
                text: _pendingConversationIsMine
                    ? 'Message request sent, waiting for a reply.'
                    : 'This farmer sent you a message request.',
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: _pendingConversationIsMine
                          ? 'Open request'
                          : 'View message',
                      filled: false,
                      loading: false,
                      onTap: () => _openConversation(_pendingConversationId!),
                    ),
                  ),
                  if (_pendingConversationIsMine) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        label: 'Unsend',
                        filled: false,
                        danger: true,
                        loading: _actionInFlight,
                        onTap: _unsendMessageRequest,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'Add pal',
                filled: true,
                loading: _actionInFlight,
                onTap: _sendPalRequest,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                label: 'Message',
                filled: false,
                loading: _actionInFlight,
                onTap: _sendMessageRequest,
              ),
            ),
          ],
        );

      case _PalState.loading:
        return const SizedBox.shrink();
    }
  }

  Future<void> _openOrCreateAcceptedConversation() async {
    final fs = FirebaseFirestore.instance;
    final existing = await fs
        .collection('conversations')
        .where('participants', arrayContains: _currentUid)
        .get();

    String? conversationId;
    for (final doc in existing.docs) {
      final participants = List<String>.from(doc.data()['participants'] ?? []);
      if (participants.contains(widget.profileUid)) {
        conversationId = doc.id;
        break;
      }
    }

    if (conversationId == null) {
      final ref = await fs.collection('conversations').add({
        'participants': [_currentUid, widget.profileUid],
        'status': 'accepted',
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCounts': {_currentUid: 0, widget.profileUid: 0},
        'archivedBy': <String>[],
      });
      conversationId = ref.id;
    }

    _openConversation(conversationId);
  }

  Widget _buildPostsList() {
    if (_palState == _PalState.blockedByThem) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('uid', isEqualTo: widget.profileUid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No posts yet',
                  style: TextStyle(fontSize: 13, color: Fg.inkSoft),
                ),
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Bg.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    data['content'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Fg.ink,
                      height: 1.4,
                    ),
                  ),
                ),
              );
            },
            childCount: docs.length,
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool filled;
  final bool loading;
  final bool danger;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.filled,
    required this.loading,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? Bg.danger : Bg.rust;
    return SizedBox(
      height: 42,
      child: filled
          ? ElevatedButton(
              onPressed: loading ? null : onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Fg.almond,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(label),
            )
          : OutlinedButton(
              onPressed: loading ? null : onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: loading
                  ? SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: color),
                    )
                  : Text(label),
            ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoBanner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Bg.rustBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Fg.rust),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Fg.rust),
            ),
          ),
        ],
      ),
    );
  }
}