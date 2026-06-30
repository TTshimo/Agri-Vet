class BehavioralScorer {
  BehavioralScorer._();

  static double calculateScore(
    List<Map<String, dynamic>> questions,
    Map<String, String> answers,
  ) {
    double total = 0.0;

    for (final question in questions) {
      final id = question['id'] as String? ?? '';
      final answer = answers[id];
      if (answer == null) continue; // question was skipped

      final weights = question['weights'] as Map<String, dynamic>?;
      if (weights == null) continue;

      final weight = weights[answer];
      if (weight != null) {
        total += (weight as num).toDouble();
      }
    }

    return total;
  }

  static String determineRiskLevel({
    required double score,
    required Map<String, dynamic> thresholds,
    required String baseRiskLevel,
  }) {
    final low = (thresholds['low'] as num?)?.toDouble() ?? 0.1;
    final medium = (thresholds['medium'] as num?)?.toDouble() ?? 0.3;
    final high = (thresholds['high'] as num?)?.toDouble() ?? 0.5;

    String behaviouralLevel;
    if (score < low) {
      behaviouralLevel = 'none';
    } else if (score < medium) {
      behaviouralLevel = 'low';
    } else if (score < high) {
      behaviouralLevel = 'medium';
    } else {
      behaviouralLevel = 'high';
    }

    return _applyBaseFloor(behaviouralLevel, baseRiskLevel);
  }

  static const _levelOrder = ['none', 'low', 'medium', 'high'];

  static String _applyBaseFloor(
      String behaviouralLevel, String baseRiskLevel) {
    final floor = _floorForBase(baseRiskLevel);
    final bIdx = _levelOrder.indexOf(behaviouralLevel);
    final fIdx = _levelOrder.indexOf(floor);
    return bIdx >= fIdx ? behaviouralLevel : floor;
  }

  static String _floorForBase(String baseRiskLevel) {
    switch (baseRiskLevel) {
      case 'high':
        return 'medium';
      case 'medium':
        return 'low';
      default:
        return 'none';
    }
  }

  static List<Map<String, dynamic>> debugBreakdown(
    List<Map<String, dynamic>> questions,
    Map<String, String> answers,
  ) {
    final rows = <Map<String, dynamic>>[];
    for (final question in questions) {
      final id = question['id'] as String? ?? '';
      final answer = answers[id];
      final weights = question['weights'] as Map<String, dynamic>?;
      final weight =
          (answer != null && weights != null) ? weights[answer] : null;

      rows.add({
        'id': id,
        'answered': answer ?? '(skipped)',
        'weight': weight ?? 0.0,
      });
    }
    return rows;
  }
}