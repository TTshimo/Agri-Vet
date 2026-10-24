import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_profile_screen.dart';
import '../theme/palette.dart';

/// Bottom wave finishing off the dark matcha header band — same shape
/// used across the other restyled screens for a consistent silhouette.
class _HeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height * 0.68)
      ..cubicTo(
        size.width * 0.32, size.height,
        size.width * 0.66, size.height * 0.44,
        size.width, size.height * 0.72,
      )
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

enum _RowState {
  loading,
  none,
  requestSent,
  requestReceived,
  pals,
}

class MakePalScreen extends StatefulWidget {
  const MakePalScreen({super.key});

  @override
  State<MakePalScreen> createState() => _MakePalScreenState();
}

class _MakePalScreenState extends State<MakePalScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Bg.almond,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: ClipPath(
              clipper: _HeaderWaveClipper(),
              child: Container(
                color: Bg.matchaDark,
                padding: EdgeInsets.fromLTRB(
                  16,
                  MediaQuery.of(context).padding.top + 8,
                  16,
                  36,
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
                            'Make a pal',
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
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Find other farmers to connect with',
                        style: TextStyle(fontSize: 12.5, color: Fg.matchaLight),
                      ),
                    ),
                    TextField(
                      controller: _searchController,
                      style: TextStyle(color: Fg.almond, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search farmers...',
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
                        fillColor: Bg.surface.withOpacity(0.12),
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

          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_uid)
                .snapshots(),
            builder: (context, meSnap) {
              final myBlocked = List<String>.from(
                  (meSnap.data?.data() as Map<String, dynamic>?)?['blockedUids'] ??
                      []);

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .orderBy('name')
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
                  final filtered = docs.where((doc) {
                    if (doc.id == _uid) return false;
                    if (myBlocked.contains(doc.id)) return false;
                    final data = doc.data() as Map<String, dynamic>;
                    final theirBlocked =
                        List<String>.from(data['blockedUids'] ?? []);
                    if (theirBlocked.contains(_uid)) return false;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    return _query.isEmpty || name.contains(_query.toLowerCase());
                  }).toList();

                  if (filtered.isEmpty) {
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
                                Icons.people_outline_rounded,
                                size: 26,
                                color: Fg.matcha.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _query.isNotEmpty
                                  ? 'No farmers found'
                                  : 'No other farmers yet',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Fg.ink),
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
                          final doc = filtered[i];
                          final data = doc.data() as Map<String, dynamic>;
                          return _PalRow(
                            uid: doc.id,
                            currentUid: _uid,
                            name: data['name'] ?? 'Farmer',
                            location: data['location'] ?? '',
                            initials: _initials(data['name'] ?? 'Farmer'),
                          );
                        },
                        childCount: filtered.length,
                      ),
                    ),
                  );
                },
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _PalRow extends StatefulWidget {
  final String uid;
  final String currentUid;
  final String name;
  final String location;
  final String initials;

  const _PalRow({
    required this.uid,
    required this.currentUid,
    required this.name,
    required this.location,
    required this.initials,
  });

  @override
  State<_PalRow> createState() => _PalRowState();
}

class _PalRowState extends State<_PalRow> {
  _RowState _state = _RowState.loading;
  String? _outgoingRequestId;
  String? _incomingRequestId;
  bool _actionInFlight = false;

  static String _palDocId(String owner, String other) => '${owner}_$other';

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final fs = FirebaseFirestore.instance;

    final palId = _palDocId(widget.currentUid, widget.uid);
    final palSnap = await fs.collection('pals').doc(palId).get();
    if (palSnap.exists) {
      if (mounted) setState(() => _state = _RowState.pals);
      return;
    }

