import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

/// Which kinds of notification a user wants. Stored in the owner-only doc
/// users/{uid}/private/notifications.
class NotificationPrefs {
  final bool alerts; // disease outbreak alerts (from the news scraper)
  final bool community; // likes, comments, replies, pal requests
  final bool messages; // chat messages and message requests

  const NotificationPrefs({
    this.alerts = true,
    this.community = true,
    this.messages = true,
  });

  factory NotificationPrefs.fromMap(Map<String, dynamic>? map) => NotificationPrefs(
        alerts: map?['alerts'] as bool? ?? true,
        community: map?['community'] as bool? ?? true,
        messages: map?['messages'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() =>
      {'alerts': alerts, 'community': community, 'messages': messages};

  NotificationPrefs copyWith({bool? alerts, bool? community, bool? messages}) =>
      NotificationPrefs(
        alerts: alerts ?? this.alerts,
        community: community ?? this.community,
        messages: messages ?? this.messages,
      );
}

/// Phone notifications, entirely on Firebase's free plan (no Cloud Functions):
///
/// * Disease outbreak alerts arrive by push even when the app is closed:
///   the news scraper (GitHub Actions) sends them to the `disease_alerts`
///   topic, which this phone joins or leaves with the Settings switch.
/// * Likes, comments, pal requests and chat messages are shown as phone
///   notifications while AgroLens is open or still running in the
///   background: the app listens to the user's bell list and pops up
///   anything new, if that kind is switched on in Settings.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  static const alertTopic = 'disease_alerts';

  /// Opens the in-app notification list; set by the app shell.
  VoidCallback? openNotifications;

  final _messaging = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  String? _uid;
  NotificationPrefs _prefs = const NotificationPrefs();
  bool _primed = false; // first snapshot = what's already there; don't pop it up

  static const _channels = [
    AndroidNotificationChannel('disease_alerts', 'Disease outbreak alerts',
        description: 'Outbreaks of diseases AgroLens diagnoses, near you',
        importance: Importance.high),
    AndroidNotificationChannel('community', 'Community',
        description: 'Likes, comments, replies and pal requests',
        importance: Importance.defaultImportance),
    AndroidNotificationChannel('messages', 'Messages',
        description: 'New chat messages and message requests',
        importance: Importance.high),
  ];

  DocumentReference<Map<String, dynamic>> _doc(String uid) => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('private')
      .doc('notifications');

  /// Call once the user is signed in (from the app shell).
  Future<void> start() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid == _uid || kIsWeb) return;
    _uid = uid;

