import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../theme/palette.dart';
import '../theme/header_wave.dart';
import '../widgets/field_background.dart';


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
                      _title,
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
                    child: CircularProgressIndicator(color: Fg.matcha),
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
                            color: Bg.matchaLight.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            type == ActivityType.posts
                                ? Icons.article_outlined
                                : Icons.biotech_outlined,
                            size: 26,
                            color: Fg.matcha.withOpacity(0.7),
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
                              color: Fg.ink),
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
      )),
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
        color: Bg.surface,
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
                    color: Fg.ink),
              ),
            ),
            Text(dateStr, style: TextStyle(fontSize: 11, color: Fg.inkSoft)),
          ]),
          if ((data['body'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              data['body'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: Fg.inkSoft),
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
                          color: Bg.matchaLight.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(t,
                            style: TextStyle(
                                fontSize: 11, color: Fg.matchaDark)),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.thumb_up_outlined, size: 14, color: Fg.inkSoft),
            const SizedBox(width: 4),
            Text('${data['likes'] ?? 0}',
                style: TextStyle(fontSize: 12, color: Fg.inkSoft)),
            const SizedBox(width: 14),
            Icon(Icons.comment_outlined, size: 14, color: Fg.inkSoft),
            const SizedBox(width: 4),
            Text('${data['commentCount'] ?? 0}',
                style: TextStyle(fontSize: 12, color: Fg.inkSoft)),
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
        color: Bg.surface,
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
                    color: Fg.ink),
              ),
            ),
            Text(dateStr, style: TextStyle(fontSize: 11, color: Fg.inkSoft)),
          ]),
          const SizedBox(height: 6),
          Text(
            data['prediction'] ?? 'No result',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500, color: Fg.matcha),
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
                style: TextStyle(fontSize: 11, color: Fg.inkSoft)),
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
        return Bg.rust;
      default:
        return Bg.matcha;
    }
  }
}