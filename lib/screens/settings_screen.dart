import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/account_cleanup.dart';
import '../services/google_auth.dart';
import '../services/notification_service.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../theme/palette.dart';
import '../theme/header_wave.dart';
import '../widgets/field_background.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

const kSupportEmail = 'tumisangtshimologo@gmail.com';

class _SettingsScreenState extends State<SettingsScreen> {
  NotificationPrefs _prefs = const NotificationPrefs();
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.loadPrefs().then((p) {
      if (mounted) setState(() => _prefs = p);
    }).catchError((Object e) {
      debugPrint('Could not load notification settings: $e');
    });
  }

  Future<void> _updatePrefs(NotificationPrefs next) async {
    final previous = _prefs;
    setState(() => _prefs = next);
    try {
      await NotificationService.instance.savePrefs(next);
    } catch (e) {
      if (!mounted) return;
      setState(() => _prefs = previous);
      _showSnack(context, 'Could not save. Check your connection.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemeProvider>();
    final langProv = context.watch<LanguageProvider>();
    final isDark = themeProv.isDark;

    return Scaffold(
      backgroundColor: Bg.almond,
      body: FieldBackground(child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: ClipPath(
              clipper: const HeaderWaveClipper(),
              child: Container(
                color: Bg.matchaDark,
                padding: EdgeInsets.fromLTRB(
                  8,
                  MediaQuery.of(context).padding.top + 8,
                  16,
                  48,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded,
                          color: Fg.almond, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Fg.almond,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _header('APPEARANCE'),
                _card([
                  _ToggleRow(
                    icon: Icons.dark_mode_outlined,
                    label: 'Dark mode',
                    value: isDark,
                    onChanged: (_) => themeProv.toggle(),
                  ),
                ]),

                _header('LANGUAGE'),
                _card([
                  for (final (i, lang) in langProv.languages.indexed) ...[
                    if (i > 0)
                      Divider(height: 1, color: Bg.hairline, indent: 48),
                    _RadioRow(
                      icon: lang.code == 'en' ? Icons.language : Icons.translate,
                      label: lang.label,
                      selected: langProv.code == lang.code,
                      onTap: () => langProv.setLanguage(lang.code),
                    ),
                  ],
                ]),
                Padding(
                  padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(
                    'Diagnosis results and Learn are shown in this language. '
                    'Translations other than English are machine-generated.',
                    style: TextStyle(fontSize: 11, color: Fg.inkSoft, height: 1.4),
                  ),
                ),

                _header('NOTIFICATIONS'),
                _card([
                  _ToggleRow(
                    icon: Icons.coronavirus_outlined,
                    label: 'Disease outbreak alerts',
                    value: _prefs.alerts,
                    onChanged: (v) => _updatePrefs(_prefs.copyWith(alerts: v)),
                  ),
                  Divider(height: 1, color: Bg.hairline, indent: 48),
                  _ToggleRow(
                    icon: Icons.forum_outlined,
                    label: 'Community activity',
                    value: _prefs.community,
                    onChanged: (v) => _updatePrefs(_prefs.copyWith(community: v)),
                  ),
                  Divider(height: 1, color: Bg.hairline, indent: 48),
                  _ToggleRow(
                    icon: Icons.chat_bubble_outline,
                    label: 'Messages',
                    value: _prefs.messages,
                    onChanged: (v) => _updatePrefs(_prefs.copyWith(messages: v)),
                  ),
                ]),

                _header('ACCOUNT'),
                _card([
                  _TileRow(
                    icon: Icons.lock_outline,
                    label: 'Change password',
                    onTap: () => _changePassword(context),
                  ),
                  Divider(height: 1, color: Bg.hairline, indent: 48),
                  _TileRow(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy settings',
                    onTap: () => _showPrivacySheet(context),
                  ),
                  Divider(height: 1, color: Bg.hairline, indent: 48),
                  _TileRow(
                    icon: Icons.download_outlined,
                    label: _exporting ? 'Preparing your data...' : 'Download my data',
                    onTap: _exporting ? () {} : () => _exportData(context),
                  ),
                  Divider(height: 1, color: Bg.hairline, indent: 48),
                  _TileRow(
                    icon: Icons.help_outline,
                    label: 'Help & support',
                    onTap: () => _contactSupport(context),
                  ),
                ]),

                _header('DANGER ZONE'),
                _card([
                  _TileRow(
                    icon: Icons.logout,
                    label: 'Log out',
                    color: Bg.danger,
                    onTap: () => _confirmLogout(context),
                  ),
                  Divider(height: 1, color: Bg.hairline, indent: 48),
                  _TileRow(
                    icon: Icons.delete_forever_outlined,
                    label: 'Delete account',
                    color: Bg.danger,
                    onTap: () => _confirmDeleteAccount(context),
                  ),
                ]),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      )),
    );
  }

  Widget _header(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 20, 2, 8),
        child: Text(t,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Fg.inkSoft,
                letterSpacing: 0.9)),
      );

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: Bg.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: children),
      );

  void _showSnack(BuildContext ctx, String msg) =>
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _changePassword(BuildContext context) async {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    if (email.isEmpty) return;
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    if (context.mounted) {
      _showSnack(context, 'Password reset link sent to $email');
    }
  }

  /// Collects the user's profile, posts and diagnoses into a JSON file and
  /// opens the phone's share sheet so they can save or send it.
  Future<void> _exportData(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _exporting = true);
    try {
      final fs = FirebaseFirestore.instance;
      final results = await Future.wait([
        fs.collection('users').doc(uid).get(),
        fs.collection('posts').where('uid', isEqualTo: uid).get(),
        fs.collection('diagnoses').where('uid', isEqualTo: uid).get(),
      ]);
      final profile = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final posts = results[1] as QuerySnapshot<Map<String, dynamic>>;
      final diagnoses = results[2] as QuerySnapshot<Map<String, dynamic>>;

      final export = {
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'account': {
          'uid': uid,
          'email': FirebaseAuth.instance.currentUser?.email,
        },
        'profile': _jsonSafe(profile.data()),
        'posts': [for (final d in posts.docs) {'id': d.id, ..._jsonSafe(d.data())}],
        'diagnoses': [
          for (final d in diagnoses.docs) {'id': d.id, ..._jsonSafe(d.data())}
        ],
      };

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/agrolens-my-data.json');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(export));
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'My AgroLens data',
      );
    } catch (e) {
      debugPrint('Export failed: $e');
      if (context.mounted) {
        _showSnack(context, 'Could not export your data. Try again later.');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Firestore Timestamps/GeoPoints aren't JSON; turn them into strings.
  static dynamic _jsonSafe(dynamic value) {
    if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
    if (value is GeoPoint) return {'lat': value.latitude, 'lng': value.longitude};
    if (value is DocumentReference) return value.path;
    if (value is Map) {
      return {for (final e in value.entries) '${e.key}': _jsonSafe(e.value)};
    }
    if (value is List) return value.map(_jsonSafe).toList();
    return value;
  }

  Future<void> _contactSupport(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: kSupportEmail,
      query: 'subject=${Uri.encodeComponent('AgroLens support')}',
    );
    final opened = await launchUrl(uri);
    if (!opened && context.mounted) {
      _showSnack(context, 'Email us at $kSupportEmail');
    }
  }

  void _showPrivacySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Bg.almond,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Privacy settings',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Fg.ink)),
            const SizedBox(height: 12),
            Text(
              'Your farm location data is only used to improve '
              'agricultural advice. It is never shared publicly '
              'or with third parties.',
              style: TextStyle(fontSize: 13, color: Fg.inkSoft, height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Bg.rust,
                  foregroundColor: Fg.almond,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
            'You will need to sign in again to use AgroLens.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Bg.danger),
            onPressed: () async {
              await NotificationService.instance.stop();
              await GoogleAuth.signOut();
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              }
            },
            child: const Text('Log out',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This will permanently delete your profile, posts, comments, '
          'pals, messages and diagnosis history. This cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Bg.danger),
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteAccount(context);
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Firebase only deletes a login that was used recently, so confirm the
  /// password (or Google account) first. Then the app removes everything
  /// the user created, and finally the login itself.
  Future<void> _deleteAccount(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final email = user.email;
    if (GoogleAuth.usesGoogle(user)) {
      try {
        if (!await GoogleAuth.reauthenticate(user)) return; // cancelled
      } catch (_) {
        if (context.mounted) _showSnack(context, 'Could not confirm your Google account.');
        return;
      }
    } else if (email != null && email.isNotEmpty) {
      final password = await _askPassword(context);
      if (password == null) return;
      try {
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: email, password: password),
        );
      } on FirebaseAuthException {
        if (context.mounted) _showSnack(context, 'That password is not correct.');
        return;
      }
    }

    try {
      await AccountCleanup.deleteAllDataOf(user.uid);
    } catch (e) {
      debugPrint('Account clean-up failed: $e');
      if (context.mounted) {
        _showSnack(context, 'Could not delete your data. Check your connection and try again.');
      }
      return; // keep the login so they can try again
    }

    try {
      await NotificationService.instance.stop();
      await user.delete();
      await GoogleAuth.signOut();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      _showSnack(
        context,
        e.code == 'requires-recent-login'
            ? 'Please log out, log back in, then delete your account.'
            : 'Could not delete your account. Try again later.',
      );
    }
  }

  Future<String?> _askPassword(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm your password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Password'),
          onSubmitted: (v) => Navigator.pop(dialogContext, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Bg.danger),
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Delete my account',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          Icon(icon, size: 20, color: Fg.matcha),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 14, color: Fg.ink))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Fg.rust,
          ),
        ]),
      );
}

class _RadioRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RadioRow(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(icon, size: 20, color: Fg.matcha),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: TextStyle(fontSize: 14, color: Fg.ink))),
            if (selected)
              Icon(Icons.check_circle, size: 18, color: Fg.rust),
          ]),
        ),
      );
}

class _TileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _TileRow(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(icon, size: 20, color: color ?? Fg.matcha),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 14, color: color ?? Fg.ink)),
            ),
            Icon(Icons.chevron_right_rounded,
                color: color ?? Fg.inkSoft, size: 18),
          ]),
        ),
      );
}