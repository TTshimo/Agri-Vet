import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

// Self-contained palette for the redesign — matcha green / almond / rust.
// Not pulled from main.dart's AppColors so this file renders correctly
// regardless of what that defines. Fold these into AppColors later if you
// want the palette shared app-wide.
class _C {
  static const matchaDark = Color(0xFF374530);
  static const matcha = Color(0xFF5C7148);
  static const matchaTint = Color(0xFFD6E0C4);
  static const almond = Color(0xFFF6EFE2);
  static const ink = Color(0xFF2B2820);
  static const inkSoft = Color(0xFF726C5C);
  static const rust = Color(0xFFC1703E);
}

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
        // Articles can carry several tags (an outbreak story is both
        // 'alert' and 'livestock'), so filter on the full list.
        .where('categories', arrayContains: category)
        .orderBy('publishedAt', descending: true)
        .limit(50);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.almond,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _FieldWavesPainter()),
          ),
          CustomScrollView(
            slivers: [
              // Header: greeting + category chips
              SliverToBoxAdapter(
                child: Container(
                  color: _C.matchaDark,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    MediaQuery.of(context).padding.top + 16,
                    20,
                    16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_greeting, $_firstName',
                        style: TextStyle(
                          fontSize: 13,
                          color: _C.matchaTint,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Explore what's new and what's next",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: _C.almond,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
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
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? _C.almond
                                      : Colors.white.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(999),
                                  border: selected
                                      ? null
                                      : Border.all(
                                          color:
                                              Colors.white.withOpacity(0.35),
                                          width: 0.7,
                                        ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      cat.icon,
                                      size: 14,
                                      color: selected
                                          ? _C.matchaDark
                                          : _C.almond,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      cat.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: selected
                                            ? _C.matchaDark
                                            : _C.almond,
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

              StreamBuilder<QuerySnapshot>(
                stream: _stream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(color: _C.matcha),
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
                    return const SliverFillRemaining(child: _EmptyView());
                  }

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
                        final data = sorted[i].data() as Map<String, dynamic>;
                        final isAlert = data['category'] == 'alert';

                        return Padding(
                          padding:
                              EdgeInsets.fromLTRB(16, i == 0 ? 16 : 0, 16, 10),
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
        ],
      ),
    );
  }
}

/// Layered soft rolling-field horizon behind the content — a subtle top
/// curve and a subtle bottom curve, both single flat-color washes.
class _FieldWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _C.matchaTint.withOpacity(0.5);

    final top = Path()
      ..moveTo(0, size.height * 0.22)
      ..cubicTo(
        size.width * 0.19, size.height * 0.15,
        size.width * 0.42, size.height * 0.25,
        size.width * 0.61, size.height * 0.18,
      )
      ..cubicTo(
        size.width * 0.78, size.height * 0.12,
        size.width * 0.92, size.height * 0.16,
        size.width, size.height * 0.14,
      )
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(top, paint);

    final bottom = Path()
      ..moveTo(0, size.height * 0.82)
      ..cubicTo(
        size.width * 0.17, size.height * 0.76,
        size.width * 0.36, size.height * 0.86,
        size.width * 0.56, size.height * 0.79,
      )
      ..cubicTo(
        size.width * 0.72, size.height * 0.74,
        size.width * 0.86, size.height * 0.78,
        size.width, size.height * 0.76,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(bottom, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Frosted glass surface with a glossy highlight band across the top.
/// Needs the field waves (or any texture) behind it to actually read as
/// glass — over a flat color it just looks like a tint.
class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.borderColor});

  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.85),
              width: 0.8,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: FractionallySizedBox(
                  heightFactor: 0.46,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color.fromRGBO(255, 255, 255, 0.4),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AlertCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openUrl(data['url']),
      child: _GlassCard(
        borderColor: _C.rust.withOpacity(0.45),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 14, color: _C.rust),
                  const SizedBox(width: 6),
                  Text(
                    'Disease alert',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _C.rust,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _timeAgo(data['publishedAt']),
                    style: TextStyle(fontSize: 11, color: _C.inkSoft),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                data['title'] ?? '',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _C.ink,
                  height: 1.4,
                ),
              ),
              if ((data['summary'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  data['summary'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: _C.inkSoft,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SourceBadge(source: data['source'] ?? '', color: _C.rust),
                  Text(
                    'Read more →',
                    style: TextStyle(
                      fontSize: 12,
                      color: _C.rust,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _NewsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final category = data['category'] ?? 'crop';
    final catStyle = _categoryStyle(category);

    return GestureDetector(
      onTap: () => _openUrl(data['url']),
      child: _GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: catStyle.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(catStyle.icon, color: catStyle.color, size: 22),
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
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: catStyle.color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(999),
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
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: _C.ink,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _timeAgo(data['publishedAt']),
                      style: TextStyle(fontSize: 11, color: _C.inkSoft),
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

class _SourcesFooter extends StatelessWidget {
  const _SourcesFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: _GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'News sources',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _C.inkSoft,
                  letterSpacing: 0.4,
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
                            color: Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.8),
                                width: 0.6),
                          ),
                          child: Text(
                            s,
                            style: TextStyle(fontSize: 11, color: _C.inkSoft),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              Text(
                'Updated every 30 minutes. Tap any article to read the full story.',
                style: TextStyle(fontSize: 11, color: _C.inkSoft, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
              color: _C.inkSoft.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No articles yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _C.inkSoft,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'News is fetched every 30 minutes.\nCheck back shortly.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _C.inkSoft, height: 1.5),
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
            Icon(Icons.wifi_off_rounded, size: 48, color: _C.inkSoft),
            const SizedBox(height: 16),
            Text(
              'Could not load news',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _C.inkSoft,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: _C.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

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
        color: _C.rust,
        label: 'Alert',
      );
    case 'livestock':
      return const _CategoryStyle(
        icon: Icons.pets_rounded,
        color: _C.rust,
        label: 'Livestock',
      );
    case 'weather':
      return const _CategoryStyle(
        icon: Icons.cloud_outlined,
        color: _C.matcha,
        label: 'Weather',
      );
    case 'policy':
      return const _CategoryStyle(
        icon: Icons.policy_outlined,
        color: _C.matcha,
        label: 'Policy',
      );
    default:
      return const _CategoryStyle(
        icon: Icons.eco_rounded,
        color: _C.matcha,
        label: 'Crops',
      );
  }
}

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
  final String label;
  const _CategoryStyle(
      {required this.icon, required this.color, required this.label});
}