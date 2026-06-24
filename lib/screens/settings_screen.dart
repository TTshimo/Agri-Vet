// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../main.dart';
// import '../../services/translation_service.dart';
// import 'login_screen.dart';

// class SettingsScreen extends StatefulWidget {
//   const SettingsScreen({super.key});

//   @override
//   State<SettingsScreen> createState() => _SettingsScreenState();
// }

// class _SettingsScreenState extends State<SettingsScreen> {
//   final _translation = TranslationService();

//   bool _darkMode = false;
//   bool _offlineMode = true;
//   bool _diseaseAlerts = true;
//   bool _communityReplies = false;

//   @override
//   void initState() {
//     super.initState();
//     _loadPrefs();
//   }

//   Future<void> _loadPrefs() async {
//     final prefs = await SharedPreferences.getInstance();
//     setState(() {
//       _darkMode = prefs.getBool('dark_mode') ?? false;
//       _offlineMode = prefs.getBool('offline_mode') ?? true;
//       _diseaseAlerts = prefs.getBool('disease_alerts') ?? true;
//       _communityReplies = prefs.getBool('community_replies') ?? false;
//     });
//   }

//   Future<void> _setPref(String key, bool value) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setBool(key, value);
//   }

//   Future<void> _signOut() async {
//     final confirmed = await showDialog<bool>(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: const Text('Sign out'),
//         content: const Text('Are you sure you want to sign out?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(false),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () => Navigator.of(context).pop(true),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: AppColors.red,
//             ),
//             child: const Text('Sign out'),
//           ),
//         ],
//       ),
//     );

//     if (confirmed == true) {
//       await FirebaseAuth.instance.signOut();
//       if (mounted) {
//         Navigator.of(context).pushAndRemoveUntil(
//           MaterialPageRoute(builder: (_) => const LoginScreen()),
//           (_) => false,
//         );
//       }
//     }
//   }

