import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../main.dart';

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
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
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
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
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
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: SizedBox.shrink(),
          );
        }

        final isPending = status == 'pending';
        final iAmRequester = requestedBy == widget.currentUid;
        final inputLocked = isPending && !iAmRequester;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              // Header
              Container(
                color: AppColors.greenDark,
                padding: EdgeInsets.fromLTRB(
                  0,
                  MediaQuery.of(context).padding.top + 8,
                  16,
                  12,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.greenMid,
                      child: Text(
                        _initials(widget.otherName),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            isPending ? 'Message request' : 'Farmer',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.greenHint),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (isPending)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: AppColors.amberLight,
                  child: iAmRequester
                      ? Row(
                          children: [
                            const Icon(Icons.schedule_rounded,
                                size: 16, color: AppColors.amberText),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Message request sent — waiting for '
                                '${widget.otherName} to accept.',
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.amberText),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.mark_email_unread_rounded,
                                    size: 16, color: AppColors.amberText),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${widget.otherName} wants to message you.',
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.amberText),
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
                                        backgroundColor: AppColors.greenDark,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(
                                                  AppRadius.button),
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
                                        foregroundColor: AppColors.red,
                                        side: const BorderSide(
                                            color: AppColors.red),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(
                                                  AppRadius.button),
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
                      return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.greenDark),
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
                              backgroundColor: AppColors.greenLight,
                              child: Text(
                                _initials(widget.otherName),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.greenDeep,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.otherName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isPending && iAmRequester
                                  ? 'Say hello to start the conversation.'
                                  : 'Send a message to start the conversation.',
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.textSecondary),
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
                                    color: AppColors.border,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    dateLabel,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
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
                  color: AppColors.amberLight,
                  child: Row(
                    children: [
                      Icon(
                        _editingMessageId != null
                            ? Icons.edit
                            : Icons.reply_rounded,
                        size: 14,
                        color: AppColors.amberText,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _editingMessageId != null
                              ? 'Editing message'
                              : 'Replying to $_replyToSender: "${_replyToText ?? ''}"',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.amberText),
                        ),
                      ),
                      GestureDetector(
                        onTap: _cancelAction,
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

              if (inputLocked)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    10,
                    16,
                    MediaQuery.of(context).padding.bottom + 10,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Text(
                    'Accept the request above to reply.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
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
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.border)),
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
                            hintStyle: const TextStyle(fontSize: 14),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide:
                                  const BorderSide(color: AppColors.border),
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
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
                            color: AppColors.greenDark,
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
                                  color: Colors.white,
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
                      ? AppColors.border
                      : isMe
                          ? AppColors.greenDark
                          : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                  border: isMe
                      ? null
                      : Border.all(color: AppColors.border),
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
                              ? Colors.white.withOpacity(0.15)
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              color: isMe
                                  ? Colors.white.withOpacity(0.6)
                                  : AppColors.greenDark,
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
                                    : AppColors.greenDark,
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
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Message text
                    if (isDeleted)
                      const Text(
                        'Message deleted',
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary,
                        ),
                      )
                    else
                      Text(
                        text,
                        style: TextStyle(
                          fontSize: 14,
                          color: isMe ? Colors.white : AppColors.textPrimary,
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
                      const Text(
                        'edited · ',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          if (onReply != null)
            ListTile(
              leading: const Icon(Icons.reply_rounded,
                  color: AppColors.textPrimary),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                onReply?.call();
              },
            ),
          if (onEdit != null)
            ListTile(
              leading: const Icon(Icons.edit_outlined,
                  color: AppColors.textPrimary),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                onEdit?.call();
              },
            ),
          if (onDelete != null)
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppColors.red),
              title: const Text('Delete',
                  style: TextStyle(color: AppColors.red)),
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