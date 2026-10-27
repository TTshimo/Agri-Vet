import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../theme/palette.dart';
import '../widgets/language_chip.dart';

/// Learn text in the language chosen in Settings (or the header chip);
/// English from disease_info.json when a translation is missing.
String _learn(BuildContext context, String disease, Map<String, dynamic> data, String field) =>
    context.watch<LanguageProvider>().t('learn.$disease.$field',
        fallback: (data[field] ?? (field == 'display_name' ? disease : '')).toString());

String _ui(BuildContext context, String key) =>
    context.watch<LanguageProvider>().t('ui.learn.$key');

// Self-contained palette for the redesign — matcha green / almond / rust.
// Matches the palette used in the redesigned home/news screen. Fold into
// a shared AppColors in main.dart later if you want it app-wide.
class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  Map<String, dynamic> _diseaseData = {};
  bool _loading = true;

  final List<String> _animalDiseases = [
    'foot and mouth',
    'lumpy cow disease',
    'goat pox',
    'salmonella',
    'coccidiosis',
    'african swine fever',
    'newcastle disease',
    'brucellosis',
    'anthrax',
    'blackleg',
    'heartwater',
  ];

  final List<String> _cropDiseases = [
    'watermelon mosaic virus',
    'sorghum cereal grain mold',
    'sorghum covered kernel smut',
    'potato late blight',
    'tomato late blight',
    'maize streak virus',
    'groundnut rosette',
    'cassava mosaic disease',
    'sorghum anthracnose',
  ];

  // Only list diseases that have an entry in disease_info.json; the rest
  // (e.g. salmonella, coccidiosis) appear as soon as their info is added.
  List<String> get _animalsWithInfo =>
      _animalDiseases.where(_diseaseData.containsKey).toList();
  List<String> get _cropsWithInfo =>
      _cropDiseases.where(_diseaseData.containsKey).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await rootBundle.loadString('assets/data/disease_info.json');
    setState(() {
      _diseaseData = json.decode(raw);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Bg.almond,
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: Fg.matcha),
            )
          : Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _BottomFieldWavePainter()),
                ),
                CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _WavyHeader(
                        height: MediaQuery.of(context).padding.top + 80, // same as Community
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            MediaQuery.of(context).padding.top + 20,
                            20,
                            0,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _ui(context, 'title'),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: Fg.almond,
                                ),
                              ),
                            ],
                          ),
                              ),
                              const SizedBox(width: 8),
                              // Language choice right here, same setting as Settings.
                              const LanguageChip(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          _ui(context, 'animal_diseases').toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Fg.inkSoft,
                            letterSpacing: 0.9,
                          ),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final key = _animalsWithInfo[i];
                          final data =
                              Map<String, dynamic>.from(_diseaseData[key] ?? {});
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                            child: _DiseaseCard(
                              diseaseKey: key,
                              data: data,
                              isAnimal: true,
                            ),
                          );
                        },
                        childCount: _animalsWithInfo.length,
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          _ui(context, 'crop_diseases').toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Fg.inkSoft,
                            letterSpacing: 0.9,
                          ),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final key = _cropsWithInfo[i];
                          final data =
                              Map<String, dynamic>.from(_diseaseData[key] ?? {});
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                            child: _DiseaseCard(
                              diseaseKey: key,
                              data: data,
                              isAnimal: false,
                            ),
                          );
                        },
                        childCount: _cropsWithInfo.length,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ],
            ),
    );
  }
}

/// Header with a soft wavy bottom edge instead of a hard rectangle, so it
/// blends into the field-wave background instead of sitting on top of it
/// as a flat UI bar.
class _WavyHeader extends StatelessWidget {
  const _WavyHeader({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipPath(
            clipper: _WavyHeaderClipper(),
            child: Container(color: Bg.matchaHeader.withOpacity(0.88)),
          ),
          child,
        ],
      ),
    );
  }
}