//   void _showChangePassword() {
//     final controller = TextEditingController();
//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: const Text('Change password'),
//         content: TextField(
//           controller: controller,
//           obscureText: true,
//           decoration: const InputDecoration(
//             hintText: 'New password',
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () async {
//               try {
//                 await FirebaseAuth.instance.currentUser
//                     ?.updatePassword(controller.text);
//                 if (mounted) {
//                   Navigator.of(context).pop();
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(
//                       content: Text('Password updated successfully'),
//                       backgroundColor: AppColors.greenDark,
//                     ),
//                   );
//                 }
//               } catch (e) {
//                 if (mounted) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(
//                       content: Text(
//                           'Failed to update password. Please re-login and try again.'),
//                       backgroundColor: AppColors.red,
//                     ),
//                   );
//                 }
//               }
//             },
//             child: const Text('Update'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showLanguagePicker() {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: AppColors.background,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (_) => Padding(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'Select language',
//               style: TextStyle(
//                 fontSize: 17,
//                 fontWeight: FontWeight.w600,
//                 color: AppColors.textPrimary,
//               ),
//             ),
//             const SizedBox(height: 16),
//             ...AppLanguage.values.map((lang) {
//               final isSelected =
//                   _translation.language == lang;
//               return GestureDetector(
//                 onTap: () async {
//                   await _translation.setLanguage(lang);
//                   if (mounted) {
//                     setState(() {});
//                     Navigator.of(context).pop();
//                   }
//                 },
//                 child: Container(
//                   margin: const EdgeInsets.only(bottom: 10),
//                   padding: const EdgeInsets.all(14),
//                   decoration: BoxDecoration(
//                     color: isSelected
//                         ? AppColors.greenLight
//                         : Colors.white,
//                     borderRadius:
//                         BorderRadius.circular(AppRadius.card),
//                     border: Border.all(
//                       color: isSelected
//                           ? AppColors.greenMid
//                           : AppColors.border,
//                     ),
//                   ),
//                   child: Row(
//                     children: [
//                       Text(
//                         lang.flag,
//                         style: const TextStyle(fontSize: 22),
//                       ),
//                       const SizedBox(width: 12),
//                       Text(
//                         lang.label,
//                         style: TextStyle(
//                           fontSize: 15,
//                           fontWeight: isSelected
//                               ? FontWeight.w600
//                               : FontWeight.w400,
//                           color: isSelected
//                               ? AppColors.greenDark
//                               : AppColors.textPrimary,
//                         ),
//                       ),
//                       const Spacer(),
//                       if (isSelected)
//                         const Icon(
//                           Icons.check_circle_rounded,
//                           color: AppColors.greenDark,
//                           size: 20,
//                         ),
//                     ],
//                   ),
//                 ),
//               );
//             }),
//             const SizedBox(height: 8),
//           ],
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       body: CustomScrollView(
//         slivers: [
//           SliverToBoxAdapter(
//             child: Container(
//               color: AppColors.greenDark,
//               padding: EdgeInsets.fromLTRB(
//                 20,
//                 MediaQuery.of(context).padding.top + 16,
//                 20,
//                 20,
//               ),
//               child: Row(
//                 children: [
//                   GestureDetector(
//                     onTap: () => Navigator.of(context).pop(),
//                     child: const Icon(
//                       Icons.arrow_back_rounded,
//                       color: AppColors.greenHint,
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//                   const Text(
//                     'Settings',
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.w600,
//                       color: Colors.white,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),

//           // Preferences
//           const _SectionHeader(label: 'PREFERENCES'),
//           SliverToBoxAdapter(
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(AppRadius.card),
//                   border: Border.all(color: AppColors.border),
//                 ),
//                 child: Column(
//                   children: [
//                     // Language
//                     _SettingRow(
//                       label: 'Language',
//                       subtitle:
//                           '${_translation.language.flag} ${_translation.language.label}',
//                       trailing: const Icon(
//                         Icons.chevron_right_rounded,
//                         color: AppColors.textSecondary,
//                       ),
//                       onTap: _showLanguagePicker,
//                     ),
//                     const Divider(height: 1, color: AppColors.border),

//                     // Dark mode
//                     _SettingRow(
//                       label: 'Dark mode',
//                       subtitle: 'Change app appearance',
//                       trailing: _Toggle(
//                         value: _darkMode,
//                         onChanged: (v) {
//                           setState(() => _darkMode = v);
//                           _setPref('dark_mode', v);
//                         },
//                       ),
//                     ),
//                     const Divider(height: 1, color: AppColors.border),

//                     // Offline mode
//                     _SettingRow(
//                       label: 'Offline mode',
//                       subtitle: 'Run models without internet',
//                       trailing: _Toggle(
//                         value: _offlineMode,
//                         onChanged: (v) {
//                           setState(() => _offlineMode = v);
//                           _setPref('offline_mode', v);
//                         },
//                       ),
//                       isLast: true,
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),

//           // Notifications
//           const _SectionHeader(label: 'NOTIFICATIONS'),
//           SliverToBoxAdapter(
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(AppRadius.card),
//                   border: Border.all(color: AppColors.border),
//                 ),
//                 child: Column(
//                   children: [
//                     _SettingRow(
//                       label: 'Disease alerts',
//                       subtitle: 'Outbreaks in your region',
//                       trailing: _Toggle(
//                         value: _diseaseAlerts,
//                         onChanged: (v) {
//                           setState(() => _diseaseAlerts = v);
//                           _setPref('disease_alerts', v);
//                         },
//                       ),
//                     ),
//                     const Divider(height: 1, color: AppColors.border),
//                     _SettingRow(
//                       label: 'Community replies',
//                       subtitle: 'When someone replies to your post',
//                       trailing: _Toggle(
//                         value: _communityReplies,
//                         onChanged: (v) {
//                           setState(() => _communityReplies = v);
//                           _setPref('community_replies', v);
//                         },
//                       ),
//                       isLast: true,
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),

//           // Account
//           const _SectionHeader(label: 'ACCOUNT'),
//           SliverToBoxAdapter(
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(AppRadius.card),
//                   border: Border.all(color: AppColors.border),
//                 ),
//                 child: Column(
//                   children: [
//                     _SettingRow(
//                       label: 'Change password',
//                       trailing: const Icon(
//                         Icons.chevron_right_rounded,
//                         color: AppColors.textSecondary,
//                       ),
//                       onTap: _showChangePassword,
//                     ),
//                     const Divider(height: 1, color: AppColors.border),
//                     _SettingRow(
//                       label: 'Sign out',
//                       labelColor: AppColors.red,
//                       trailing: const Icon(
//                         Icons.logout_rounded,
//                         color: AppColors.red,
//                         size: 18,
//                       ),
//                       onTap: _signOut,
//                       isLast: true,
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),

