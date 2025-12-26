import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sevasetu/hierarchical_system/models/ai_analysis.dart';
import 'package:sevasetu/hierarchical_system/models/enums.dart';

void main() {
  group('AIAnalysis', () {
    // Feature: sevasetu-hierarchical-system, Property 14: AIAnalysis JSON Round-Trip
    // Validates: Requirements 14.10
    group('Property 14: JSON Round-Trip', () {
      test('fromJson(toJson(analysis)) produces equivalent object', () {
        final random = Random(42);

        // Run 100 iterations with random data
        for (int i = 0; i < 100; i++) {
          final original = _generateRandomAIAnalysis(random);
          final json = original.toJson();
          final restored = AIAnalysis.fromJson(json);

          expect(
            restored.detectedCategory,
            equals(original.detectedCategory),
            reason: 'detectedCategory should match after round-trip',
          );
          expect(
            restored.confidenceScore,
            equals(original.confidenceScore),
            reason: 'confidenceScore should match after round-trip',
          );
          expect(
            restored.severityLevel,
            equals(original.severityLevel),
            reason: 'severityLevel should match after round-trip',
          );
          expect(
            restored.affectedAreaSqm,
            equals(original.affectedAreaSqm),
            reason: 'affectedAreaSqm should match after round-trip',
          );
          expect(
            restored.populationImpact,
            equals(original.populationImpact),
            reason: 'populationImpact should match after round-trip',
          );
          expect(
            restored.hazardIndicators,
            equals(original.hazardIndicators),
            reason: 'hazardIndicators should match after round-trip',
          );
          expect(
            restored.recommendedPriority,
            equals(original.recommendedPriority),
            reason: 'recommendedPriority should match after round-trip',
          );
          expect(
            restored.analysisNotes,
            equals(original.analysisNotes),
            reason: 'analysisNotes should match after round-trip',
          );
          expect(
            restored.analyzedAt,
            equals(original.analyzedAt),
            reason: 'analyzedAt should match after round-trip',
          );
          expect(
            restored,
            equals(original),
            reason: 'Full object equality should hold after round-trip',
          );
        }
      });

      test('handles empty hazard indicators list', () {
        final analysis = AIAnalysis(
          detectedCategory: IssueCategory.pothole,
          confidenceScore: 0.9,
          severityLevel: SeverityLevel.high,
          affectedAreaSqm: 10.0,
          populationImpact: PopulationImpact.medium,
          hazardIndicators: [],
          recommendedPriority: 75,
          analysisNotes: '',
          analyzedAt: DateTime(2025, 1, 1),
        );

        final json = analysis.toJson();
        final restored = AIAnalysis.fromJson(json);

        expect(restored.hazardIndicators, isEmpty);
        expect(restored, equals(analysis));
      });

      test('handles multiple hazard indicators', () {
        final analysis = AIAnalysis(
          detectedCategory: IssueCategory.sewageOverflow,
          confidenceScore: 0.95,
          severityLevel: SeverityLevel.critical,
          affectedAreaSqm: 50.0,
          populationImpact: PopulationImpact.critical,
          hazardIndicators: [
            HazardIndicator.healthHazard,
            HazardIndicator.waterContamination,
            HazardIndicator.diseaseRisk,
          ],
          recommendedPriority: 95,
          analysisNotes: 'Urgent attention required',
          analyzedAt: DateTime(2025, 6, 15, 14, 30),
        );

        final json = analysis.toJson();
        final restored = AIAnalysis.fromJson(json);

        expect(restored.hazardIndicators.length, equals(3));
        expect(restored, equals(analysis));
      });
    });

    group('Field Validation', () {
      test('confidenceScore is preserved with precision', () {
        final scores = [0.0, 0.1, 0.5, 0.99, 1.0, 0.123456789];

        for (final score in scores) {
          final analysis = _createAnalysisWithConfidence(score);
          final json = analysis.toJson();
          final restored = AIAnalysis.fromJson(json);

          expect(restored.confidenceScore, equals(score));
        }
      });

      test('analyzedAt preserves timestamp precision', () {
        final timestamps = [
          DateTime(2025, 1, 1),
          DateTime(2025, 12, 31, 23, 59, 59),
          DateTime.now(),
        ];

        for (final timestamp in timestamps) {
          final analysis = _createAnalysisWithTimestamp(timestamp);
          final json = analysis.toJson();
          final restored = AIAnalysis.fromJson(json);

          expect(restored.analyzedAt, equals(timestamp));
        }
      });
    });
  });
}

AIAnalysis _generateRandomAIAnalysis(Random random) {
  final categories = IssueCategory.all;
  final severities = SeverityLevel.all;
  final impacts = PopulationImpact.all;
  final hazards = [
    HazardIndicator.trafficRisk,
    HazardIndicator.pedestrianSafety,
    HazardIndicator.healthHazard,
    HazardIndicator.flooding,
    HazardIndicator.fireHazard,
  ];

  // Generate random hazard indicators
  final numHazards = random.nextInt(hazards.length + 1);
  final selectedHazards = <String>[];
  for (int i = 0; i < numHazards; i++) {
    final hazard = hazards[random.nextInt(hazards.length)];
    if (!selectedHazards.contains(hazard)) {
      selectedHazards.add(hazard);
    }
  }

  return AIAnalysis(
    detectedCategory: categories[random.nextInt(categories.length)],
    confidenceScore: random.nextDouble(),
    severityLevel: severities[random.nextInt(severities.length)],
    affectedAreaSqm: random.nextDouble() * 1000,
    populationImpact: impacts[random.nextInt(impacts.length)],
    hazardIndicators: selectedHazards,
    recommendedPriority: random.nextInt(101),
    analysisNotes: 'Test note ${random.nextInt(1000)}',
    analyzedAt: DateTime(
      2025,
      random.nextInt(12) + 1,
      random.nextInt(28) + 1,
      random.nextInt(24),
      random.nextInt(60),
    ),
  );
}

AIAnalysis _createAnalysisWithConfidence(double confidence) {
  return AIAnalysis(
    detectedCategory: IssueCategory.pothole,
    confidenceScore: confidence,
    severityLevel: SeverityLevel.medium,
    affectedAreaSqm: 10.0,
    populationImpact: PopulationImpact.medium,
    hazardIndicators: [],
    recommendedPriority: 50,
    analysisNotes: '',
    analyzedAt: DateTime(2025, 1, 1),
  );
}

AIAnalysis _createAnalysisWithTimestamp(DateTime timestamp) {
  return AIAnalysis(
    detectedCategory: IssueCategory.pothole,
    confidenceScore: 0.9,
    severityLevel: SeverityLevel.medium,
    affectedAreaSqm: 10.0,
    populationImpact: PopulationImpact.medium,
    hazardIndicators: [],
    recommendedPriority: 50,
    analysisNotes: '',
    analyzedAt: timestamp,
  );
}
