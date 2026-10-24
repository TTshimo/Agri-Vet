import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../theme/palette.dart';

/// Bottom wave finishing off the dark matcha header band — same shape
/// used across the other restyled screens for a consistent silhouette.
class _HeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height * 0.7)
      ..cubicTo(
        size.width * 0.32, size.height,
        size.width * 0.66, size.height * 0.5,
        size.width, size.height * 0.76,
      )
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String currentUid;
  final String otherUid;
  final String otherName;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.currentUid,
    required this.otherUid,
    required this.otherName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _submitting = false;
  String? _editingMessageId;
  String? _replyToId;
  String? _replyToText;
  String? _replyToSender;

  String? _lastSeenDocId;
  bool _editingIsLastMsg = false;

  bool _decidingRequest = false;

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .update({'unreadCounts.${widget.currentUid}': 0});
    // Clear this chat's entry in the notification bell, if there is one.
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(widget.currentUid)
          .collection('items')
          .doc('msg_${widget.conversationId}')
          .update({'read': true});
    } catch (_) {
      // No unread message notification for this chat.
    }
  }

  /// One notification per conversation (doc id msg_<conversationId>),
  /// overwritten by each new message so the bell shows the latest one
  /// instead of filling up. Also triggers the push notification.
  Future<void> _notifyRecipient(String text) async {
    try {
      final fs = FirebaseFirestore.instance;
      final meDoc = await fs.collection('users').doc(widget.currentUid).get();
      await fs
          .collection('notifications')
          .doc(widget.otherUid)
          .collection('items')
          .doc('msg_${widget.conversationId}')
          .set({
        'type': 'message',
        'fromUid': widget.currentUid,
        'fromName': meDoc.data()?['name'] ?? 'Farmer',
        'conversationId': widget.conversationId,
        'preview': text.length > 120 ? '${text.substring(0, 117)}...' : text,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Message notification not sent: $e');
    }
  }

  Future<void> _acceptRequest() async {
    setState(() => _decidingRequest = true);
    try {
      final fs = FirebaseFirestore.instance;
      await fs.collection('conversations').doc(widget.conversationId).update({
        'status': 'accepted',
      });

      final meDoc =
          await fs.collection('users').doc(widget.currentUid).get();
      final myName = meDoc.data()?['name'] ?? 'Farmer';
      await fs
          .collection('notifications')
          .doc(widget.otherUid)
          .collection('items')
          .add({
        'type': 'msg_accept',
        'fromUid': widget.currentUid,
        'fromName': myName,
        'conversationId': widget.conversationId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } finally {
      if (mounted) setState(() => _decidingRequest = false);
    }
  }

  Future<void> _declineRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Decline message request?'),
        content: Text(
            'This will delete the conversation. ${widget.otherName} won\'t '
            'be notified.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Fg.danger),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _decidingRequest = true);
    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .delete();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _decidingRequest = false);
    }
  }

  Future<void> _sendMessage(
      {bool editingIsLastMsg = false, bool inputLocked = false}) async {
    if (inputLocked) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);

    try {
      if (_editingMessageId != null) {
        await FirebaseFirestore.instance
            .collection('conversations')
            .doc(widget.conversationId)
            .collection('messages')
            .doc(_editingMessageId)
            .update({'text': text, 'edited': true});

        if (editingIsLastMsg) {
          await FirebaseFirestore.instance
              .collection('conversations')
              .doc(widget.conversationId)
              .update({'lastMessage': text});
        }

        setState(() {
          _editingMessageId = null;
          _editingIsLastMsg = false;
          _replyToId = null;
          _replyToText = null;
          _replyToSender = null;
        });
      } else {
        final batch = FirebaseFirestore.instance.batch();

        final msgRef = FirebaseFirestore.instance
            .collection('conversations')
            .doc(widget.conversationId)
            .collection('messages')
            .doc();

        final msgData = <String, dynamic>{
          'senderUid': widget.currentUid,
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
        };

        if (_replyToId != null) {
          msgData['replyToId'] = _replyToId;
          msgData['replyToText'] = _replyToText;
          msgData['replyToSender'] = _replyToSender;
        }

        batch.set(msgRef, msgData);

        batch.update(
          FirebaseFirestore.instance
              .collection('conversations')
              .doc(widget.conversationId),
          {
            'lastMessage': text,
            'lastMessageAt': FieldValue.serverTimestamp(),
            'unreadCounts.${widget.otherUid}': FieldValue.increment(1),
          },
        );

        await batch.commit();
        _notifyRecipient(text);

        setState(() {
          _replyToId = null;
          _replyToText = null;
          _replyToSender = null;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }

      _controller.clear();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _deleteMessage(String messageId, bool isLast) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This will remove the message for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Fg.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .doc(messageId)
        .update({'deleted': true, 'text': ''});

    if (isLast) {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update({'lastMessage': 'Message deleted'});
    }
  }

  void _startEdit(String messageId, String currentText, bool isLastMsg) {
    setState(() {
      _editingMessageId = messageId;
      _editingIsLastMsg = isLastMsg;
      _replyToId = null;
      _replyToText = null;
      _replyToSender = null;
    });
    _controller.text = currentText;
  }

  void _startReply(String messageId, String text, String sender) {
    setState(() {
      _replyToId = messageId;
      _replyToText = text;
      _replyToSender = sender;
      _editingMessageId = null;
    });
    _controller.text = '';
  }

  void _cancelAction() {
    setState(() {
      _editingMessageId = null;
      _editingIsLastMsg = false;
      _replyToId = null;
      _replyToText = null;
      _replyToSender = null;
    });
    _controller.clear();
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    return DateFormat('h:mm a').format(ts.toDate());
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    if (dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day) {
      return 'Today';
    }
    if (dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day - 1) {
      return 'Yesterday';
    }
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
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .snapshots(),
      builder: (context, convSnap) {
        final convData = convSnap.data?.data() as Map<String, dynamic>?;
        final status = convData?['status'] as String?;
        final requestedBy = convData?['requestedBy'] as String?;

        if (convSnap.hasData && !convSnap.data!.exists) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
          return Scaffold(
            backgroundColor: Bg.almond,
            body: SizedBox.shrink(),
          );
        }

        final isPending = status == 'pending';
        final iAmRequester = requestedBy == widget.currentUid;
        final inputLocked = isPending && !iAmRequester;

        return Scaffold(
          backgroundColor: Bg.almond,
          body: Column(
            children: [
              // Header
              ClipPath(
                clipper: _HeaderWaveClipper(),
                child: Container(
                  color: Bg.matchaDark,
                  padding: EdgeInsets.fromLTRB(
                    0,
                    MediaQuery.of(context).padding.top + 8,
                    16,
                    28,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                            color: Fg.almond, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Bg.matcha,
                        child: Text(
                          _initials(widget.otherName),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Fg.almond,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.otherName,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                                color: Fg.almond,
                              ),
                            ),
                            Text(
                              isPending ? 'Message request' : 'Farmer',
                              style: TextStyle(
                                  fontSize: 11.5, color: Fg.matchaLight),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (isPending)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Bg.rustBg,
                  child: iAmRequester
                      ? Row(
                          children: [
                            Icon(Icons.schedule_rounded,
                                size: 16, color: Fg.rust),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Message request sent — waiting for '
                                '${widget.otherName} to accept.',
                                style: TextStyle(
                                    fontSize: 12.5, color: Fg.rust),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.mark_email_unread_rounded,
                                    size: 16, color: Fg.rust),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${widget.otherName} wants to message you.',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: Fg.rust),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 36,
                                    child: ElevatedButton(
                                      onPressed: _decidingRequest
                                          ? null
                                          : _acceptRequest,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Bg.rust,
                                        foregroundColor: Fg.almond,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: _decidingRequest
                                          ? const SizedBox(
                                              height: 16,
                                              width: 16,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text('Accept',
                                              style: TextStyle(fontSize: 13)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: SizedBox(
                                    height: 36,
                                    child: OutlinedButton(
                                      onPressed: _decidingRequest
                                          ? null
                                          : _declineRequest,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Fg.danger,
                                        side: BorderSide(color: Bg.danger),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text('Decline',
                                          style: TextStyle(fontSize: 13)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('conversations')
                      .doc(widget.conversationId)
                      .collection('messages')
                      .orderBy('createdAt')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(color: Fg.matcha),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: Bg.matchaLight,
                              child: Text(
                                _initials(widget.otherName),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Fg.matchaDark,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.otherName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Fg.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isPending && iAmRequester
                                  ? 'Say hello to start the conversation.'
                                  : 'Send a message to start the conversation.',
                              style: TextStyle(
                                  fontSize: 13, color: Fg.inkSoft),
                            ),
                          ],
                        ),
                      );
                    }

                    final latestDocId = docs.last.id;
                    if (latestDocId != _lastSeenDocId) {
                      _lastSeenDocId = latestDocId;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _markAsRead();
                      });
                    }

                    String? lastDate;

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final doc = docs[i];
                        final data = doc.data() as Map<String, dynamic>;
                        final isMe = data['senderUid'] == widget.currentUid;
                        final ts = data['createdAt'] as Timestamp?;
                        final dateLabel = _formatDate(ts);
                        final showDate = dateLabel != lastDate;
                        lastDate = dateLabel;
                        final isLastMsg = i == docs.length - 1;

                        return Column(
                          children: [
                            if (showDate)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Bg.matchaLight.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    dateLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Fg.matchaDark,
                                    ),
                                  ),
                                ),
                              ),
                            _MessageBubble(
                              messageId: doc.id,
                              data: data,
                              isMe: isMe,
                              isLastMsg: isLastMsg,
                              time: _formatTime(ts),
                              currentName: 'You',
                              otherName: widget.otherName,
                              onEdit: isMe &&
                                      data['deleted'] != true &&
                                      !inputLocked
                                  ? () => _startEdit(
                                      doc.id, data['text'] ?? '', isLastMsg)
                                  : null,
                              onDelete: isMe &&
                                      data['deleted'] != true &&
                                      !inputLocked
                                  ? () => _deleteMessage(doc.id, isLastMsg)
                                  : null,
                              onReply: data['deleted'] != true && !inputLocked
                                  ? () => _startReply(
                                        doc.id,
                                        data['text'] ?? '',
                                        isMe ? 'You' : widget.otherName,
                                      )
                                  : null,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              if (!inputLocked &&
                  (_editingMessageId != null || _replyToId != null))
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  color: Bg.rustBg,
                  child: Row(
                    children: [
                      Icon(
                        _editingMessageId != null
                            ? Icons.edit
                            : Icons.reply_rounded,
                        size: 14,
                        color: Fg.rust,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _editingMessageId != null
                              ? 'Editing message'
                              : 'Replying to $_replyToSender: "${_replyToText ?? ''}"',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: Fg.rust),
                        ),
                      ),
                      GestureDetector(
                        onTap: _cancelAction,
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                              fontSize: 12,
                              color: Fg.rust,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

              if (inputLocked)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    10,
                    16,
                    MediaQuery.of(context).padding.bottom + 10,
                  ),
                  decoration: BoxDecoration(
                    color: Bg.surface,
                    border: Border(top: BorderSide(color: Bg.hairline)),
                  ),
                  child: Text(
                    'Accept the request above to reply.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Fg.inkSoft,
                    ),
                  ),
                )
              else
                Container(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    8,
                    12,
                    MediaQuery.of(context).padding.bottom + 8,
                  ),
                  decoration: BoxDecoration(
                    color: Bg.surface,
                    border: Border(top: BorderSide(color: Bg.hairline)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          maxLines: 4,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText: _editingMessageId != null
                                ? 'Edit message...'
                                : 'Message ${widget.otherName}...',
                            hintStyle: TextStyle(
                                fontSize: 14, color: Fg.inkSoft),
                            filled: true,
                            fillColor: Bg.almond,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          style: TextStyle(fontSize: 14, color: Fg.ink),
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _submitting
                            ? null
                            : () => _sendMessage(
                                editingIsLastMsg: _editingIsLastMsg,
                                inputLocked: inputLocked),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Bg.rust,
                            borderRadius: BorderRadius.circular(21),
                          ),
                          child: _submitting
                              ? const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Icon(
                                  _editingMessageId != null
                                      ? Icons.check_rounded
                                      : Icons.send_rounded,
                                  color: Fg.almond,
                                  size: 20,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String messageId;
  final Map<String, dynamic> data;
  final bool isMe;
  final bool isLastMsg;
  final String time;
  final String currentName;
  final String otherName;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onReply;

  const _MessageBubble({
    required this.messageId,
    required this.data,
    required this.isMe,
    required this.isLastMsg,
    required this.time,
    required this.currentName,
    required this.otherName,
    this.onEdit,
    this.onDelete,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final isDeleted = data['deleted'] == true;
    final text = data['text'] ?? '';
    final edited = data['edited'] == true;
    final hasReply = data['replyToId'] != null;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: isDeleted
            ? null
            : () {
                if (onEdit == null && onDelete == null && onReply == null) {
                  return;
                }
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _MessageActionsSheet(
                    onEdit: onEdit,
                    onDelete: onDelete,
                    onReply: onReply,
                  ),
                );
              },
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDeleted
                      ? Bg.hairline
                      : isMe
                          ? Bg.matchaDark
                          : Bg.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                  border: isMe
                      ? null
                      : Border.all(color: Bg.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasReply && !isDeleted)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Bg.surface.withOpacity(0.15)
                              : Bg.almond,
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              color: isMe
                                  ? Bg.surface.withOpacity(0.6)
                                  : Bg.matchaDark,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['replyToSender'] ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isMe
                                    ? Colors.white.withOpacity(0.9)
                                    : Fg.matchaDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              data['replyToText'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isMe
                                    ? Colors.white.withOpacity(0.7)
                                    : Fg.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Message text
                    if (isDeleted)
                      Text(
                        'Message deleted',
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Fg.inkSoft,
                        ),
                      )
                    else
                      Text(
                        text,
                        style: TextStyle(
                          fontSize: 14,
                          color: isMe ? Fg.almond : Fg.ink,
                          height: 1.4,
                        ),
                      ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (edited && !isDeleted)
                      Text(
                        'edited · ',
                        style: TextStyle(
                          fontSize: 10,
                          color: Fg.inkSoft,
                        ),
                      ),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 10,
                        color: Fg.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageActionsSheet extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onReply;

  const _MessageActionsSheet({this.onEdit, this.onDelete, this.onReply});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          0, 12, 0, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Bg.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Bg.hairline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          if (onReply != null)
            ListTile(
              leading: Icon(Icons.reply_rounded, color: Fg.ink),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                onReply?.call();
              },
            ),
          if (onEdit != null)
            ListTile(
              leading: Icon(Icons.edit_outlined, color: Fg.ink),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                onEdit?.call();
              },
            ),
          if (onDelete != null)
            ListTile(
              leading: Icon(Icons.delete_outline, color: Fg.danger),
              title: Text('Delete', style: TextStyle(color: Fg.danger)),
              onTap: () {
                Navigator.pop(context);
                onDelete?.call();
              },
            ),
        ],
      ),
    );
  }
}