    final sentQuery = await fs
        .collection('palRequests')
        .where('fromUid', isEqualTo: widget.currentUid)
        .where('toUid', isEqualTo: widget.uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (sentQuery.docs.isNotEmpty) {
      if (mounted) {
        setState(() {
          _state = _RowState.requestSent;
          _outgoingRequestId = sentQuery.docs.first.id;
        });
      }
      return;
    }

    final receivedQuery = await fs
        .collection('palRequests')
        .where('fromUid', isEqualTo: widget.uid)
        .where('toUid', isEqualTo: widget.currentUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (receivedQuery.docs.isNotEmpty) {
      if (mounted) {
        setState(() {
          _state = _RowState.requestReceived;
          _incomingRequestId = receivedQuery.docs.first.id;
        });
      }
      return;
    }

    if (mounted) setState(() => _state = _RowState.none);
  }

  Future<void> _notify(String type, {String? requestId}) async {
    final meDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUid)
        .get();
    final myName = meDoc.data()?['name'] ?? 'Farmer';
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(widget.uid)
        .collection('items')
        .add({
      'type': type,
      'fromUid': widget.currentUid,
      'fromName': myName,
      if (requestId != null) 'requestId': requestId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _sendPalRequest() async {
    setState(() => _actionInFlight = true);
    try {
      final ref =
          await FirebaseFirestore.instance.collection('palRequests').add({
        'fromUid': widget.currentUid,
        'toUid': widget.uid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _notify('pal_request', requestId: ref.id);
      if (!mounted) return;
      setState(() {
        _state = _RowState.requestSent;
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
        _state = _RowState.none;
        _outgoingRequestId = null;
      });
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  Future<void> _sendMessageRequest() async {
    setState(() => _actionInFlight = true);
    try {
      final fs = FirebaseFirestore.instance;

      final existing = await fs
          .collection('conversations')
          .where('participants', arrayContains: widget.currentUid)
          .get();
      String? conversationId;
      for (final doc in existing.docs) {
        final participants =
            List<String>.from(doc.data()['participants'] ?? []);
        if (participants.contains(widget.uid)) {
          conversationId = doc.id;
          break;
        }
      }

      if (conversationId == null) {
        final ref = await fs.collection('conversations').add({
          'participants': [widget.currentUid, widget.uid],
          'status': 'pending',
          'requestedBy': widget.currentUid,
          'lastMessage': '',
          'lastMessageAt': FieldValue.serverTimestamp(),
          'unreadCounts': {widget.currentUid: 0, widget.uid: 0},
          'archivedBy': <String>[],
        });
        conversationId = ref.id;
        await _notify('msg_request');
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(profileUid: widget.uid),
        ),
      );
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          profileUid: widget.uid,
          incomingRequestId: _incomingRequestId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Bg.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _openProfile,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Bg.matchaLight,
                child: Text(
                  widget.initials,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: Fg.ink,
                      ),
                    ),
                    if (widget.location.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          widget.location,
                          style: TextStyle(fontSize: 11.5, color: Fg.inkSoft),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButtons() {
    if (_state == _RowState.loading) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: Fg.matcha),
      );
    }

    if (_state == _RowState.pals) {
      return const _SmallTag(label: 'Pals', icon: Icons.check_circle_rounded);
    }

    if (_state == _RowState.requestReceived) {
      return _SmallTag(
        label: 'Wants to be pals',
        icon: Icons.schedule_rounded,
        onTap: _openProfile,
      );
    }

    if (_state == _RowState.requestSent) {
      return _SmallButton(
        label: 'Cancel',
        loading: _actionInFlight,
        onTap: _cancelPalRequest,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SmallButton(
          label: 'Add',
          filled: true,
          loading: _actionInFlight,
          onTap: _sendPalRequest,
        ),
        const SizedBox(width: 6),
        _SmallButton(
          label: 'Message',
          loading: _actionInFlight,
          onTap: _sendMessageRequest,
        ),
      ],
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final bool filled;
  final bool loading;
  final VoidCallback onTap;

  const _SmallButton({
    required this.label,
    required this.loading,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: filled ? Bg.rust : Bg.almond,
          borderRadius: BorderRadius.circular(999),
          border: filled ? null : Border.all(color: Bg.hairline),
        ),
        child: loading
            ? SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: filled ? Fg.almond : Fg.inkSoft,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: filled ? Fg.almond : Fg.inkSoft,
                ),
              ),
      ),
    );
  }
}

class _SmallTag extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _SmallTag({required this.label, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Bg.matchaLight,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Fg.matchaDark),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Fg.matchaDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}