import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../main.dart';

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
      type == ActivityType.posts ? 'My Posts' : 'My Diagnoses';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.greenDark,
        foregroundColor: Colors.white,
        title: Text(_title),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(_collection)
            .where('userId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: AppColors.greenDark));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    type == ActivityType.posts
                        ? Icons.article_outlined
                        : Icons.biotech_outlined,
                    size: 48,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    type == ActivityType.posts
                        ? 'No posts yet'
                        : 'No diagnoses yet',
                    style: const TextStyle(
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              return type == ActivityType.posts
                  ? _PostCard(data: d)
                  : _DiagnosisCard(data: d);
            },
          );
        },
      ),
    );
  }
}

// ── Post card ─────────────────────────────────────────────────────────────────
class _PostCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PostCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ts = (data['createdAt'] as Timestamp?)?.toDate();
    final dateStr = ts != null
        ? DateFormat('d MMM yyyy').format(ts)
        : '';
    final tags = List<String>.from(data['tags'] ?? []);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: isDark
                ? const Color(0xFF2C2C2C)
                : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                data['title'] ?? 'Untitled',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
            ),
            Text(dateStr,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ]),
          if ((data['body'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              data['body'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
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
                          color: AppColors.greenDark.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(t,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.greenDark)),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.thumb_up_outlined,
                size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text('${data['likes'] ?? 0}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(width: 14),
            const Icon(Icons.comment_outlined,
                size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text('${data['commentCount'] ?? 0}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ],
      ),
    );
  }
}

// ── Diagnosis card ────────────────────────────────────────────────────────────
class _DiagnosisCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DiagnosisCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ts = (data['createdAt'] as Timestamp?)?.toDate();
    final dateStr = ts != null
        ? DateFormat('d MMM yyyy').format(ts)
        : '';
    final confidence = ((data['confidence'] ?? 0.0) * 100).round();
    final severityColor = _severityColor(data['severity'] ?? '');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: isDark
                ? const Color(0xFF2C2C2C)
                : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                data['animalType'] ?? 'Unknown animal',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
            ),
            Text(dateStr,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ]),
          const SizedBox(height: 6),
          Text(
            data['prediction'] ?? 'No result',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.greenDark),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: severityColor.withOpacity(0.12),
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
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ],
      ),
    );
  }

  Color _severityColor(String s) {
    switch (s.toLowerCase()) {
      case 'high':   return const Color(0xFFD32F2F);
      case 'medium': return const Color(0xFFF57C00);
      default:      return const Color(0xFF2E7D32);
    }
  }
}
