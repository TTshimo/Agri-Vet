import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../main.dart';
import 'settings_screen.dart';
import 'user_activity_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF2C2C2C)
        : AppColors.border;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          final data =
              snapshot.data?.data() as Map<String, dynamic>? ?? {};

          final name         = data['name']         ?? 'Farmer';
          final username     = data['username']     ?? '';
          final bio          = data['bio']          ?? '';
          final phone        = data['phone']        ?? '';
          final location     = data['location']     ?? '';
          final farmName     = data['farmName']     ?? '';
          final farmType     = data['farmType']     ?? '';
          final farmSize     = data['farmSize']     ?? '';
          final animalsKept  = data['animalsKept']  ?? '';
          final animalCount  = data['animalCount']  ?? '';
          final waterSource  = data['waterSource']  ?? '';
          final soilType     = data['soilType']     ?? '';
          final yearsFarming = data['yearsFarming'] ?? '';
          final photoUrl     = data['photoUrl']     ?? '';
          final diagnosisCount = data['diagnosisCount'] ?? 0;
          final postCount      = data['postCount']     ?? 0;

          final initials = name
              .trim()
              .split(' ')
              .where((String p) => p.isNotEmpty)
              .take(2)
              .map((String p) => p[0].toUpperCase())
              .join();

          return CustomScrollView(
            slivers: [
              // ── Banner ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.greenDark,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    MediaQuery.of(context).padding.top + 20,
                    20,
                    28,
                  ),
                  child: Column(
                    children: [
                      // Avatar with camera tap
                      GestureDetector(
                        onTap: () => _pickPhoto(context, uid),
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 42,
                              backgroundColor: AppColors.greenMid,
                              backgroundImage: photoUrl.isNotEmpty
                                  ? NetworkImage(photoUrl)
                                  : null,
                              child: photoUrl.isEmpty
                                  ? Text(
                                      initials,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0, right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.amber,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt,
                                    size: 14, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(name,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      if (username.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('@$username',
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.greenHint)),
                      ],
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.location_on_outlined,
                              size: 13, color: AppColors.greenHint),
                          const SizedBox(width: 3),
                          Text(location,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.greenHint)),
                        ]),
                      ],
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(bio,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.greenHint)),
                      ],
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.amber,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Verified Farmer',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Stats (tappable) ──────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      _StatBox(
                        label: 'Diagnoses',
                        value: '$diagnosisCount',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => UserActivityScreen(
                              uid: uid,
                              type: ActivityType.diagnoses,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _StatBox(
                        label: 'Posts',
                        value: '$postCount',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => UserActivityScreen(
                              uid: uid,
                              type: ActivityType.posts,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const _StatBox(label: 'Member', value: 'Active'),
                    ],
                  ),
                ),
              ),

              // ── User details section ──────────────────────────────
              _sectionHeader('ACCOUNT DETAILS'),
              SliverToBoxAdapter(
                child: _card(
                  context,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  rows: [
                    _FieldData('Full name',  name,     'name'),
                    _FieldData('Username',   username, 'username'),
                    _FieldData('Bio',        bio,      'bio',      multiline: true),
                    _FieldData('Phone',      phone,    'phone',    isPhone: true),
                    _FieldData('Location',   location, 'location', isLast: true),
                  ],
                  uid: uid,
                ),
              ),

              // ── Farm details section ──────────────────────────────
              _sectionHeader('FARM DETAILS'),
              SliverToBoxAdapter(
                child: _card(
                  context,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  rows: [
                    _FieldData('Farm name',           farmName,     'farmName'),
                    _FieldData('Farm type',           farmType,     'farmType',
                        hint: 'e.g. Livestock / Crop / Mixed'),
                    _FieldData('Farm size (ha)',       farmSize,     'farmSize',
                        isNumeric: true),
                    _FieldData('Animals kept',        animalsKept,  'animalsKept',
                        hint: 'e.g. Cattle, Goats, Poultry'),
                    _FieldData('No. of animals',      animalCount,  'animalCount',
                        isNumeric: true),
                    _FieldData('Water source',        waterSource,  'waterSource',
                        hint: 'e.g. Borehole, Dam, River'),
                    _FieldData('Soil type',           soilType,     'soilType',
                        hint: 'e.g. Sandy, Clay, Loam'),
                    _FieldData('Years farming',       yearsFarming, 'yearsFarming',
                        isNumeric: true, isLast: true),
                  ],
                  uid: uid,
                ),
              ),

              // ── Settings button ───────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius:
                            BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: borderColor),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.settings_outlined,
                              size: 20,
                              color: AppColors.textSecondary),
                          SizedBox(width: 12),
                          Text('Settings',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary)),
                          Spacer(),
                          Icon(Icons.chevron_right_rounded,
                              color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }

  // ── Section header helper ────────────────────────────────────────────────
  Widget _sectionHeader(String title) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.08 * 11)),
        ),
      );

  // ── Card builder ─────────────────────────────────────────────────────────
  Widget _card(
    BuildContext context, {
    required Color cardColor,
    required Color borderColor,
    required List<_FieldData> rows,
    required String uid,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: rows
              .asMap()
              .entries
              .map((e) => Column(
                    children: [
                      _ProfileRow(
                        label: e.value.label,
                        value: e.value.value.isEmpty
                            ? 'Not set'
                            : e.value.value,
                        onEdit: () => _editField(
                          context,
                          uid: uid,
                          field: e.value.field,
                          label: e.value.label,
                          current: e.value.value,
                          hint: e.value.hint,
                          multiline: e.value.multiline,
                          isNumeric: e.value.isNumeric,
                          isPhone: e.value.isPhone,
                        ),
                        isLast: e.value.isLast,
                      ),
                      if (!e.value.isLast)
                        Divider(height: 1, color: borderColor),
                    ],
                  ))
              .toList(),
        ),
      ),
    );
  }

  // ── Photo picker ─────────────────────────────────────────────────────────
  Future<void> _pickPhoto(BuildContext context, String uid) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 512,
    );
    if (picked == null) return;
    if (!context.mounted) return;

    try {
      final ref = FirebaseStorage.instance
          .ref('avatars/$uid.jpg');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'photoUrl': url});
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  // ── Edit dialog ──────────────────────────────────────────────────────────
  void _editField(
    BuildContext context, {
    required String uid,
    required String field,
    required String label,
    required String current,
    String? hint,
    bool multiline = false,
    bool isNumeric = false,
    bool isPhone = false,
  }) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit $label'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint ?? label),
          autofocus: true,
          maxLines: multiline ? 3 : 1,
          keyboardType: isNumeric
              ? TextInputType.number
              : isPhone
                  ? TextInputType.phone
                  : TextInputType.text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .update({field: controller.text.trim()});
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────
class _FieldData {
  final String label, value, field;
  final String? hint;
  final bool multiline, isNumeric, isPhone, isLast;
  const _FieldData(this.label, this.value, this.field, {
    this.hint, this.multiline = false,
    this.isNumeric = false, this.isPhone = false,
    this.isLast = false,
  });
}

// ── Stat box ──────────────────────────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  final String label, value;
  final VoidCallback? onTap;
  const _StatBox({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
                color: isDark
                    ? const Color(0xFF2C2C2C)
                    : AppColors.border),
          ),
          child: Column(children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.greenDark)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
            if (onTap != null) ...[
              const SizedBox(height: 3),
              const Text('View all',
                  style: TextStyle(
                      fontSize: 10, color: AppColors.greenDark)),
            ]
          ]),
        ),
      ),
    );
  }
}

// ── Profile row ───────────────────────────────────────────────────────────────
class _ProfileRow extends StatelessWidget {
  final String label, value;
  final VoidCallback onEdit;
  final bool isLast;
  const _ProfileRow({
    required this.label, required this.value,
    required this.onEdit, this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        GestureDetector(
          onTap: onEdit,
          child: const Icon(Icons.edit_outlined,
              size: 18, color: AppColors.textSecondary),
        ),
      ]),
    );
  }
}
