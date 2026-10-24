import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/translation_service.dart';
import '../../services/behavioural_score.dart';

// Self-contained palette for the redesign — matcha green / almond / rust.
// Matches the palette used across the other redesigned screens. Fold into
// a shared AppColors in main.dart later if you want it app-wide.
class _C {
  static const matchaDark = Color(0xFF374530);
  static const matchaHeader = Color(0xFF4A5B41);
  static const matcha = Color(0xFF5C7148);
  static const matchaTint = Color(0xFFD6E0C4);
  static const almond = Color(0xFFF6EFE2);
  static const ink = Color(0xFF2B2820);
  static const inkSoft = Color(0xFF726C5C);
  static const rust = Color(0xFFC1703E);
  static const rustBg = Color(0xFFF1DECB);
}

enum DiagnosisType { animal, plant }

enum _FlowStep { upload, profiling, result }

class DiagnosisScreen extends StatefulWidget {
  final DiagnosisType? initialType;
  const DiagnosisScreen({super.key, this.initialType});

  @override
  State<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends State<DiagnosisScreen> {
  DiagnosisType? _selectedType;
  File? _selectedImage;
  bool _analysing = false;
  _DiagnosisResult? _result;
  String _animalType = '';
  bool _showSetswana = false;
  _FlowStep _step = _FlowStep.upload;

  Map<String, dynamic> _knowledgeBase = {};
  List<Map<String, dynamic>> _questions = [];
  final Map<String, String> _answers = {};
  int _currentQuestion = 0;

  final _picker = ImagePicker();
  final _translation = TranslationService();

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _loadKnowledgeBase();
  }

