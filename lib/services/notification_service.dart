import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

/// Which kinds of push notification a user wants. Stored, with the
/// device tokens, in the owner-only doc users/{uid}/private/notifications,
/// where the Cloud Function (functions/index.js) reads them.
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

/// Push notifications: permission, device token registration, the
/// disease-alert topic, showing notifications while the app is open, and
/// opening the right screen when one is tapped.
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

      final token = await _messaging.getToken();
      if (token != null) await _saveToken(uid, token);
      _subscriptions.add(_messaging.onTokenRefresh.listen((t) => _saveToken(uid, t)));

      final prefs = await loadPrefs();
      await _applyAlertTopic(prefs.alerts);

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
      final token = await _messaging.getToken();
      if (token != null) {
        await _doc(uid).set({
          'tokens': FieldValue.arrayRemove([token]),
        }, SetOptions(merge: true));
      }
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
    await _applyAlertTopic(prefs.alerts);
  }

  Future<void> _applyAlertTopic(bool enabled) async {
    if (kIsWeb) return; // topics are not supported on web
    if (enabled) {
      await _messaging.subscribeToTopic(alertTopic);
    } else {
      await _messaging.unsubscribeFromTopic(alertTopic);
    }
  }

  Future<void> _saveToken(String uid, String token) => _doc(uid).set({
        'tokens': FieldValue.arrayUnion([token]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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
  void _showForeground(RemoteMessage message) {
    final n = message.notification;
    if (n == null || defaultTargetPlatform != TargetPlatform.android) return;
    final channelId = n.android?.channelId ?? 'community';
    final channel = _channels.firstWhere((c) => c.id == channelId,
        orElse: () => _channels[1]);
    _local.show(
      message.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(channel.id, channel.name,
            channelDescription: channel.description,
            importance: channel.importance,
            priority: Priority.high),
      ),
      payload: Uri(queryParameters: message.data.map((k, v) => MapEntry(k, '$v')))
          .query,
    );
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
