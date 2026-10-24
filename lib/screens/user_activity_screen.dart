import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// AgroLens palette — matcha green / almond / white, light module variant.
class _C {
  static const matchaDark = Color(0xFF374530);
  static const matcha = Color(0xFF5C7148);
  static const matchaLight = Color(0xFFD6E0C4);
  static const almond = Color(0xFFF6EFE2);
  static const ink = Color(0xFF2B2820);
  static const inkSoft = Color(0xFF726C5C);
  static const rust = Color(0xFFC1703E);
  static const hairline = Color(0xFFEDE6D6);
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

enum ActivityType { posts, diagnoses }

class UserActivityScreen extends StatelessWidget {
  final String uid;
  final ActivityType type;

  const UserActivityScreen({
    super.key,
    required this.uid,
    required this.type,
  });

  String get _collection =>
      type == ActivityType.posts ? 'posts' : 'diagnoses';

  String get _title =>
      type == ActivityType.posts ? 'My posts' : 'My diagnoses';

  @override
  Widget build(BuildContext context) {
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
                      _title,
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
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection(_collection)
                .where('uid', isEqualTo: uid)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: _C.matcha),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: _C.matchaLight.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            type == ActivityType.posts
                                ? Icons.article_outlined
                                : Icons.biotech_outlined,
                            size: 26,
                            color: _C.matcha.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          type == ActivityType.posts
                              ? 'No posts yet'
                              : 'No diagnoses yet',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: _C.ink),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final d = docs[i].data() as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: type == ActivityType.posts
                            ? _PostCard(data: d)
                            : _DiagnosisCard(data: d),
                      );
                    },
                    childCount: docs.length,
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PostCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final ts = (data['createdAt'] as Timestamp?)?.toDate();
    final dateStr = ts != null ? DateFormat('d MMM yyyy').format(ts) : '';
    final tags = List<String>.from(data['tags'] ?? []);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                data['title'] ?? 'Untitled',
                style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: _C.ink),
              ),
            ),
            Text(dateStr, style: TextStyle(fontSize: 11, color: _C.inkSoft)),
          ]),
          if ((data['body'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              data['body'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: _C.inkSoft),
            ),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: tags
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _C.matchaLight.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(t,
                            style: TextStyle(
                                fontSize: 11, color: _C.matchaDark)),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.thumb_up_outlined, size: 14, color: _C.inkSoft),
            const SizedBox(width: 4),
            Text('${data['likes'] ?? 0}',
                style: TextStyle(fontSize: 12, color: _C.inkSoft)),
            const SizedBox(width: 14),
            Icon(Icons.comment_outlined, size: 14, color: _C.inkSoft),
            const SizedBox(width: 4),
            Text('${data['commentCount'] ?? 0}',
                style: TextStyle(fontSize: 12, color: _C.inkSoft)),
          ]),
        ],
      ),
    );
  }
}

class _DiagnosisCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DiagnosisCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final ts = (data['createdAt'] as Timestamp?)?.toDate();
    final dateStr = ts != null ? DateFormat('d MMM yyyy').format(ts) : '';
    final confidence = ((data['confidence'] ?? 0.0) * 100).round();
    final severityColor = _severityColor(data['severity'] ?? '');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                data['animalType'] ?? 'Unknown animal',
                style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: _C.ink),
              ),
            ),
            Text(dateStr, style: TextStyle(fontSize: 11, color: _C.inkSoft)),
          ]),
          const SizedBox(height: 6),
          Text(
            data['prediction'] ?? 'No result',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500, color: _C.matcha),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: severityColor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                data['severity'] ?? 'Unknown',
                style: TextStyle(
                    fontSize: 11,
                    color: severityColor,
                    fontWeight: FontWeight.w500),
              ),
            ),
            const Spacer(),
            Text('$confidence% confidence',
                style: TextStyle(fontSize: 11, color: _C.inkSoft)),
          ]),
        ],
      ),
    );
  }

  // Simplified to the app's two-tone risk system: high severity reads as
  // rust (urgent), everything else reads as matcha (calm/informational).
  Color _severityColor(String s) {
    switch (s.toLowerCase()) {
      case 'high':
        return _C.rust;
      default:
        return _C.matcha;
    }
  }
}