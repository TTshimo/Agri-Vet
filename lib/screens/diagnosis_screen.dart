import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../main.dart';
import '../../services/translation_service.dart';
import '../../services/behavioural_score.dart';

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
          backgroundColor: AppColors.red,
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
      backgroundColor: AppColors.background,
      body: CustomScrollView(
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

    return Container(
      color: AppColors.greenDark,
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 20),
      child: Row(
        children: [
          if (widget.initialType != null || _step != _FlowStep.upload)
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
                  color: AppColors.greenHint, size: 24),
            ),
          if (widget.initialType != null || _step != _FlowStep.upload)
            const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          if (_step != _FlowStep.upload)
            GestureDetector(
              onTap: () => setState(() => _showSetswana = !_showSetswana),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _showSetswana ? 'EN' : 'TN',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            'What are you diagnosing?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _TypeCard(
                  icon: Icons.pets_rounded,
                  label: 'Animal',
                  selected: _selectedType == DiagnosisType.animal,
                  onTap: () => setState(() {
                    _selectedType = DiagnosisType.animal;
                    _result = null;
                    _selectedImage = null;
                    _step = _FlowStep.upload;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TypeCard(
                  icon: Icons.eco_rounded,
                  label: 'Plant',
                  selected: _selectedType == DiagnosisType.plant,
                  onTap: () => setState(() {
                    _selectedType = DiagnosisType.plant;
                    _result = null;
                    _selectedImage = null;
                    _step = _FlowStep.upload;
                  }),
                ),
              ),
            ],
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
            const SizedBox(height: 16),
            const Text(
              'Animal type',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _animalType.isEmpty ? null : _animalType,   // fixed: value not initialValue
              decoration: InputDecoration(
                hintText: 'Select animal type',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              items: ['Cattle', 'Goat', 'Poultry']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _animalType = v ?? ''),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedImage == null || _analysing ? null : _analyse,
              child: _analysing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 10),
                        Text('Analysing...'),
                      ],
                    )
                  : const Text('Analyse photo'),
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_result != null) _buildDiseaseBanner(lang),

          const SizedBox(height: 20),

          Row(
            children: [
              Text(
                _showSetswana
                    ? 'Potso ${_currentQuestion + 1} ya ${_questions.length}'
                    : 'Question ${_currentQuestion + 1} of ${_questions.length}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.greenMid,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.background2,
              valueColor: const AlwaysStoppedAnimation(AppColors.greenMid),
              minHeight: 6,
            ),
          ),

          const SizedBox(height: 28),

          Text(
            questionText,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 20),

          ...List.generate(optionsEn.length, (i) {
            final enOption = optionsEn[i];
            final displayLabel = (_showSetswana && i < optionsTn.length)
                ? optionsTn[i]
                : enOption;
            final isSelected = currentAnswer == enOption;

            return GestureDetector(
              onTap: () => _answerQuestion(qId, enOption),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.greenLight : Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: isSelected ? AppColors.greenMid : AppColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayLabel,
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected ? AppColors.greenDark : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: isSelected
                          ? const Icon(Icons.check_circle_rounded,
                              key: ValueKey('checked'),
                              color: AppColors.greenDark, size: 20)
                          : const Icon(Icons.radio_button_unchecked_rounded,
                              key: ValueKey('unchecked'),
                              color: AppColors.border, size: 20),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 24),

          Row(
            children: [
              if (_currentQuestion > 0) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _previousQuestion,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button)),
                    ),
                    child: Text(
                      _showSetswana ? 'Moago' : 'Back',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: currentAnswer == null ? null : _nextQuestion,
                  child: Text(
                    isLastQuestion
                        ? (_showSetswana ? 'Bona supego' : 'See diagnosis')
                        : (_showSetswana ? 'E e latelang' : 'Next'),
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
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.greenLight,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.greenMid.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.image_search_rounded, size: 18, color: AppColors.greenDark),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _showSetswana ? 'Semelo se se bonweng mo setshwantshong' : 'Detected from image',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                Text(
                  '$name  ·  $confidence% match',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.greenDark,
                  ),
                ),
              ],
            ),
          ),
        ],
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

    Color riskColor;
    Color riskBg;
    String riskLabel;
    IconData riskIcon;
    switch (riskLevel) {
      case 'high':
        riskColor = AppColors.red;
        riskBg = AppColors.redLight;
        riskLabel = _showSetswana ? 'Kotsing e kgolo' : 'High risk';
        riskIcon = Icons.warning_rounded;
        break;
      case 'medium':
        riskColor = AppColors.amber;
        riskBg = AppColors.amberLight;
        riskLabel = _showSetswana ? 'Lebelela' : 'Monitor';
        riskIcon = Icons.info_rounded;
        break;
      case 'none':
        riskColor = AppColors.greenText;
        riskBg = AppColors.greenLight;
        riskLabel = _showSetswana ? 'E itekanetseng' : 'Healthy';
        riskIcon = Icons.check_circle_rounded;
        break;
      default: // 'low'
        riskColor = AppColors.amber;
        riskBg = AppColors.amberLight;
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

          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.border),
              color: Colors.white,
            ),
            clipBehavior: Clip.hardEdge,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppColors.greenDark,
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
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: riskBg.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: riskColor.withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(riskIcon, size: 13, color: riskBg),
                                const SizedBox(width: 4),
                                Text(
                                  riskLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: riskBg,
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
                        color: AppColors.greenMid,
                      ),
                      if (r.answers.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _ConfidenceBar(
                          label: _showSetswana ? 'Maitshwaro' : 'Behavioural',
                          value: (r.behavioralScore).clamp(0.0, 1.0),
                          color: riskColor.withOpacity(0.8),
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
              riskLevel: riskLevel,
            ),

          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.border),
            ),
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
                  highlight: riskLevel == 'high',
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
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button)),
            ),
            child: Text(
              _showSetswana ? 'Tshwara supego e nngwe' : 'Diagnose again',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerSummary(String lang) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _showSetswana ? 'Dikarabo tsa gago' : 'Your responses',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
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
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    displayAnswer,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary),
                  ),
                  const Divider(height: 16, color: AppColors.border),
                ],
              ),
            );
          }),
        ],
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