class _WavyHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.774)
      ..cubicTo(
        w * 0.806, h * 0.955,
        w * 0.639, h * 0.697,
        w * 0.458, h * 0.839,
      )
      ..cubicTo(
        w * 0.292, h * 0.968,
        w * 0.153, h * 0.903,
        0, h * 0.968,
      )
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Single soft horizon wash at the bottom of the screen.
class _BottomFieldWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Bg.matchaTint.withOpacity(0.5);
    final path = Path()
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
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Frosted glass surface with a glossy highlight band across the top.
/// [glossTint] lets the highlighted "what to do" section tint its gloss
/// warm (rust-bg) instead of plain white.
class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.borderColor,
    this.glossTint,
  });

  final Widget child;
  final Color? borderColor;
  final Color? glossTint;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: Bg.surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor ?? Bg.surface.withOpacity(0.85),
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
                    decoration: BoxDecoration(
                      color: (glossTint ?? Bg.surface).withOpacity(0.4),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18),
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

class _DiseaseCard extends StatelessWidget {
  final String diseaseKey;
  final Map<String, dynamic> data;
  final bool isAnimal;

  const _DiseaseCard({
    required this.diseaseKey,
    required this.data,
    required this.isAnimal,
  });

  bool get _highRisk => data['risk_level'] == 'high';
  Color get _riskColor => _highRisk ? Bg.rust : Bg.matcha;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _DiseaseDetailScreen(
            diseaseKey: diseaseKey,
            data: data,
            isAnimal: isAnimal,
          ),
        ),
      ),
      child: _GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _riskColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  isAnimal ? Icons.pets_rounded : Icons.eco_rounded,
                  size: 20,
                  color: _riskColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _learn(context, diseaseKey, data, 'display_name'),
                      style: TextStyle(
                        fontSize: 14,
                        color: Fg.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _learn(context, diseaseKey, data, 'symptoms'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Fg.inkSoft),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: Fg.inkSoft, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiseaseDetailScreen extends StatelessWidget {
  final String diseaseKey;
  final Map<String, dynamic> data;
  final bool isAnimal;

  const _DiseaseDetailScreen({
    required this.diseaseKey,
    required this.data,
    required this.isAnimal,
  });

  bool get _highRisk => data['risk_level'] == 'high';
  Color get _riskColor => _highRisk ? Bg.rust : Bg.matcha;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Bg.almond,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _BottomFieldWavePainter()),
          ),
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _WavyHeader(
                  height: MediaQuery.of(context).padding.top + 132,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      MediaQuery.of(context).padding.top + 20,
                      20,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: Fg.almond,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _learn(context, diseaseKey, data, 'display_name'),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Fg.almond,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _ui(context, isAnimal ? 'animal_disease' : 'crop_disease'),
                          style: TextStyle(fontSize: 12, color: Fg.matchaTint),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _DetailSection(
                      label: _ui(context, 'symptoms'),
                      content: _learn(context, diseaseKey, data, 'symptoms'),
                      icon: Icons.search_rounded,
                    ),
                    const SizedBox(height: 10),
                    _DetailSection(
                      label: _ui(context, 'affects'),
                      content: _learn(context, diseaseKey, data, 'affects'),
                      icon: Icons.pets_rounded,
                    ),
                    const SizedBox(height: 10),
                    _DetailSection(
                      label: _ui(context, 'spreads'),
                      content: _learn(context, diseaseKey, data, 'spreads_by'),
                      icon: Icons.share_outlined,
                    ),
                    const SizedBox(height: 10),
                    _DetailSection(
                      label: _ui(context, 'what_to_do'),
                      content: _learn(context, diseaseKey, data, 'what_to_do'),
                      icon: Icons.medical_services_outlined,
                      highlight: true,
                      highlightColor: _riskColor,
                    ),
                    const SizedBox(height: 10),
                    _DetailSection(
                      label: _ui(context, 'prevention'),
                      content: _learn(context, diseaseKey, data, 'prevention'),
                      icon: Icons.shield_outlined,
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String label;
  final String content;
  final IconData icon;
  final bool highlight;
  final Color? highlightColor;

  const _DetailSection({
    required this.label,
    required this.content,
    required this.icon,
    this.highlight = false,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = highlight ? (highlightColor ?? Bg.rust) : Bg.matcha;
    return _GlassCard(
      borderColor: highlight ? accent.withOpacity(0.5) : null,
      glossTint: highlight ? Bg.rustBg : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: accent),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: TextStyle(fontSize: 13.5, color: Fg.ink, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}