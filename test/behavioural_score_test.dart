// Unit tests for the behavioural risk scorer used by the diagnosis flow.
//
// (The previous file was Flutter's default counter template, which could
// never pass against this app.)

import 'package:flutter_test/flutter_test.dart';

import 'package:agrivet/services/behavioural_score.dart';

void main() {
  final questions = <Map<String, dynamic>>[
    {
      'id': 'q1',
      'weights': {'yes': 0.2, 'no': 0.0},
    },
    {
      'id': 'q2',
      'weights': {'yes': 0.15, 'no': 0.0},
    },
    {
      'id': 'q3',
      'weights': {'yes': 0.3, 'no': 0.0},
    },
  ];

  const thresholds = <String, dynamic>{
    'low': 0.1,
    'medium': 0.3,
    'high': 0.5,
  };

  group('BehavioralScorer.calculateScore', () {
    test('sums the weights of the chosen answers', () {
      final score = BehavioralScorer.calculateScore(
        questions,
        {'q1': 'yes', 'q2': 'yes', 'q3': 'no'},
      );
      expect(score, closeTo(0.35, 1e-9));
    });

    test('skips unanswered questions', () {
      final score = BehavioralScorer.calculateScore(questions, {'q3': 'yes'});
      expect(score, closeTo(0.3, 1e-9));
    });

    test('ignores answers that have no weight', () {
      final score =
          BehavioralScorer.calculateScore(questions, {'q1': 'not sure'});
      expect(score, 0.0);
    });
  });

  group('BehavioralScorer.determineRiskLevel', () {
    String level(double score, String base) =>
        BehavioralScorer.determineRiskLevel(
          score: score,
          thresholds: thresholds,
          baseRiskLevel: base,
        );

    test('maps scores onto the threshold bands', () {
      expect(level(0.05, 'none'), 'none');
      expect(level(0.1, 'none'), 'low');
      expect(level(0.35, 'none'), 'medium');
      expect(level(0.5, 'none'), 'high');
    });

    test('a high-risk disease never drops below medium', () {
      expect(level(0.0, 'high'), 'medium');
    });

    test('a medium-risk disease never drops below low', () {
      expect(level(0.0, 'medium'), 'low');
    });

    test('behavioural answers can still raise risk above the floor', () {
      expect(level(0.6, 'medium'), 'high');
    });
  });
}