//           const SliverToBoxAdapter(child: SizedBox(height: 32)),
//         ],
//       ),
//     );
//   }
// }

// // ── Helper widgets ────────────────────────────────────────────────────────────

// class _SectionHeader extends StatelessWidget {
//   final String label;
//   const _SectionHeader({required this.label});

//   @override
//   Widget build(BuildContext context) {
//     return SliverToBoxAdapter(
//       child: Padding(
//         padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
//         child: Text(
//           label,
//           style: const TextStyle(
//             fontSize: 11,
//             fontWeight: FontWeight.w600,
//             color: AppColors.textSecondary,
//             letterSpacing: 0.88,
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _SettingRow extends StatelessWidget {
//   final String label;
//   final String? subtitle;
//   final Widget trailing;
//   final VoidCallback? onTap;
//   final bool isLast;
//   final Color? labelColor;

//   const _SettingRow({
//     required this.label,
//     this.subtitle,
//     required this.trailing,
//     this.onTap,
//     this.isLast = false,
//     this.labelColor,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Padding(
//         padding: const EdgeInsets.symmetric(
//           horizontal: 16,
//           vertical: 14,
//         ),
//         child: Row(
//           children: [
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     label,
//                     style: TextStyle(
//                       fontSize: 14,
//                       color: labelColor ?? AppColors.textPrimary,
//                       fontWeight: FontWeight.w400,
//                     ),
//                   ),
//                   if (subtitle != null) ...[
//                     const SizedBox(height: 2),
//                     Text(
//                       subtitle!,
//                       style: const TextStyle(
//                         fontSize: 12,
//                         color: AppColors.textSecondary,
//                       ),
//                     ),
//                   ],
//                 ],
//               ),
//             ),
//             trailing,
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _Toggle extends StatelessWidget {
//   final bool value;
//   final ValueChanged<bool> onChanged;

//   const _Toggle({required this.value, required this.onChanged});

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: () => onChanged(!value),
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 200),
//         width: 44,
//         height: 24,
//         decoration: BoxDecoration(
//           color: value ? AppColors.greenDark : AppColors.background2,
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(
//             color: value ? AppColors.greenDark : AppColors.border,
//           ),
//         ),
//         child: AnimatedAlign(
//           duration: const Duration(milliseconds: 200),
//           alignment:
//               value ? Alignment.centerRight : Alignment.centerLeft,
//           child: Container(
//             width: 18,
//             height: 18,
//             margin: const EdgeInsets.symmetric(horizontal: 2),
//             decoration: const BoxDecoration(
//               color: Colors.white,
//               shape: BoxShape.circle,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

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

          // ── APPEARANCE ─────────────────────────────────────────
          _header('APPEARANCE'),
          _card(cardColor, borderColor, [
            _ToggleRow(
              icon: Icons.dark_mode_outlined,
              label: 'Dark mode',
              value: isDark,
              onChanged: (_) => themeProv.toggle(),
            ),
          ]),

          // ── LANGUAGE ───────────────────────────────────────────
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

          // ── NOTIFICATIONS ──────────────────────────────────────
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

          // ── ACCOUNT ────────────────────────────────────────────
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

          // ── DANGER ZONE ────────────────────────────────────────
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

  // ── Helpers ──────────────────────────────────────────────────────────────
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
                Navigator.of(context)
                    .popUntil((r) => r.isFirst);
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
                await FirebaseAuth.instance.currentUser
                    ?.delete();
                if (context.mounted) {
                  Navigator.of(context)
                      .popUntil((r) => r.isFirst);
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

// ── Reusable row widgets ──────────────────────────────────────────────────────
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
            activeColor: AppColors.greenDark,
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