  Future<void> _loadKnowledgeBase() async {
    final raw = await rootBundle.loadString('assets/data/disease_knowledge_base.json');
    setState(() => _knowledgeBase = json.decode(raw));
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 90,
    );
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
        _result = null;
        _step = _FlowStep.upload;
        _answers.clear();
        _currentQuestion = 0;
      });
    }
  }

  Future<void> _analyse() async {
    if (_selectedImage == null || _selectedType == null) return;
    setState(() => _analysing = true);

    try {
      final modelPath = _selectedType == DiagnosisType.animal
          ? 'assets/models/animal_model.tflite'
          : 'assets/models/plant_model.tflite';

      final classesPath = _selectedType == DiagnosisType.animal
          ? 'assets/data/animal_classes.json'
          : 'assets/data/plant_classes.json';

      final interpreter = await Interpreter.fromAsset(modelPath);
      final classesRaw = await rootBundle.loadString(classesPath);
      final classesMap = json.decode(classesRaw) as Map<String, dynamic>;
      final labels = classesMap.map((k, v) => MapEntry(int.parse(k), v.toString()));

      final input = await _preprocessImage(_selectedImage!);
      final outputShape = interpreter.getOutputTensor(0).shape;
      final numClasses = outputShape[1];
      final output = List.filled(numClasses, 0.0).reshape([1, numClasses]);

      interpreter.run(input, output);
      interpreter.close();

      final scores = (output[0] as List).cast<double>();
      double maxScore = 0;
      int maxIndex = 0;
      for (int i = 0; i < scores.length; i++) {
        if (scores[i] > maxScore) {
          maxScore = scores[i];
          maxIndex = i;
        }
      }

      final diseaseKey = labels[maxIndex] ?? 'unknown';
      final category = _selectedType == DiagnosisType.animal ? 'animals' : 'plants';
      final categoryData = _knowledgeBase[category] as Map<String, dynamic>? ?? {};
      final diseaseData = (categoryData[diseaseKey] as Map<String, dynamic>?) ?? {};

      final rawQuestions = diseaseData['behavioral_questions'] as List? ?? [];
      final questions = rawQuestions.cast<Map<String, dynamic>>();

      setState(() {
        _questions = questions;
        _answers.clear();
        _currentQuestion = 0;
        _result = _DiagnosisResult(
          diseaseKey: diseaseKey,
          modelConfidence: maxScore,
          diseaseData: diseaseData,
          type: _selectedType!,
          finalRiskLevel: diseaseData['risk_level'] as String? ?? 'none',
        );
        _step = questions.isEmpty ? _FlowStep.result : _FlowStep.profiling;
      });

      if (questions.isEmpty) _saveToFirestore(_result!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Analysis failed: ${e.toString()}'),
          backgroundColor: _C.rust,
        ));
      }
    } finally {
      if (mounted) setState(() => _analysing = false);
    }
  }

  void _answerQuestion(String questionId, String answer) {
    setState(() => _answers[questionId] = answer);
  }

  void _nextQuestion() {
    if (_currentQuestion < _questions.length - 1) {
      setState(() => _currentQuestion++);
    } else {
      _finishProfiling();
    }
  }

  void _previousQuestion() {
    if (_currentQuestion > 0) setState(() => _currentQuestion--);
  }

  void _finishProfiling() {
    if (_result == null) return;

    final thresholds =
        _result!.diseaseData['risk_thresholds'] as Map<String, dynamic>? ?? {};
    final baseRiskLevel = _result!.diseaseData['risk_level'] as String? ?? 'none';

    final totalScore = BehavioralScorer.calculateScore(_questions, _answers);
    final finalRisk = BehavioralScorer.determineRiskLevel(
      score: totalScore,
      thresholds: thresholds,
      baseRiskLevel: baseRiskLevel,
    );

    setState(() {
      _result = _result!.copyWith(
        finalRiskLevel: finalRisk,
        behavioralScore: totalScore,
        answers: Map.from(_answers),
      );
      _step = _FlowStep.result;
    });

    _saveToFirestore(_result!);
  }

  Future<List> _preprocessImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes)!;
    final resized = img.copyResize(decoded, width: 224, height: 224);

    return List.generate(
      1,
      (_) => List.generate(
        224,
        (y) => List.generate(224, (x) {
          final pixel = resized.getPixel(x, y);
          return [
            pixel.r.toDouble(),
            pixel.g.toDouble(),
            pixel.b.toDouble(),
          ];
        }),
      ),
    );
  }

  Future<void> _saveToFirestore(_DiagnosisResult result) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final nameMap = result.diseaseData['display_name'] as Map<String, dynamic>? ?? {};

    await FirebaseFirestore.instance.collection('diagnoses').add({
      'uid': uid,
      'diseaseKey': result.diseaseKey,
      'diseaseName': nameMap['en'] ?? result.diseaseKey,
      'modelConfidence': result.modelConfidence,
      'behavioralScore': result.behavioralScore,
      'finalRiskLevel': result.finalRiskLevel,
      'answers': result.answers,
      'type': result.type == DiagnosisType.animal ? 'animal' : 'plant',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'diagnosisCount': FieldValue.increment(1)});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.almond,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _BottomFieldWavePainter()),
          ),
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildTopBar()),
              if (widget.initialType == null && _step == _FlowStep.upload)
                SliverToBoxAdapter(child: _buildTypeSelector()),
              if (_selectedType != null) ...[
                if (_step == _FlowStep.upload)
                  SliverToBoxAdapter(child: _buildUploadSection()),
                if (_step == _FlowStep.profiling)
                  SliverToBoxAdapter(child: _buildProfiling()),
                if (_step == _FlowStep.result && _result != null)
                  SliverToBoxAdapter(child: _buildResult()),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    String title;
    switch (_step) {
      case _FlowStep.profiling:
        title = _showSetswana ? 'Dipotso di seng mmalwa' : 'A few questions';
        break;
      case _FlowStep.result:
        title = _showSetswana ? 'Sepelo sa supego' : 'Diagnosis result';
        break;
      default:
        title = _selectedType == DiagnosisType.animal
            ? (_showSetswana ? 'Supego ya leruo' : 'Animal diagnosis')
            : _selectedType == DiagnosisType.plant
                ? (_showSetswana ? 'Supego ya semela' : 'Plant diagnosis')
                : (_showSetswana ? 'Supa' : 'Diagnose');
    }

    final showBack = widget.initialType != null || _step != _FlowStep.upload;

    return _WavyHeader(
      height: MediaQuery.of(context).padding.top + 100,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.of(context).padding.top + 18,
          20,
          0,
        ),
        child: Row(
          children: [
            if (showBack)
              GestureDetector(
                onTap: () {
                  if (_step == _FlowStep.profiling) {
                    setState(() => _step = _FlowStep.upload);
                  } else if (_step == _FlowStep.result) {
                    setState(() {
                      if (_questions.isEmpty) {
                        _step = _FlowStep.upload;
                      } else {
                        _currentQuestion = _questions.length - 1;
                        _step = _FlowStep.profiling;
                      }
                    });
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                child: const Icon(Icons.arrow_back_rounded,
                    color: _C.almond, size: 22),
              ),
            if (showBack) const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _C.almond,
              ),
            ),
            const Spacer(),
            if (_step != _FlowStep.upload)
              GestureDetector(
                onTap: () => setState(() => _showSetswana = !_showSetswana),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _showSetswana ? 'EN' : 'TN',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _C.almond,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What are you diagnosing?',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _C.ink),
          ),
          const SizedBox(height: 12),
          _TypeToggle(
            selected: _selectedType,
            onSelect: (type) => setState(() {
              _selectedType = type;
              _result = null;
              _selectedImage = null;
              _step = _FlowStep.upload;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _selectedImage != null
              ? _ImagePreview(
                  image: _selectedImage!,
                  onClear: () => setState(() {
                    _selectedImage = null;
                    _result = null;
                  }),
                )
              : _UploadZone(
                  onCamera: () => _pickImage(ImageSource.camera),
                  onGallery: () => _pickImage(ImageSource.gallery),
                ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SecondaryButton(
                  icon: Icons.camera_alt_outlined,
                  label: 'Camera',
                  onTap: () => _pickImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SecondaryButton(
                  icon: Icons.photo_library_outlined,
                  label: 'Gallery',
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ),
            ],
          ),
          if (_selectedType == DiagnosisType.animal) ...[
            const SizedBox(height: 18),
            Text(
              'Animal type',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _C.ink),
            ),
            const SizedBox(height: 8),
            _GlassCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: DropdownButtonHideUnderline(
                  child: DropdownButtonFormField<String>(
                    value: _animalType.isEmpty ? null : _animalType,
                    isExpanded: true,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: _C.inkSoft),
                    style: TextStyle(fontSize: 13, color: _C.ink),
                    dropdownColor: _C.almond,
                    decoration: InputDecoration(
                      hintText: 'Select animal type',
                      hintStyle: TextStyle(fontSize: 13, color: _C.inkSoft),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                    items: ['Cattle', 'Goat', 'Poultry']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _animalType = v ?? ''),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedImage == null || _analysing ? null : _analyse,
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.rust,
                disabledBackgroundColor: _C.rust.withOpacity(0.35),
                foregroundColor: _C.rustBg,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _analysing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _C.rustBg),
                        ),
                        SizedBox(width: 10),
                        Text('Analysing...'),
                      ],
                    )
                  : const Text('Analyse photo',
                      style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfiling() {
    if (_questions.isEmpty) return const SizedBox.shrink();

    final q = _questions[_currentQuestion];
    final qId = q['id'] as String? ?? '';
    final lang = _showSetswana ? 'tn' : 'en';

    final questionText =
        (q['question'] as Map<String, dynamic>?)?[lang]?.toString() ??
        (q['question'] as Map<String, dynamic>?)?['en']?.toString() ??
        '';

    final optionsEn =
        ((q['options'] as Map<String, dynamic>?)?['en'] as List?)
            ?.cast<String>() ?? [];
    final optionsTn =
        ((q['options'] as Map<String, dynamic>?)?['tn'] as List?)
            ?.cast<String>() ?? [];

    final currentAnswer = _answers[qId];
    final isLastQuestion = _currentQuestion == _questions.length - 1;
    final progress = (_currentQuestion + 1) / _questions.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_result != null) _buildDiseaseBanner(lang),

          const SizedBox(height: 18),

          Row(
            children: [
              Text(
                _showSetswana
                    ? 'Potso ${_currentQuestion + 1} ya ${_questions.length}'
                    : 'Question ${_currentQuestion + 1} of ${_questions.length}',
                style: TextStyle(fontSize: 12, color: _C.inkSoft),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _C.matcha,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.6),
              valueColor: AlwaysStoppedAnimation(_C.matcha),
              minHeight: 6,
            ),
          ),

          const SizedBox(height: 24),

          Text(
            questionText,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: _C.ink,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 18),

          ...List.generate(optionsEn.length, (i) {
            final enOption = optionsEn[i];
            final displayLabel = (_showSetswana && i < optionsTn.length)
                ? optionsTn[i]
                : enOption;
            final isSelected = currentAnswer == enOption;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => _answerQuestion(qId, enOption),
                child: _GlassCard(
                  borderColor: isSelected ? _C.matcha.withOpacity(0.6) : null,
                  glossTint: isSelected ? _C.matchaTint : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayLabel,
                            style: TextStyle(
                              fontSize: 14,
                              color: isSelected ? _C.matchaDark : _C.ink,
                              fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                            ),
                          ),
                        ),
                        Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: isSelected ? _C.matcha : _C.inkSoft.withOpacity(0.5),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 20),

          Row(
            children: [
              if (_currentQuestion > 0) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _previousQuestion,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _C.inkSoft.withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      _showSetswana ? 'Moago' : 'Back',
                      style: TextStyle(color: _C.inkSoft),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: currentAnswer == null ? null : _nextQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.rust,
                    disabledBackgroundColor: _C.rust.withOpacity(0.35),
                    foregroundColor: _C.rustBg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    isLastQuestion
                        ? (_showSetswana ? 'Bona supego' : 'See diagnosis')
                        : (_showSetswana ? 'E e latelang' : 'Next'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          GestureDetector(
            onTap: _finishProfiling,
            child: Center(
              child: Text(
                _showSetswana
                    ? 'Tlola dipotso tse di setseng'
                    : 'Skip remaining questions',
                style: TextStyle(
                  fontSize: 13,
                  color: _C.inkSoft,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDiseaseBanner(String lang) {
    final nameMap = _result!.diseaseData['display_name'] as Map<String, dynamic>? ?? {};
    final name = nameMap[lang]?.toString() ?? nameMap['en']?.toString() ?? _result!.diseaseKey;
    final confidence = (_result!.modelConfidence * 100).toStringAsFixed(0);

    return _GlassCard(
      borderColor: _C.matcha.withOpacity(0.35),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.image_search_rounded, size: 18, color: _C.matchaDark),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _showSetswana ? 'Semelo se se bonweng mo setshwantshong' : 'Detected from image',
                    style: TextStyle(fontSize: 11, color: _C.inkSoft),
                  ),
                  Text(
                    '$name  ·  $confidence% match',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _C.matchaDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    final r = _result!;
    final lang = _showSetswana ? 'tn' : 'en';
    final diseaseData = r.diseaseData;
    final riskLevel = r.finalRiskLevel;

    final nameMap = diseaseData['display_name'] as Map<String, dynamic>? ?? {};
    final displayName =
        nameMap[lang]?.toString() ?? nameMap['en']?.toString() ?? r.diseaseKey;

    // Two-tone risk language, consistent with the rest of the app: only
    // "high" gets the rust warning treatment, everything else reads calm.
    final isHigh = riskLevel == 'high';
    final riskColor = isHigh ? _C.rust : _C.matcha;
    String riskLabel;
    IconData riskIcon;
    switch (riskLevel) {
      case 'high':
        riskLabel = _showSetswana ? 'Kotsing e kgolo' : 'High risk';
        riskIcon = Icons.warning_rounded;
        break;
      case 'medium':
        riskLabel = _showSetswana ? 'Lebelela' : 'Monitor';
        riskIcon = Icons.info_rounded;
        break;
      case 'none':
        riskLabel = _showSetswana ? 'E itekanetseng' : 'Healthy';
        riskIcon = Icons.check_circle_rounded;
        break;
      default: // 'low'
        riskLabel = _showSetswana ? 'Lebelela' : 'Low concern';
        riskIcon = Icons.info_outline_rounded;
    }

    String loc(String field) {
      final val = diseaseData[field];
      if (val is Map<String, dynamic>) {
        return val[lang]?.toString() ?? val['en']?.toString() ?? '';
      }
      return val?.toString() ?? '';
    }

    final recKey = (riskLevel == 'low' || riskLevel == 'none') ? 'low' : riskLevel;
    final recommendation =
        (diseaseData['recommendations'] as Map<String, dynamic>?)?[recKey]
            as Map<String, dynamic>?;
    final recommendationText =
        recommendation?[lang]?.toString() ?? recommendation?['en']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LangToggle(
            showSetswana: _showSetswana,
            onToggle: (v) => setState(() => _showSetswana = v),
          ),
          const SizedBox(height: 12),

          _GlassCard(
            borderColor: riskColor.withOpacity(0.35),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _C.matchaHeader.withOpacity(0.88),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: _C.almond,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(riskIcon, size: 13, color: _C.almond),
                                const SizedBox(width: 4),
                                Text(
                                  riskLabel,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _C.almond,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _ConfidenceBar(
                        label: _showSetswana ? 'Setshwantsho' : 'Image match',
                        value: r.modelConfidence,
                      ),
                      if (r.answers.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _ConfidenceBar(
                          label: _showSetswana ? 'Maitshwaro' : 'Behavioural',
                          value: (r.behavioralScore).clamp(0.0, 1.0),
                          trailingLabel: riskLabel,
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      if (loc('affects').isNotEmpty && loc('affects') != 'N/A')
                        _InfoRow(
                          label: _showSetswana ? 'E amana le' : 'Affects',
                          value: loc('affects'),
                        ),
                      if (loc('spreads_by').isNotEmpty && loc('spreads_by') != 'N/A')
                        _InfoRow(
                          label: _showSetswana ? 'E anamela ka' : 'Spreads by',
                          value: loc('spreads_by'),
                        ),
                      if (loc('visual_symptoms').isNotEmpty)
                        _InfoRow(
                          label: _showSetswana ? 'Go bonala' : 'Visual signs',
                          value: loc('visual_symptoms'),
                          multiline: true,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          if (recommendationText.isNotEmpty)
            _ActionCard(
              title: _showSetswana ? 'Se o tshwanetse go se dira jaanong' : 'What to do now',
              content: recommendationText,
              isHigh: isHigh,
            ),

          const SizedBox(height: 12),

          _GlassCard(
            child: Column(
              children: [
                _ExpandableSection(
                  label: _showSetswana ? 'Kalafi' : 'Treatment',
                  content: loc('treatment'),
                ),
                _ExpandableSection(
                  label: _showSetswana ? 'Thibelo' : 'Prevention',
                  content: loc('prevention'),
                ),
                _ExpandableSection(
                  label: _showSetswana
                      ? 'Leng o tshwanetse go leletsa ngaka'
                      : 'When to call a vet',
                  content: loc('when_to_call_vet'),
                  isLast: true,
                  highlight: isHigh,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          if (r.answers.isNotEmpty) _buildAnswerSummary(lang),

          const SizedBox(height: 16),

          OutlinedButton(
            onPressed: () => setState(() {
              _step = _FlowStep.upload;
              _selectedImage = null;
              _result = null;
              _answers.clear();
              _currentQuestion = 0;
            }),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _C.inkSoft.withOpacity(0.3)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              _showSetswana ? 'Tshwara supego e nngwe' : 'Diagnose again',
              style: TextStyle(color: _C.inkSoft),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerSummary(String lang) {
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _showSetswana ? 'Dikarabo tsa gago' : 'Your responses',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _C.inkSoft,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 10),
            ..._questions.map((q) {
              final id = q['id'] as String? ?? '';
              final answer = _answers[id];
              if (answer == null) return const SizedBox.shrink();

              final qText =
                  (q['question'] as Map<String, dynamic>?)?[lang]?.toString() ??
                  (q['question'] as Map<String, dynamic>?)?['en']?.toString() ??
                  '';

              final optionsEn =
                  ((q['options'] as Map<String, dynamic>?)?['en'] as List?)
                      ?.cast<String>() ?? [];
              final optionsTn =
                  ((q['options'] as Map<String, dynamic>?)?['tn'] as List?)
                      ?.cast<String>() ?? [];
              final idx = optionsEn.indexOf(answer);
              final displayAnswer = (_showSetswana && idx >= 0 && idx < optionsTn.length)
                  ? optionsTn[idx]
                  : answer;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      qText,
                      style: TextStyle(fontSize: 12, color: _C.inkSoft, height: 1.3),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      displayAnswer,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500, color: _C.ink),
                    ),
                    Divider(height: 16, color: Colors.white.withOpacity(0.7)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _DiagnosisResult {
  final String diseaseKey;
  final double modelConfidence;
  final double behavioralScore;
  final Map<String, dynamic> diseaseData;
  final DiagnosisType type;
  final String finalRiskLevel;
  final Map<String, String> answers;

  const _DiagnosisResult({
    required this.diseaseKey,
    required this.modelConfidence,
    required this.diseaseData,
    required this.type,
    required this.finalRiskLevel,
    this.behavioralScore = 0,
    this.answers = const {},
  });

  _DiagnosisResult copyWith({
    String? finalRiskLevel,
    double? behavioralScore,
    Map<String, String>? answers,
  }) {
    return _DiagnosisResult(
      diseaseKey: diseaseKey,
      modelConfidence: modelConfidence,
      diseaseData: diseaseData,
      type: type,
      finalRiskLevel: finalRiskLevel ?? this.finalRiskLevel,
      behavioralScore: behavioralScore ?? this.behavioralScore,
      answers: answers ?? this.answers,
    );
  }
}

/// Header with a soft wavy bottom edge instead of a hard rectangle, so it
/// blends into the field-wave background instead of sitting on top of it
/// as a flat UI bar. Shared shape/behaviour with the news and learn screens.
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
            child: Container(color: _C.matchaHeader.withOpacity(0.88)),
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
    final paint = Paint()..color = _C.matchaTint.withOpacity(0.5);
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
            color: Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(18),
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
                  heightFactor: 0.4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: (glossTint ?? Colors.white).withOpacity(0.4),
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

/// Animal / Plant segmented toggle — one glass pill, selected side filled.
class _TypeToggle extends StatelessWidget {
  final DiagnosisType? selected;
  final ValueChanged<DiagnosisType> onSelect;
  const _TypeToggle({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          children: [
            Expanded(
              child: _TypeSegment(
                icon: Icons.pets_rounded,
                label: 'Animal',
                selected: selected == DiagnosisType.animal,
                onTap: () => onSelect(DiagnosisType.animal),
              ),
            ),
            Expanded(
              child: _TypeSegment(
                icon: Icons.eco_rounded,
                label: 'Plant',
                selected: selected == DiagnosisType.plant,
                onTap: () => onSelect(DiagnosisType.plant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeSegment extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeSegment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? _C.matchaHeader : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, size: 19, color: selected ? _C.almond : _C.inkSoft),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? _C.almond : _C.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceBar extends StatelessWidget {
  final String label;
  final double value;
  final String? trailingLabel;

  const _ConfidenceBar({
    required this.label,
    required this.value,
    this.trailingLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: _C.matchaTint)),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.white.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(_C.almond),
              minHeight: 5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          trailingLabel ?? '${(value * 100).toStringAsFixed(0)}%',
          style: TextStyle(
              fontSize: 11, color: _C.matchaTint, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _LangToggle extends StatelessWidget {
  final bool showSetswana;
  final ValueChanged<bool> onToggle;
  const _LangToggle({required this.showSetswana, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => onToggle(false),
                child: _LangBtn(label: 'English', active: !showSetswana),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => onToggle(true),
                child: _LangBtn(label: 'Setswana', active: showSetswana),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LangBtn extends StatelessWidget {
  final String label;
  final bool active;
  const _LangBtn({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: active ? _C.matchaHeader : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: active ? _C.almond : _C.inkSoft,
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String content;
  final bool isHigh;
  const _ActionCard({required this.title, required this.content, required this.isHigh});

  @override
  Widget build(BuildContext context) {
    final accent = isHigh ? _C.rust : _C.matcha;
    return _GlassCard(
      borderColor: accent.withOpacity(0.5),
      glossTint: isHigh ? _C.rustBg : _C.matchaTint,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isHigh ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                  size: 16,
                  color: accent,
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: TextStyle(fontSize: 13, color: _C.ink, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadZone extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  const _UploadZone({required this.onCamera, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onGallery,
      child: _GlassCard(
        child: Container(
          height: 180,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _C.matcha.withOpacity(0.4),
              width: 1.5,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined, size: 36, color: _C.matchaHeader),
              const SizedBox(height: 10),
              Text(
                'Take a photo or upload from your gallery',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: _C.ink),
              ),
              const SizedBox(height: 4),
              Text(
                'Best results: clear lighting, close up of affected area',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: _C.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final File image;
  final VoidCallback onClear;
  const _ImagePreview({required this.image, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.file(image, height: 220, width: double.infinity, fit: BoxFit.cover),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: onClear,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SecondaryButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _GlassCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: _C.matchaHeader),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, color: _C.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool multiline;
  const _InfoRow({required this.label, required this.value, this.multiline = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: multiline
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: _C.inkSoft)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _C.ink,
                    height: 1.5,
                  ),
                ),
                Divider(height: 16, color: Colors.white.withOpacity(0.7)),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: TextStyle(fontSize: 13, color: _C.inkSoft)),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _C.ink,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ExpandableSection extends StatefulWidget {
  final String label;
  final String content;
  final bool isLast;
  final bool highlight;
  const _ExpandableSection({
    required this.label,
    required this.content,
    this.isLast = false,
    this.highlight = false,
  });

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: widget.isLast
                  ? null
                  : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.7))),
            ),
            child: Row(
              children: [
                if (widget.highlight)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(Icons.warning_amber_rounded, size: 16, color: _C.rust),
                  ),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: widget.highlight ? _C.rust : _C.ink,
                    ),
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: _C.inkSoft,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              widget.content,
              style: TextStyle(fontSize: 13, color: _C.inkSoft, height: 1.6),
            ),
          ),
      ],
    );
  }
}