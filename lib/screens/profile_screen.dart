import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_screen.dart';
import 'profile_social_menu.dart';

/// AgroLens palette — matcha green / almond / white, light module variant.
class _C {
  static const matchaDark = Color(0xFF374530);
  static const matcha = Color(0xFF5C7148);
  static const matchaLight = Color(0xFFD6E0C4);
  static const almond = Color(0xFFF6EFE2);
  static const almondDeep = Color(0xFFE8DCC6);
  static const ink = Color(0xFF2B2820);
  static const inkSoft = Color(0xFF726C5C);
  static const rust = Color(0xFFC1703E);
  static const hairline = Color(0xFFEDE6D6);
  static const muted = Color(0xFFB8AE97);
}

/// Bottom wave that finishes off the dark matcha header band.
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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;

  Future<void> _logout() async {
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
      backgroundColor: _C.almond,
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
      clipper: _HeaderWaveClipper(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
        color: _C.matchaDark,
        child: Column(
          children: [
            Row(
              children: [
                Text('Profile',
                    style: TextStyle(color: _C.matchaLight, fontSize: 13, fontWeight: FontWeight.w500)),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.settings_outlined, color: _C.matchaLight, size: 20),
                  onPressed: () {
                    // TODO: navigate to settings screen
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: _C.rust,
                  backgroundImage:
                      (data['photoUrl'] as String?)?.isNotEmpty == true ? NetworkImage(data['photoUrl']) : null,
                  child: (data['photoUrl'] as String?)?.isNotEmpty == true
                      ? null
                      : Text(initials,
                          style: const TextStyle(color: _C.almond, fontSize: 24, fontWeight: FontWeight.w600)),
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
                        color: _C.almond,
                        shape: BoxShape.circle,
                        border: Border.all(color: _C.matchaDark, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_outlined, size: 13, color: _C.matchaDark),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(name, style: const TextStyle(color: _C.almond, fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on_outlined, size: 13, color: _C.matchaLight),
                const SizedBox(width: 4),
                Text(location, style: TextStyle(color: _C.matchaLight, fontSize: 12)),
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
                    Icon(Icons.verified_outlined, size: 13, color: _C.matchaLight),
                    const SizedBox(width: 4),
                    Text('Verified farmer',
                        style: TextStyle(color: _C.matchaLight, fontSize: 11, fontWeight: FontWeight.w500)),
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
            child: Text(text, style: const TextStyle(color: _C.ink, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          if (editable) Icon(Icons.edit_outlined, size: 14, color: _C.matcha),
        ],
      ),
    );
  }

  Widget _buildCommunityMenu(BuildContext context, String uid) {
    return const ProfileSocialMenu(
      cardColor: Colors.white,
      borderColor: _C.hairline,
    );
  }

  Widget _buildAccountDetails(Map<String, dynamic> data) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
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

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout, size: 16, color: _C.rust),
        label: const Text('Log out', style: TextStyle(color: _C.rust, fontWeight: FontWeight.w500)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _C.almondDeep, width: 0.8),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: _C.ink, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: _C.inkSoft, fontSize: 10.5)),
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
        border: isLast ? null : const Border(bottom: BorderSide(color: _C.hairline, width: 0.6)),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: _C.inkSoft, fontSize: 12)),
          const Spacer(),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: _C.ink, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}