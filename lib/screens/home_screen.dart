import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _user = FirebaseAuth.instance.currentUser;

  String _selectedCategory = 'all';
  late Stream<QuerySnapshot> _stream;

  final List<_Category> _categories = const [
    _Category(id: 'all', label: 'All', icon: Icons.article_outlined),
    _Category(id: 'alert', label: 'Alerts', icon: Icons.warning_amber_rounded),
    _Category(id: 'livestock', label: 'Livestock', icon: Icons.pets_rounded),
    _Category(id: 'crop', label: 'Crops', icon: Icons.eco_rounded),
    _Category(id: 'weather', label: 'Weather', icon: Icons.cloud_outlined),
    _Category(id: 'policy', label: 'Policy', icon: Icons.policy_outlined),
  ];

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Goodmorning';
    if (hour < 17) return 'Hello';
    return 'Yesterday';
  }

  String get _firstName {
    final name = _user?.displayName ?? 'Farmer';
    return name.split(' ').first;
  }

  @override
  void initState() {
    super.initState();
    _stream = _buildQuery('all').snapshots();
  }

  Query<Map<String, dynamic>> _buildQuery(String category) {
    if (category == 'all') {
      return FirebaseFirestore.instance
          .collection('news')
          .orderBy('publishedAt', descending: true)
          .limit(50);
    }
    return FirebaseFirestore.instance
        .collection('news')
        .where('category', isEqualTo: category)
        .orderBy('publishedAt', descending: true)
        .limit(50);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Header: greeting + category chip
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.greenDark,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 16,
                20,
                16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting
                  Text(
                    '$_greeting, $_firstName',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.greenHint,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Explore what’s new and what’s next",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category filter chips
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final cat = _categories[i];
                        final selected = _selectedCategory == cat.id;
                        return GestureDetector(
                          onTap: () => setState(() {
                            _selectedCategory = cat.id;
                            _stream = _buildQuery(cat.id).snapshots();
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  cat.icon,
                                  size: 14,
                                  color: selected
                                      ? AppColors.greenDark
                                      : Colors.white,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  cat.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: selected
                                        ? AppColors.greenDark
                                        : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // News stream
          StreamBuilder<QuerySnapshot>(
            stream: _stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.greenDark),
                  ),
                );
              }

              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: _ErrorView(error: snapshot.error.toString()),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const SliverFillRemaining(
                  child: _EmptyView(),
                );
              }

              // Pin alerts to top
              final alerts = docs
                  .where((d) =>
                      (d.data() as Map<String, dynamic>)['category'] ==
                      'alert')
                  .toList();
              final rest = docs
                  .where((d) =>
                      (d.data() as Map<String, dynamic>)['category'] !=
                      'alert')
                  .toList();
              final sorted = [...alerts, ...rest];

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    if (i == sorted.length) {
                      return const _SourcesFooter();
                    }
                    final data =
                        sorted[i].data() as Map<String, dynamic>;
                    final isAlert = data['category'] == 'alert';

                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                          16, i == 0 ? 16 : 0, 16, 10),
                      child: isAlert
                          ? _AlertCard(data: data)
                          : _NewsCard(data: data),
                    );
                  },
                  childCount: sorted.length + 1,
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

// Alert card

class _AlertCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AlertCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openUrl(data['url']),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.red.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: AppColors.red.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                color: AppColors.redLight,
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppRadius.card)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 14, color: AppColors.red),
                  const SizedBox(width: 6),
                  const Text(
                    'DISEASE ALERT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.red,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  _SourceBadge(
                      source: data['source'] ?? '',
                      color: AppColors.red),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['title'] ?? '',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  if ((data['summary'] ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      data['summary'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        _timeAgo(data['publishedAt']),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Read more →',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Standard news card 

class _NewsCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _NewsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final category = data['category'] ?? 'crop';
    final catStyle = _categoryStyle(category);

    return GestureDetector(
      onTap: () => _openUrl(data['url']),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: catStyle.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(catStyle.icon,
                    color: catStyle.color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _SourceBadge(
                            source: data['source'] ?? '',
                            color: catStyle.color),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: catStyle.bg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            catStyle.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: catStyle.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data['title'] ?? '',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _timeAgo(data['publishedAt']),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Source badge 
class _SourceBadge extends StatelessWidget {
  final String source;
  final Color color;
  const _SourceBadge({required this.source, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      source.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.4,
      ),
    );
  }
}

// Sources footer
class _SourcesFooter extends StatelessWidget {
  const _SourcesFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background2,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'NEWS SOURCES',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                'FAO',
                'WOAH',
                'ReliefWeb',
                'AllAfrica',
                'CGIAR',
                'Botswana Daily News',
                "Farmer's Weekly",
                'SABC News',
              ]
                  .map((s) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          s,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            const Text(
              'Updated every 30 minutes. Tap any article to read the full story.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Empty + error states 
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.newspaper_outlined,
              size: 48,
              color: AppColors.textSecondary.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'No articles yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'News is fetched every 30 minutes.\nCheck back shortly.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text(
              'Could not load news',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helpers
String _timeAgo(dynamic ts) {
  if (ts == null) return '';
  final dt = (ts as Timestamp).toDate();
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('d MMM').format(dt);
}

Future<void> _openUrl(String? url) async {
  if (url == null || url.isEmpty) return;
  final uri = Uri.tryParse(url);
  if (uri != null && await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

_CategoryStyle _categoryStyle(String category) {
  switch (category) {
    case 'alert':
      return const _CategoryStyle(
        icon: Icons.warning_amber_rounded,
        color: AppColors.red,
        bg: AppColors.redLight,
        label: 'Alert',
      );
    case 'livestock':
      return const _CategoryStyle(
        icon: Icons.pets_rounded,
        color: AppColors.greenText,
        bg: AppColors.greenLight,
        label: 'Livestock',
      );
    case 'weather':
      return const _CategoryStyle(
        icon: Icons.cloud_outlined,
        color: Color(0xFF1565C0),
        bg: Color(0xFFE3F2FD),
        label: 'Weather',
      );
    case 'policy':
      return const _CategoryStyle(
        icon: Icons.policy_outlined,
        color: AppColors.amberText,
        bg: AppColors.amberLight,
        label: 'Policy',
      );
    default:
      return const _CategoryStyle(
        icon: Icons.eco_rounded,
        color: Color(0xFF3B6D11),
        bg: Color(0xFFEAF3DE),
        label: 'Crops',
      );
  }
}

// Models
class _Category {
  final String id;
  final String label;
  final IconData icon;
  const _Category(
      {required this.id, required this.label, required this.icon});
}

class _CategoryStyle {
  final IconData icon;
  final Color color;
  final Color bg;
  final String label;
  const _CategoryStyle({
    required this.icon,
    required this.color,
    required this.bg,
    required this.label,
  });
}