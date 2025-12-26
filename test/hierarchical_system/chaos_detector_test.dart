import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sevasetu/hierarchical_system/models/ai_analysis.dart';
import 'package:sevasetu/hierarchical_system/models/enums.dart';
import 'package:sevasetu/hierarchical_system/services/chaos_detector.dart';

void main() {
  late ChaosDetector detector;

  setUp(() {
    detector = ChaosDetector();
  });

  group('ChaosDetector', () {
    // Feature: sevasetu-hierarchical-system, Property 8: Chaos Score Bounds
    // Validates: Requirements 10.1, 10.11
    group('Property 8: Chaos Score Bounds', () {
      test('chaos score is always within [0.0, 1.0]', () {
        final random = Random(42);

        for (int i = 0; i < 100; i++) {
          final analysis = _generateRandomAIAnalysis(random);
          final score = detector.calculateChaosScore(analysis);

          expect(
            score,
            greaterThanOrEqualTo(0.0),
            reason: 'Chaos score should never be negative',
          );
          expect(
            score,
            lessThanOrEqualTo(1.0),
            reason: 'Chaos score should never exceed 1.0',
          );
        }
      });

      test(
        'empty hazards with LOW severity and LOW impact gives low chaos',
        () {
          final analysis = AIAnalysis(
            detectedCategory: IssueCategory.garbage,
            confidenceScore: 0.9,
            severityLevel: SeverityLevel.low,
            affectedAreaSqm: 5.0,
            populationImpact: PopulationImpact.low,
            hazardIndicators: [],
            recommendedPriority: 20,
            analysisNotes: '',
            analyzedAt: DateTime.now(),
          );

          final score = detector.calculateChaosScore(analysis);
          expect(score, equals(0.0));
        },
      );

      test(
        'maximum hazards with CRITICAL severity gives high chaos (clamped to 1.0)',
        () {
          final analysis = AIAnalysis(
            detectedCategory: IssueCategory.sewageOverflow,
            confidenceScore: 0.95,
            severityLevel: SeverityLevel.critical,
            affectedAreaSqm: 500.0,
            populationImpact: PopulationImpact.critical,
            hazardIndicators: [
              HazardIndicator.flooding,
              HazardIndicator.trafficBlocked,
              HazardIndicator.structuralDamage,
              HazardIndicator.fireHazard,
              HazardIndicator.healthHazard,
            ],
            recommendedPriority: 100,
            analysisNotes: 'Emergency',
            analyzedAt: DateTime.now(),
          );

          final score = detector.calculateChaosScore(analysis);
          expect(score, equals(1.0)); // Should be clamped to 1.0
        },
      );
    });

    group('Chaos Score Components', () {
      test('CRITICAL severity adds 0.3 to chaos score', () {
        final baseAnalysis = _createBaseAnalysis();
        final criticalAnalysis = baseAnalysis.copyWith(
          severityLevel: 'CRITICAL',
        );

        final baseScore = detector.calculateChaosScore(baseAnalysis);
        final criticalScore = detector.calculateChaosScore(criticalAnalysis);

        expect(criticalScore - baseScore, closeTo(0.3, 0.01));
      });

      test('HIGH severity adds 0.2 to chaos score', () {
        final baseAnalysis = _createBaseAnalysis();
        final highAnalysis = baseAnalysis.copyWith(severityLevel: 'HIGH');

        final baseScore = detector.calculateChaosScore(baseAnalysis);
        final highScore = detector.calculateChaosScore(highAnalysis);

        expect(highScore - baseScore, closeTo(0.2, 0.01));
      });

      test('CRITICAL population impact adds 0.25 to chaos score', () {
        final baseAnalysis = _createBaseAnalysis();
        final criticalAnalysis = baseAnalysis.copyWith(
          populationImpact: 'CRITICAL',
        );

        final baseScore = detector.calculateChaosScore(baseAnalysis);
        final criticalScore = detector.calculateChaosScore(criticalAnalysis);

        expect(criticalScore - baseScore, closeTo(0.25, 0.01));
      });

      test('HIGH population impact adds 0.15 to chaos score', () {
        final baseAnalysis = _createBaseAnalysis();
        final highAnalysis = baseAnalysis.copyWith(populationImpact: 'HIGH');

        final baseScore = detector.calculateChaosScore(baseAnalysis);
        final highScore = detector.calculateChaosScore(highAnalysis);

        expect(highScore - baseScore, closeTo(0.15, 0.01));
      });

      test('flooding hazard adds 0.15 to chaos score', () {
        final baseAnalysis = _createBaseAnalysis();
        final floodingAnalysis = baseAnalysis.copyWith(
          hazardIndicators: [HazardIndicator.flooding],
        );

        final baseScore = detector.calculateChaosScore(baseAnalysis);
        final floodingScore = detector.calculateChaosScore(floodingAnalysis);

        // 0.1 for one hazard + 0.15 for flooding
        expect(floodingScore - baseScore, closeTo(0.25, 0.01));
      });

      test('fire_hazard adds 0.3 to chaos score', () {
        final baseAnalysis = _createBaseAnalysis();
        final fireAnalysis = baseAnalysis.copyWith(
          hazardIndicators: [HazardIndicator.fireHazard],
        );

        final baseScore = detector.calculateChaosScore(baseAnalysis);
        final fireScore = detector.calculateChaosScore(fireAnalysis);

        // 0.1 for one hazard + 0.3 for fire
        expect(fireScore - baseScore, closeTo(0.4, 0.01));
      });

      test('each hazard adds 0.1 to base chaos score', () {
        final analysis1 = _createBaseAnalysis().copyWith(
          hazardIndicators: [HazardIndicator.pedestrianSafety],
        );
        final analysis2 = _createBaseAnalysis().copyWith(
          hazardIndicators: [
            HazardIndicator.pedestrianSafety,
            HazardIndicator.vehicleDamage,
          ],
        );

        final score1 = detector.calculateChaosScore(analysis1);
        final score2 = detector.calculateChaosScore(analysis2);

        expect(score2 - score1, closeTo(0.1, 0.01));
      });
    });

    group('Emergency Detection', () {
      test('isEmergency returns true when chaos >= 0.8', () {
        final analysis = AIAnalysis(
          detectedCategory: IssueCategory.sewageOverflow,
          confidenceScore: 0.95,
          severityLevel: SeverityLevel.critical,
          affectedAreaSqm: 200.0,
          populationImpact: PopulationImpact.critical,
          hazardIndicators: [
            HazardIndicator.flooding,
            HazardIndicator.structuralDamage,
          ],
          recommendedPriority: 95,
          analysisNotes: '',
          analyzedAt: DateTime.now(),
        );

        expect(detector.isEmergency(analysis), isTrue);
      });

      test('isHighPrioritySituation returns true when chaos >= 0.6', () {
        final analysis = AIAnalysis(
          detectedCategory: IssueCategory.pothole,
          confidenceScore: 0.9,
          severityLevel:
              SeverityLevel.critical, // Changed to CRITICAL for higher chaos
          affectedAreaSqm: 50.0,
          populationImpact: PopulationImpact.high,
          hazardIndicators: [
            HazardIndicator.trafficRisk,
            HazardIndicator.pedestrianSafety,
            HazardIndicator.flooding, // Added flooding for +0.15
          ],
          recommendedPriority: 75,
          analysisNotes: '',
          analyzedAt: DateTime.now(),
        );

        expect(detector.isHighPrioritySituation(analysis), isTrue);
      });

      test('needsElevatedAttention returns true when chaos >= 0.4', () {
        final analysis = AIAnalysis(
          detectedCategory: IssueCategory.streetlight,
          confidenceScore: 0.85,
          severityLevel: SeverityLevel.high, // Changed to HIGH for +0.2
          affectedAreaSqm: 20.0,
          populationImpact: PopulationImpact.medium,
          hazardIndicators: [
            HazardIndicator.nightSafety,
            HazardIndicator.pedestrianSafety,
          ],
          recommendedPriority: 50,
          analysisNotes: '',
          analyzedAt: DateTime.now(),
        );

        expect(detector.needsElevatedAttention(analysis), isTrue);
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
    HazardIndicator.structuralDamage,
    HazardIndicator.trafficBlocked,
  ];

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
    analysisNotes: '',
    analyzedAt: DateTime.now(),
  );
}

AIAnalysis _createBaseAnalysis() {
  return AIAnalysis(
    detectedCategory: IssueCategory.pothole,
    confidenceScore: 0.9,
    severityLevel: SeverityLevel.low,
    affectedAreaSqm: 10.0,
    populationImpact: PopulationImpact.low,
    hazardIndicators: [],
    recommendedPriority: 30,
    analysisNotes: '',
    analyzedAt: DateTime.now(),
  );
}