class _ConfidenceBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final String? trailingLabel;

  const _ConfidenceBar({
    required this.label,
    required this.value,
    required this.color,
    this.trailingLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.greenHint)),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.white.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          trailingLabel ?? '${(value * 100).toStringAsFixed(0)}%',
          style: const TextStyle(
              fontSize: 11, color: AppColors.greenHint, fontWeight: FontWeight.w600),
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background2,
        borderRadius: BorderRadius.circular(10),
      ),
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
        color: active ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: active ? Border.all(color: AppColors.border) : null,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: active ? AppColors.greenDark : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String content;
  final String riskLevel;
  const _ActionCard({required this.title, required this.content, required this.riskLevel});

  @override
  Widget build(BuildContext context) {
    final isHigh = riskLevel == 'high';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHigh ? AppColors.amberLight : AppColors.greenLight,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: isHigh
              ? AppColors.amber.withOpacity(0.4)
              : AppColors.greenMid.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isHigh ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                size: 16,
                color: isHigh ? AppColors.amberDark : AppColors.greenDeep,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isHigh ? AppColors.amberDark : AppColors.greenDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: isHigh ? AppColors.amberText : AppColors.greenText,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeCard({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.greenDark : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: selected ? AppColors.greenDark : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: selected ? Colors.white : AppColors.textSecondary),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
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
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.greenMid, width: 1.5),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, size: 40, color: AppColors.greenMid),
            SizedBox(height: 10),
            Text(
              'Take a photo or upload from your gallery',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            SizedBox(height: 4),
            Text(
              'Best results: clear lighting, close up of affected area',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
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
          borderRadius: BorderRadius.circular(AppRadius.card),
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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background2,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.textPrimary),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool multiline;
  const _InfoRow({required this.label, required this.value, this.valueColor, this.multiline = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: multiline
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
                const Divider(height: 16, color: AppColors.border),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: valueColor ?? AppColors.textPrimary,
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
                  : const Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                if (widget.highlight)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.red),
                  ),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: widget.highlight ? AppColors.red : AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary,
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
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.6),
            ),
          ),
      ],
    );
  }
}