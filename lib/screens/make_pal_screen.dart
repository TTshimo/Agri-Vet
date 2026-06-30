import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import 'user_profile_screen.dart';

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
                          'Make a Pal',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40), // balance the back button
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Find other farmers to connect with',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.greenHint,
                        ),
                      ),
                    ),
                  ),
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search farmers...',
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
                    return const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.greenDark),
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
                            Icon(
                              Icons.people_outline_rounded,
                              size: 48,
                              color: AppColors.textSecondary.withOpacity(0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _query.isNotEmpty
                                  ? 'No farmers found'
                                  : 'No other farmers yet',
                              style: const TextStyle(
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
    return Column(
      children: [
        InkWell(
          onTap: _openProfile,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.greenLight,
                  child: Text(
                    widget.initials,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (widget.location.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            widget.location,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
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
        const Divider(height: 1, color: AppColors.border, indent: 64),
      ],
    );
  }

  Widget _buildButtons() {
    if (_state == _RowState.loading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
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
          color: filled ? AppColors.greenDark : AppColors.background2,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: filled
              ? null
              : Border.all(color: AppColors.border),
        ),
        child: loading
            ? SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: filled ? Colors.white : AppColors.textSecondary,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: filled ? Colors.white : AppColors.textSecondary,
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
          color: AppColors.greenLight,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppColors.greenDeep),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.greenDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}