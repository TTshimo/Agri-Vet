import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_screen.dart';
import '../services/google_auth.dart';
import '../services/notification_service.dart';
import 'profile_social_menu.dart';
import 'settings_screen.dart';
import '../theme/palette.dart';
import '../theme/header_wave.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

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
    return Scaffold(
      backgroundColor: Bg.almond,
      body: uid == null
          ? const Center(child: Text('Not signed in'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() ?? const <String, dynamic>{};
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildHeader(context, data),
                      Transform.translate(
                        offset: const Offset(0, -34),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                          child: Column(
                            children: [
                              _buildStatsRow(uid),
                              const SizedBox(height: 18),
                              _buildSectionLabel('Community'),
                              _buildCommunityMenu(context, uid),
                              const SizedBox(height: 18),
                              _buildSectionLabel('Account details', editable: true),
                              _buildAccountDetails(data),
                              const SizedBox(height: 18),
                              _buildSectionLabel('Farm details', editable: true),
                              _buildFarmDetails(data),
                              const SizedBox(height: 18),
                              _buildSectionLabel('App'),
                              _buildSettingsTile(context),
                              const SizedBox(height: 22),
                              _buildLogoutButton(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, dynamic> data) {
    final name = (data['name'] as String?)?.trim().isNotEmpty == true
        ? data['name'] as String
        : 'Your name';
    final location = (data['location'] as String?)?.trim().isNotEmpty == true
        ? data['location'] as String
        : 'Add your location';
    final verified = data['verified'] == true;
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((s) => s[0]).join().toUpperCase();

    return ClipPath(
      clipper: const HeaderWaveClipper(),
      child: Container(
        width: double.infinity,
        // Clear of the status bar on top; clear of the wave at the bottom.
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 72),
        color: Bg.matchaDark,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Profile',
                  style: TextStyle(color: Fg.matchaLight, fontSize: 13, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 8),
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: Bg.rust,
                  backgroundImage:
                      (data['photoUrl'] as String?)?.isNotEmpty == true ? NetworkImage(data['photoUrl']) : null,
                  child: (data['photoUrl'] as String?)?.isNotEmpty == true
                      ? null
                      : Text(initials,
                          style: TextStyle(color: Fg.almond, fontSize: 24, fontWeight: FontWeight.w600)),
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: GestureDetector(
                    onTap: () {
                      // TODO: hook up image picker + upload
                    },
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Bg.almond,
                        shape: BoxShape.circle,
                        border: Border.all(color: Bg.matchaDark, width: 2),
                      ),
                      child: Icon(Icons.camera_alt_outlined, size: 13, color: Fg.matchaDark),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(name, style: TextStyle(color: Fg.almond, fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on_outlined, size: 13, color: Fg.matchaLight),
                const SizedBox(width: 4),
                Text(location, style: TextStyle(color: Fg.matchaLight, fontSize: 12)),
              ],
            ),
            if (verified) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_outlined, size: 13, color: Fg.matchaLight),
                    const SizedBox(width: 4),
                    Text('Verified farmer',
                        style: TextStyle(color: Fg.matchaLight, fontSize: 11, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
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
              final createdAt = snap.data?.data()?['createdAt'] as Timestamp?;
              final label = createdAt == null
                  ? '—'
                  : _monthsSince(createdAt.toDate());
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

  Widget _buildSectionLabel(String text, {bool editable = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: TextStyle(color: Fg.ink, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          if (editable) Icon(Icons.edit_outlined, size: 14, color: Fg.matcha),
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
          _DetailRow(label: 'Full name', value: data['name'] as String? ?? '—'),
          _DetailRow(label: 'Username', value: data['username'] as String? ?? '—'),
          _DetailRow(label: 'Bio', value: data['bio'] as String? ?? '—'),
          _DetailRow(label: 'Phone', value: data['phone'] as String? ?? '—'),
          _DetailRow(label: 'Location', value: data['location'] as String? ?? '—', isLast: true),
        ],
      ),
    );
  }

  Widget _buildFarmDetails(Map<String, dynamic> data) {
    final animals = (data['animalsKept'] as List?)?.join(', ');
    return Container(
      decoration: BoxDecoration(color: Bg.surface, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          _DetailRow(label: 'Farm name', value: data['farmName'] as String? ?? '—'),
          _DetailRow(label: 'Farm type', value: data['farmerType'] as String? ?? '—'),
          _DetailRow(label: 'Animals kept', value: (animals?.isNotEmpty ?? false) ? animals! : '—'),
          _DetailRow(label: 'Water source', value: data['waterSource'] as String? ?? '—'),
          _DetailRow(label: 'Soil type', value: data['soilType'] as String? ?? '—'),
          _DetailRow(label: 'Years farming', value: data['yearsFarming'] as String? ?? '—', isLast: true),
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