    try {
      await _initLocalNotifications();
      await _messaging.requestPermission();

      _prefs = await loadPrefs();
      await _applyAlertTopic(_prefs.alerts);

      _primed = false;
      _subscriptions.add(FirebaseFirestore.instance
          .collection('notifications')
          .doc(uid)
          .collection('items')
          .where('read', isEqualTo: false)
          .snapshots()
          .listen(_onBellChanged, onError: (Object e) {
        debugPrint('Notification listener stopped: $e');
      }));

      _subscriptions.add(FirebaseMessaging.onMessage.listen(_showForeground));
      _subscriptions.add(FirebaseMessaging.onMessageOpenedApp.listen(_open));
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _open(initial);
    } catch (e) {
      debugPrint('NotificationService.start failed: $e');
    }
  }

  /// Call before signing out so this phone stops getting that user's pushes.
  Future<void> stop() async {
    final uid = _uid;
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    _uid = null;
    if (uid == null || kIsWeb) return;
    try {
      await _messaging.unsubscribeFromTopic(alertTopic);
    } catch (e) {
      debugPrint('NotificationService.stop failed: $e');
    }
  }

  Future<NotificationPrefs> loadPrefs() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const NotificationPrefs();
    final snap = await _doc(uid).get();
    return NotificationPrefs.fromMap(snap.data()?['prefs'] as Map<String, dynamic>?);
  }

  Future<void> savePrefs(NotificationPrefs prefs) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _doc(uid).set({'prefs': prefs.toMap()}, SetOptions(merge: true));
    _prefs = prefs;
    await _applyAlertTopic(prefs.alerts);
  }

  /// Pops up a phone notification for each new unread bell item, and for a
  /// chat item updated by a newer message.
  void _onBellChanged(QuerySnapshot<Map<String, dynamic>> snap) {
    if (!_primed) {
      _primed = true;
      return;
    }
    for (final change in snap.docChanges) {
      if (change.type == DocumentChangeType.removed) continue;
      final data = change.doc.data();
      if (data == null || data['read'] == true) continue;
      if (change.type == DocumentChangeType.modified && data['type'] != 'message') continue;
      final category = categoryFor(data['type'] as String?);
      final allowed = category == 'messages' ? _prefs.messages : _prefs.community;
      if (!allowed) continue;
      final text = pushText(data);
      _showLocal(change.doc.id, text.title, text.body, category,
          {'type': '${data['type'] ?? ''}', 'itemId': change.doc.id});
    }
  }

  /// Which Settings switch (and Android channel) a notification type uses.
  static String categoryFor(String? type) => const {
        'msg_request': 'messages',
        'msg_accept': 'messages',
        'message': 'messages',
      }[type] ??
      'community';

  /// Title and body, matching the wording of the in-app list.
  static ({String title, String body}) pushText(Map<String, dynamic> data) {
    final name = (data['fromName'] as String?) ?? 'A farmer';
    switch (data['type']) {
      case 'like':
        return (title: 'New like', body: '$name liked your post');
      case 'comment':
        return (title: 'New comment', body: '$name commented on your post');
      case 'reply':
        return (title: 'New reply', body: '$name replied to your comment');
      case 'pal_request':
        return (title: 'Pal request', body: '$name sent you a pal request');
      case 'pal_accept':
        return (title: 'New pal', body: '$name accepted your pal request');
      case 'msg_request':
        return (title: 'Message request', body: '$name wants to message you');
      case 'msg_accept':
        return (title: 'Request accepted', body: '$name accepted your message request');
      case 'message':
        final preview = (data['preview'] as String?) ?? '';
        return (title: name, body: preview.isEmpty ? 'Sent you a message' : preview);
      default:
        return (title: 'AgroLens', body: 'You have a new notification');
    }
  }

  void _showLocal(String tag, String? title, String? body, String channelId,
      Map<String, String> data) {
    final channel = _channels.firstWhere((c) => c.id == channelId,
        orElse: () => _channels[1]);
    _local.show(
      // Same id for the same bell item: a chat's newer message replaces
      // its older notification instead of stacking.
      tag.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(channel.id, channel.name,
            channelDescription: channel.description,
            importance: channel.importance,
            priority: Priority.high),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: Uri(queryParameters: data).query,
    );
  }

  Future<void> _applyAlertTopic(bool enabled) async {
    if (kIsWeb) return; // topics are not supported on web
    if (enabled) {
      await _messaging.subscribeToTopic(alertTopic);
    } else {
      await _messaging.unsubscribeFromTopic(alertTopic);
    }
  }

  Future<void> _initLocalNotifications() async {
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) =>
          _openData(_decodePayload(response.payload)),
    );
    final android = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    for (final channel in _channels) {
      await android?.createNotificationChannel(channel);
    }
    // iOS shows pushes in the foreground natively.
    await _messaging.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true);
  }

  /// Android doesn't display pushes while the app is open; show them here.
  /// Android doesn't display pushes (outbreak alerts) while the app is
  /// open; show them here. iOS shows them itself.
  void _showForeground(RemoteMessage message) {
    final n = message.notification;
    if (n == null || defaultTargetPlatform != TargetPlatform.android) return;
    _showLocal('${message.messageId ?? message.hashCode}', n.title, n.body,
        n.android?.channelId ?? 'disease_alerts',
        message.data.map((k, v) => MapEntry(k, '$v')));
  }

  Map<String, String> _decodePayload(String? payload) =>
      payload == null || payload.isEmpty ? const {} : Uri.splitQueryString(payload);

  void _open(RemoteMessage message) =>
      _openData(message.data.map((k, v) => MapEntry(k, '$v')));

  /// Disease alerts open the news article; everything else opens the
  /// in-app notification list, where each item links to its post or chat.
  void _openData(Map<String, String> data) {
    final url = data['url'];
    if (data['type'] == 'disease_alert' && url != null && url.isNotEmpty) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return;
    }
    openNotifications?.call();
  }
}
