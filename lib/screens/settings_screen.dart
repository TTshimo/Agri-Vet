import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/language_provider.dart';

/// AgroLens palette — matcha green / almond / white, light module variant.
class _C {
  static const matchaDark = Color(0xFF374530);
  static const matcha = Color(0xFF5C7148);
  static const almond = Color(0xFFF6EFE2);
  static const ink = Color(0xFF2B2820);
  static const inkSoft = Color(0xFF726C5C);
  static const rust = Color(0xFFC1703E);
  static const hairline = Color(0xFFEDE6D6);
  static const danger = Color(0xFFC94C3F);
}

/// Bottom wave finishing off the dark matcha header band — same shape
/// used across the other restyled screens for a consistent silhouette.
class _HeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height * 0.62)
      ..cubicTo(
        size.width * 0.32, size.height,
        size.width * 0.66, size.height * 0.4,
        size.width, size.height * 0.68,
      )
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _diagnosisNotifs = true;
  bool _communityNotifs = true;
  bool _messageNotifs = true;

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemeProvider>();
    final langProv = context.watch<LanguageProvider>();
    final isDark = themeProv.isDark;

    return Scaffold(
      backgroundColor: _C.almond,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: ClipPath(
              clipper: _HeaderWaveClipper(),
              child: Container(
                color: _C.matchaDark,
                padding: EdgeInsets.fromLTRB(
                  8,
                  MediaQuery.of(context).padding.top + 8,
                  16,
                  40,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded,
                          color: _C.almond, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: _C.almond,
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
                  _RadioRow(
                    icon: Icons.language,
                    label: 'English',
                    selected: langProv.language == AppLanguage.english,
                    onTap: () => langProv.setLanguage(AppLanguage.english),
                  ),
                  const Divider(height: 1, color: _C.hairline, indent: 48),
                  _RadioRow(
                    icon: Icons.translate,
                    label: 'Setswana',
                    selected: langProv.language == AppLanguage.setswana,
                    onTap: () => langProv.setLanguage(AppLanguage.setswana),
                  ),
                ]),

                _header('NOTIFICATIONS'),
                _card([
                  _ToggleRow(
                    icon: Icons.biotech_outlined,
                    label: 'Diagnosis results',
                    value: _diagnosisNotifs,
                    onChanged: (v) => setState(() => _diagnosisNotifs = v),
                  ),
                  const Divider(height: 1, color: _C.hairline, indent: 48),
                  _ToggleRow(
                    icon: Icons.forum_outlined,
                    label: 'Community activity',
                    value: _communityNotifs,
                    onChanged: (v) => setState(() => _communityNotifs = v),
                  ),
                  const Divider(height: 1, color: _C.hairline, indent: 48),
                  _ToggleRow(
                    icon: Icons.chat_bubble_outline,
                    label: 'Messages',
                    value: _messageNotifs,
                    onChanged: (v) => setState(() => _messageNotifs = v),
                  ),
                ]),

                _header('ACCOUNT'),
                _card([
                  _TileRow(
                    icon: Icons.lock_outline,
                    label: 'Change password',
                    onTap: () => _changePassword(context),
                  ),
                  const Divider(height: 1, color: _C.hairline, indent: 48),
                  _TileRow(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy settings',
                    onTap: () => _showPrivacySheet(context),
                  ),
                  const Divider(height: 1, color: _C.hairline, indent: 48),
                  _TileRow(
                    icon: Icons.download_outlined,
                    label: 'Download my data',
                    onTap: () => _showSnack(
                        context, 'Data export will be emailed to you.'),
                  ),
                  const Divider(height: 1, color: _C.hairline, indent: 48),
                  _TileRow(
                    icon: Icons.help_outline,
                    label: 'Help & support',
                    onTap: () => _showSnack(context, 'Opening support...'),
                  ),
                ]),

                _header('DANGER ZONE'),
                _card([
                  _TileRow(
                    icon: Icons.logout,
                    label: 'Log out',
                    color: _C.danger,
                    onTap: () => _confirmLogout(context),
                  ),
                  const Divider(height: 1, color: _C.hairline, indent: 48),
                  _TileRow(
                    icon: Icons.delete_forever_outlined,
                    label: 'Delete account',
                    color: _C.danger,
                    onTap: () => _confirmDeleteAccount(context),
                  ),
                ]),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 20, 2, 8),
        child: Text(t,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _C.inkSoft,
                letterSpacing: 0.9)),
      );

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
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

  void _showPrivacySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _C.almond,
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
                    color: _C.ink)),
            const SizedBox(height: 12),
            Text(
              'Your farm location data is only used to improve '
              'agricultural advice. It is never shared publicly '
              'or with third parties.',
              style: TextStyle(fontSize: 13, color: _C.inkSoft, height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.rust,
                  foregroundColor: _C.almond,
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
            style: ElevatedButton.styleFrom(backgroundColor: _C.danger),
            onPressed: () async {
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
      builder: (_) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This will permanently delete your profile, farm data, '
          'and diagnosis history. This cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _C.danger),
            onPressed: () async {
              try {
                await FirebaseAuth.instance.currentUser?.delete();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login',
                    (route) => false,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  _showSnack(
                      context, 'Re-authenticate to delete your account.');
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Delete',
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
          Icon(icon, size: 20, color: _C.matcha),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 14, color: _C.ink))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: _C.rust,
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
            Icon(icon, size: 20, color: _C.matcha),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: TextStyle(fontSize: 14, color: _C.ink))),
            if (selected)
              Icon(Icons.check_circle, size: 18, color: _C.rust),
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
            Icon(icon, size: 20, color: color ?? _C.matcha),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 14, color: color ?? _C.ink)),
            ),
            Icon(Icons.chevron_right_rounded,
                color: color ?? _C.inkSoft, size: 18),
          ]),
        ),
      );
}