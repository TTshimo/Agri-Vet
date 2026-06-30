import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';

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
  ];

  final List<String> _cropDiseases = [
    'watermelon mosaic virus',
    'sorghum cereal grain mold',
    'sorghum covered kernel smut',
    'potato late blight',
    'tomato late blight',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw =
        await rootBundle.loadString('assets/data/disease_info.json');
    setState(() {
      _diseaseData = json.decode(raw);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(color: AppColors.greenDark))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    color: AppColors.greenDark,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      MediaQuery.of(context).padding.top + 16,
                      20,
                      20,
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Learn',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Stay informed about diseases',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.greenHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text(
                      'ANIMAL DISEASES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.08 * 11,
                      ),
                    ),
                  ),
                ),

                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final key = _animalDiseases[i];
                      final data = Map<String, dynamic>.from(
                          _diseaseData[key] ?? {});
                      return Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: _DiseaseCard(
                          diseaseKey: key,
                          data: data,
                          isAnimal: true,
                        ),
                      );
                    },
                    childCount: _animalDiseases.length,
                  ),
                ),

                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      'CROP DISEASES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.08 * 11,
                      ),
                    ),
                  ),
                ),

                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final key = _cropDiseases[i];
                      final data = Map<String, dynamic>.from(
                          _diseaseData[key] ?? {});
                      return Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: _DiseaseCard(
                          diseaseKey: key,
                          data: data,
                          isAnimal: false,
                        ),
                      );
                    },
                    childCount: _cropDiseases.length,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
    );
  }
}

// Disease card
class _DiseaseCard extends StatelessWidget {
  final String diseaseKey;
  final Map<String, dynamic> data;
  final bool isAnimal;

  const _DiseaseCard({
    required this.diseaseKey,
    required this.data,
    required this.isAnimal,
  });

  Color get _riskColor {
    switch (data['risk_level']) {
      case 'high':
        return AppColors.red;
      case 'medium':
        return AppColors.amber;
      default:
        return AppColors.greenText;
    }
  }

  Color get _riskBg {
    switch (data['risk_level']) {
      case 'high':
        return AppColors.redLight;
      case 'medium':
        return AppColors.amberLight;
      default:
        return AppColors.greenLight;
    }
  }

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
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _riskBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isAnimal ? Icons.pets_rounded : Icons.eco_rounded,
                size: 22,
                color: _riskColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['display_name'] ?? diseaseKey,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data['symptoms'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// Disease details
class _DiseaseDetailScreen extends StatelessWidget {
  final String diseaseKey;
  final Map<String, dynamic> data;
  final bool isAnimal;

  const _DiseaseDetailScreen({
    required this.diseaseKey,
    required this.data,
    required this.isAnimal,
  });

  Color get _riskColor {
    switch (data['risk_level']) {
      case 'high':
        return AppColors.red;
      case 'medium':
        return AppColors.amber;
      default:
        return AppColors.greenText;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.greenDark,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 16,
                20,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.greenHint,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    data['display_name'] ?? diseaseKey,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isAnimal ? 'Animal disease' : 'Crop disease',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.greenHint,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DetailSection(
                    label: 'Symptoms',
                    content: data['symptoms'] ?? '',
                    icon: Icons.search_rounded,
                  ),
                  const SizedBox(height: 12),
                  _DetailSection(
                    label: 'Affects',
                    content: data['affects'] ?? '',
                    icon: Icons.pets_rounded,
                  ),
                  const SizedBox(height: 12),
                  _DetailSection(
                    label: 'How it spreads',
                    content: data['spreads_by'] ?? '',
                    icon: Icons.share_outlined,
                  ),
                  const SizedBox(height: 12),
                  _DetailSection(
                    label: 'What to do',
                    content: data['what_to_do'] ?? '',
                    icon: Icons.medical_services_outlined,
                    highlight: true,
                    highlightColor: _riskColor,
                  ),
                  const SizedBox(height: 12),
                  _DetailSection(
                    label: 'Prevention',
                    content: data['prevention'] ?? '',
                    icon: Icons.shield_outlined,
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight
            ? (highlightColor ?? AppColors.greenDark).withOpacity(0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: highlight
              ? (highlightColor ?? AppColors.greenDark).withOpacity(0.2)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: highlight
                    ? (highlightColor ?? AppColors.greenDark)
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: highlight
                      ? (highlightColor ?? AppColors.greenDark)
                      : AppColors.textSecondary,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}