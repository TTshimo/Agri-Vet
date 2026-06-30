import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../main.dart';
import '../../providers/theme_provider.dart';
import '../../providers/language_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _diagnosisNotifs = true;
  bool _communityNotifs = true;
  bool _messageNotifs   = true;

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemeProvider>();
    final langProv  = context.watch<LanguageProvider>();
    final isDark    = themeProv.isDark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF2C2C2C)
        : AppColors.border;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.greenDark,
        foregroundColor: Colors.white,
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // Appearance
          _header('APPEARANCE'),
          _card(cardColor, borderColor, [
            _ToggleRow(
              icon: Icons.dark_mode_outlined,
              label: 'Dark mode',
              value: isDark,
              onChanged: (_) => themeProv.toggle(),
            ),
          ]),

          // Language
          _header('LANGUAGE'),
          _card(cardColor, borderColor, [
            _RadioRow(
              icon: Icons.language,
              label: 'English',
              selected: langProv.language == AppLanguage.english,
              onTap: () =>
                  langProv.setLanguage(AppLanguage.english),
            ),
            Divider(height: 1, color: borderColor),
            _RadioRow(
              icon: Icons.translate,
              label: 'Setswana',
              selected: langProv.language == AppLanguage.setswana,
              onTap: () =>
                  langProv.setLanguage(AppLanguage.setswana),
            ),
          ]),

          // Notifications
          _header('NOTIFICATIONS'),
          _card(cardColor, borderColor, [
            _ToggleRow(
              icon: Icons.biotech_outlined,
              label: 'Diagnosis results',
              value: _diagnosisNotifs,
              onChanged: (v) => setState(() => _diagnosisNotifs = v),
            ),
            Divider(height: 1, color: borderColor),
            _ToggleRow(
              icon: Icons.forum_outlined,
              label: 'Community activity',
              value: _communityNotifs,
              onChanged: (v) => setState(() => _communityNotifs = v),
            ),
            Divider(height: 1, color: borderColor),
            _ToggleRow(
              icon: Icons.chat_bubble_outline,
              label: 'Messages',
              value: _messageNotifs,
              onChanged: (v) => setState(() => _messageNotifs = v),
            ),
          ]),

          // Account
          _header('ACCOUNT'),
          _card(cardColor, borderColor, [
            _TileRow(
              icon: Icons.lock_outline,
              label: 'Change password',
              onTap: () => _changePassword(context),
            ),
            Divider(height: 1, color: borderColor),
            _TileRow(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy settings',
              onTap: () => _showPrivacySheet(context),
            ),
            Divider(height: 1, color: borderColor),
            _TileRow(
              icon: Icons.download_outlined,
              label: 'Download my data',
              onTap: () => _showSnack(context,
                  'Data export will be emailed to you.'),
            ),
            Divider(height: 1, color: borderColor),
            _TileRow(
              icon: Icons.help_outline,
              label: 'Help & support',
              onTap: () => _showSnack(context,
                  'Opening support...'),
            ),
          ]),

          // Danger zone
          _header('DANGER ZONE'),
          _card(cardColor, borderColor, [
            _TileRow(
              icon: Icons.logout,
              label: 'Log out',
              color: const Color(0xFFD32F2F),
              onTap: () => _confirmLogout(context),
            ),
            Divider(height: 1, color: borderColor),
            _TileRow(
              icon: Icons.delete_forever_outlined,
              label: 'Delete account',
              color: const Color(0xFFD32F2F),
              onTap: () => _confirmDeleteAccount(context),
            ),
          ]),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // Helpers
  Widget _header(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 20, 2, 8),
        child: Text(t,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.9)),
      );

  Widget _card(Color bg, Color border, List<Widget> children) =>
      Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: border),
        ),
        child: Column(children: children),
      );

  void _showSnack(BuildContext ctx, String msg) =>
      ScaffoldMessenger.of(ctx)
          .showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _changePassword(BuildContext context) async {
    final email =
        FirebaseAuth.instance.currentUser?.email ?? '';
    if (email.isEmpty) return;
    await FirebaseAuth.instance
        .sendPasswordResetEmail(email: email);
    if (context.mounted) {
      _showSnack(context,
          'Password reset link sent to $email');
    }
  }

  void _showPrivacySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Privacy settings',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            const Text(
              'Your farm location data is only used to improve '
              'agricultural advice. It is never shared publicly '
              'or with third parties.',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.greenDark),
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it',
                    style: TextStyle(color: Colors.white)),
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
            'You will need to sign in again to use AgriVet.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F)),
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
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F)),
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
                  _showSnack(context,
                      'Re-authenticate to delete your account.');
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

// Reusable row widgets
class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.icon, required this.label,
      required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Text(label,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textPrimary))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.greenDark,
          ),
        ]),
      );
}

class _RadioRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RadioRow({required this.icon, required this.label,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) =>
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(child: Text(label,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textPrimary))),
            if (selected)
              const Icon(Icons.check_circle,
                  size: 18, color: AppColors.greenDark),
          ]),
        ),
      );
}

class _TileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _TileRow({required this.icon, required this.label,
      required this.onTap, this.color});

  @override
  Widget build(BuildContext context) =>
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(icon, size: 20,
                color: color ?? AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      color: color ?? AppColors.textPrimary)),
            ),
            Icon(Icons.chevron_right_rounded,
                color: color ?? AppColors.textSecondary),
          ]),
        ),
      );
}