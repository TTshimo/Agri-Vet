import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_screen.dart';
import '../services/google_auth.dart';
import '../services/notification_service.dart';
import 'profile_social_menu.dart';
import 'settings_screen.dart';
import '../theme/palette.dart';
import '../widgets/page_header.dart';
import '../widgets/field_background.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.previewData});

  /// Screenshot tests only: render with this profile instead of loading one.
  @visibleForTesting
  final Map<String, dynamic>? previewData;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;

  Future<void> _logout() async {
    await NotificationService.instance.stop();
    await GoogleAuth.signOut();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    final preview = widget.previewData;
    return Scaffold(
      backgroundColor: Bg.almond,
      body: FieldBackground(
        child: preview != null
            ? _content(context, 'preview', preview)
            : uid == null
            ? const Center(child: Text('Not signed in'))
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                builder: (context, snapshot) => _content(
                    context, uid, snapshot.data?.data() ?? const <String, dynamic>{}),
              ),
      ),
    );
  }

  Widget _content(BuildContext context, String uid, Map<String, dynamic> data) {
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Same header as Home, Diagnose, Community and Learn.
                        const WavyPageHeader(title: 'Profile'),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildIdentityCard(data),
                              const SizedBox(height: 12),
                              _buildStatsRow(uid),
                              const SizedBox(height: 20),
                              _buildSectionLabel('Community'),
                              _buildCommunityMenu(context, uid),
                              const SizedBox(height: 20),
                              _buildSectionLabel('Account details',
                                  onEdit: () => _editAccount(context, uid, data)),
                              _buildAccountDetails(data),
                              const SizedBox(height: 20),
                              _buildSectionLabel('Farm details',
                                  onEdit: () => _editFarm(context, uid, data)),
                              _buildFarmDetails(data),
                              const SizedBox(height: 20),
                              _buildSectionLabel('App'),
                              _buildSettingsTile(context),
                              const SizedBox(height: 22),
                              _buildLogoutButton(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
  }

  static String _v(Object? value) {
    if (value is List) return value.isEmpty ? '—' : value.join(', ');
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '—' : text;
  }

  /// Name, place and avatar, on a card under the header.
  Widget _buildIdentityCard(Map<String, dynamic> data) {
    final rawName = (data['name'] as String?)?.trim() ?? '';
    final name = rawName.isNotEmpty ? rawName : 'Add your name';
    final location = (data['location'] as String?)?.trim().isNotEmpty == true
        ? data['location'] as String
        : 'Add your location';
    final photoUrl = (data['photoUrl'] as String?) ?? '';
    final initials = rawName.isEmpty
        ? '?'
        : rawName.split(RegExp(r'\s+')).take(2).map((s) => s[0]).join().toUpperCase();
    final uid = _uid;

    return Material(
      color: Bg.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: uid == null ? null : () => _editAccount(context, uid, data),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Bg.rust,
                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isNotEmpty
                    ? null
                    : Text(initials,
                        style: TextStyle(color: Fg.almond, fontSize: 20, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: rawName.isEmpty ? Fg.inkSoft : Fg.ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: Fg.inkSoft),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Fg.inkSoft, fontSize: 12.5)),
                        ),
                      ],
                    ),
                    if (data['verified'] == true) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.verified_outlined, size: 14, color: Fg.matcha),
                          const SizedBox(width: 4),
                          Text('Verified farmer',
                              style: TextStyle(
                                  color: Fg.matcha, fontSize: 11.5, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.edit_outlined, size: 18, color: Fg.matcha),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editAccount(BuildContext context, String uid, Map<String, dynamic> data) {
    return _showEditSheet(
      context,
      uid: uid,
      title: 'Account details',
      fields: [
        _EditField('name', 'Full name', data['name']),
        _EditField('username', 'Username', data['username']),
        _EditField('bio', 'Bio', data['bio'], maxLines: 3),
        _EditField('phone', 'Phone', data['phone'], keyboard: TextInputType.phone),
        _EditField('location', 'Location', data['location']),
      ],
    );
  }

  Future<void> _editFarm(BuildContext context, String uid, Map<String, dynamic> data) {
    final animals = (data['animalsKept'] as List?)?.join(', ') ?? '';
    return _showEditSheet(
      context,
      uid: uid,
      title: 'Farm details',
      fields: [
        _EditField('farmName', 'Farm name', data['farmName']),
        _EditField('farmerType', 'Farm type', data['farmerType'],
            options: const ['livestock', 'crops', 'both']),
        _EditField('animalsKept', 'Animals kept (comma separated)', animals, isList: true),
        _EditField('waterSource', 'Water source', data['waterSource']),
        _EditField('soilType', 'Soil type', data['soilType']),
        _EditField('yearsFarming', 'Years farming', data['yearsFarming'],
            keyboard: TextInputType.number),
      ],
    );
  }

  Future<void> _showEditSheet(
    BuildContext context, {
    required String uid,
    required String title,
    required List<_EditField> fields,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Bg.almond,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditSheet(uid: uid, title: title, fields: fields),
    );
  }

  Widget _buildStatsRow(String uid) {
    return Row(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('diagnoses')
                .where('uid', isEqualTo: uid)
                .snapshots(),
            builder: (context, snap) =>
                _StatCard(value: '${snap.data?.docs.length ?? 0}', label: 'Diagnoses'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .where('uid', isEqualTo: uid)
                .snapshots(),
            builder: (context, snap) =>
                _StatCard(value: '${snap.data?.docs.length ?? 0}', label: 'Posts'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
            builder: (context, snap) {
              final createdAt = (snap.data?.data()?['createdAt'] as Timestamp?)?.toDate() ??
                  FirebaseAuth.instance.currentUser?.metadata.creationTime;
              final label = createdAt == null ? '—' : _monthsSince(createdAt);
              return _StatCard(value: label, label: 'Active');
            },
          ),
        ),
      ],
    );
  }

  String _monthsSince(DateTime date) {
    final months = DateTime.now().difference(date).inDays ~/ 30;
    return months < 1 ? '<1mo' : '${months}mo';
  }

  Widget _buildSectionLabel(String text, {VoidCallback? onEdit}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: TextStyle(color: Fg.ink, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          if (onEdit != null)
            InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 14, color: Fg.matcha),
                    const SizedBox(width: 4),
                    Text('Edit',
                        style: TextStyle(color: Fg.matcha, fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommunityMenu(BuildContext context, String uid) {
    return ProfileSocialMenu(
      cardColor: Bg.surface,
      borderColor: Bg.hairline,
    );
  }

  Widget _buildAccountDetails(Map<String, dynamic> data) {
    return Container(
      decoration: BoxDecoration(color: Bg.surface, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          _DetailRow(label: 'Full name', value: _v(data['name'])),
          _DetailRow(label: 'Username', value: _v(data['username'])),
          _DetailRow(label: 'Bio', value: _v(data['bio'])),
          _DetailRow(label: 'Phone', value: _v(data['phone'])),
          _DetailRow(label: 'Location', value: _v(data['location']), isLast: true),
        ],
      ),
    );
  }

  Widget _buildFarmDetails(Map<String, dynamic> data) {
    return Container(
      decoration: BoxDecoration(color: Bg.surface, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          _DetailRow(label: 'Farm name', value: _v(data['farmName'])),
          _DetailRow(label: 'Farm type', value: _v(data['farmerType'])),
          _DetailRow(label: 'Animals kept', value: _v(data['animalsKept'])),
          _DetailRow(label: 'Water source', value: _v(data['waterSource'])),
          _DetailRow(label: 'Soil type', value: _v(data['soilType'])),
          _DetailRow(label: 'Years farming', value: _v(data['yearsFarming']), isLast: true),
        ],
      ),
    );
  }

  /// Settings lives on the page (it used to be a gear in the header corner
  /// that did nothing when tapped).
  Widget _buildSettingsTile(BuildContext context) {
    return Material(
      color: Bg.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(Icons.settings_outlined, size: 20, color: Fg.matcha),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Settings', style: TextStyle(fontSize: 14, color: Fg.ink)),
                    const SizedBox(height: 2),
                    Text('Language, dark mode, notifications, account',
                        style: TextStyle(fontSize: 11.5, color: Fg.inkSoft)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: Fg.inkSoft),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _logout,
        icon: Icon(Icons.logout, size: 16, color: Fg.rust),
        label: Text('Log out', style: TextStyle(color: Fg.rust, fontWeight: FontWeight.w500)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Bg.almondDeep, width: 0.8),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: Bg.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: Fg.ink, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Fg.inkSoft, fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.isLast = false});

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Bg.hairline, width: 0.6)),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: Fg.inkSoft, fontSize: 12)),
          const Spacer(),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(color: Fg.ink, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
class _EditField {
  const _EditField(this.key, this.label, this.initial,
      {this.maxLines = 1, this.keyboard, this.options, this.isList = false});

  final String key;
  final String label;
  final Object? initial;
  final int maxLines;
  final TextInputType? keyboard;
  final List<String>? options; // a fixed choice instead of free text
  final bool isList; // saved as a list (comma separated in the box)
}

/// Bottom sheet that edits a few profile fields and saves them together.
class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.uid, required this.title, required this.fields});

  final String uid;
  final String title;
  final List<_EditField> fields;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final Map<String, TextEditingController> _text = {
    for (final f in widget.fields)
      if (f.options == null) f.key: TextEditingController(text: f.initial?.toString() ?? ''),
  };
  late final Map<String, String?> _choice = {
    for (final f in widget.fields)
      if (f.options != null)
        f.key: f.options!.contains(f.initial) ? f.initial as String : null,
  };
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final update = <String, dynamic>{};
    for (final f in widget.fields) {
      if (f.options != null) {
        if (_choice[f.key] != null) update[f.key] = _choice[f.key];
      } else if (f.isList) {
        update[f.key] = _text[f.key]!
            .text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      } else {
        update[f.key] = _text[f.key]!.text.trim();
      }
    }
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .set(update, SetOptions(merge: true));
      if ((update['name'] as String?)?.isNotEmpty == true) {
        await FirebaseAuth.instance.currentUser?.updateDisplayName(update['name'] as String);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Profile save failed: $e');
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Check your connection and try again.')),
        );
      }
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Fg.inkSoft, fontSize: 13),
        filled: true,
        fillColor: Bg.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Bg.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Bg.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Bg.matcha, width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(widget.title,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Fg.ink)),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Fg.inkSoft),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final f in widget.fields) ...[
                if (f.options != null)
                  DropdownButtonFormField<String>(
                    value: _choice[f.key],
                    decoration: _decoration(f.label),
                    dropdownColor: Bg.surface,
                    style: TextStyle(color: Fg.ink, fontSize: 14),
                    items: [
                      for (final o in f.options!)
                        DropdownMenuItem(
                          value: o,
                          child: Text(o[0].toUpperCase() + o.substring(1)),
                        ),
                    ],
                    onChanged: (v) => setState(() => _choice[f.key] = v),
                  )
                else
                  TextField(
                    controller: _text[f.key],
                    maxLines: f.maxLines,
                    keyboardType: f.keyboard,
                    style: TextStyle(color: Fg.ink, fontSize: 14),
                    decoration: _decoration(f.label),
                  ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 4),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Bg.rust,
                  foregroundColor: Fg.almond,
                  disabledBackgroundColor: Bg.rust.withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _saving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Fg.almond),
                      )
                    : const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
