/// Pure logic for scoring behavioral profiling answers against a disease's
/// risk thresholds. Extracted from DiagnosisScreen so it can be unit tested
/// without spinning up widgets, Firebase, or TFLite.
class BehavioralScorer {
  /// Calculates the total behavioral score from a set of answers.
  ///
  /// [questions] is the raw `behavioral_questions` list from the knowledge
  /// base JSON for a given disease. Each question map must contain an `id`
  /// and a `weights` map of answer -> numeric weight.
  ///
  /// [answers] maps question id -> the answer string the user selected.
  ///
  /// Unanswered questions contribute 0. Unknown answer strings contribute 0
  /// rather than throwing, since user input should never crash scoring.
  static double calculateScore(
    List<Map<String, dynamic>> questions,
    Map<String, String> answers,
  ) {
    double total = 0;
    for (final q in questions) {
      final id = q['id'] as String?;
      if (id == null) continue;

      final answer = answers[id];
      if (answer == null) continue;

      final weights = q['weights'] as Map<String, dynamic>? ?? {};
      final weight = weights[answer];
      if (weight is num) {
        total += weight.toDouble();
      }
    }
    return total;
  }

  /// Determines the final risk level given a behavioral score and a
  /// disease's risk_thresholds map (`{low, medium, high}`).
  ///
  /// Diseases with risk_level == 'none' (healthy classes) always return
  /// 'none' regardless of score, since there are no behavioral questions
  /// to ask about a healthy animal/plant.
  static String determineRiskLevel({
    required double score,
    required Map<String, dynamic> thresholds,
    required String baseRiskLevel,
  }) {
    if (baseRiskLevel == 'none') return 'none';

    final highThresh = (thresholds['high'] as num? ?? 0.5).toDouble();
    final medThresh = (thresholds['medium'] as num? ?? 0.3).toDouble();

    if (score >= highThresh) return 'high';
    if (score >= medThresh) return 'medium';
    return 'low';
  }

  /// Convenience combined call: score the answers and resolve the risk
  /// level in one step.
  static String scoreAndClassify({
    required List<Map<String, dynamic>> questions,
    required Map<String, String> answers,
    required Map<String, dynamic> thresholds,
    required String baseRiskLevel,
  }) {
    final score = calculateScore(questions, answers);
    return determineRiskLevel(
      score: score,
      thresholds: thresholds,
      baseRiskLevel: baseRiskLevel,
    );
  }
}