import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sevasetu/hierarchical_system/models/ai_analysis.dart';
import 'package:sevasetu/hierarchical_system/models/civic_issue.dart';
import 'package:sevasetu/hierarchical_system/models/enums.dart';
import 'package:sevasetu/hierarchical_system/models/geo_point.dart';
import 'package:sevasetu/hierarchical_system/services/priority_calculator.dart';
import 'package:sevasetu/hierarchical_system/services/chaos_detector.dart';

void main() {
  late PriorityCalculator calculator;

  setUp(() {
    calculator = PriorityCalculator();
  });

  group('PriorityCalculator', () {
    // Feature: sevasetu-hierarchical-system, Property 3: Severity Score Determinism
    // Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.5
    group('Property 3: Severity Score Determinism', () {
      test('CRITICAL severity returns 30 points', () {
        expect(calculator.calculateSeverityScore('CRITICAL'), equals(30));
        expect(calculator.calculateSeverityScore('critical'), equals(30));
      });

      test('HIGH severity returns 24 points', () {
        expect(calculator.calculateSeverityScore('HIGH'), equals(24));
        expect(calculator.calculateSeverityScore('high'), equals(24));
      });

      test('MEDIUM severity returns 15 points', () {
        expect(calculator.calculateSeverityScore('MEDIUM'), equals(15));
        expect(calculator.calculateSeverityScore('medium'), equals(15));
      });

      test('LOW severity returns 8 points', () {
        expect(calculator.calculateSeverityScore('LOW'), equals(8));
        expect(calculator.calculateSeverityScore('low'), equals(8));
      });

      test('unknown severity returns 10 points (default)', () {
        expect(calculator.calculateSeverityScore('UNKNOWN'), equals(10));
        expect(calculator.calculateSeverityScore(''), equals(10));
        expect(calculator.calculateSeverityScore('invalid'), equals(10));
      });

      test('severity scoring is deterministic over 100 iterations', () {
        final severities = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'UNKNOWN'];
        final random = Random(42);

        for (int i = 0; i < 100; i++) {
          final severity = severities[random.nextInt(severities.length)];
          final score1 = calculator.calculateSeverityScore(severity);
          final score2 = calculator.calculateSeverityScore(severity);
          expect(
            score1,
            equals(score2),
            reason: 'Severity scoring should be deterministic',
          );
        }
      });
    });

    // Feature: sevasetu-hierarchical-system, Property 4: Population Score Bounds
    // Validates: Requirements 6.1, 6.2, 6.3, 6.4, 6.8
    group('Property 4: Population Score Bounds', () {
      test('population score never exceeds 25 points', () {
        final random = Random(42);

        for (int i = 0; i < 100; i++) {
          final analysis = _generateRandomAIAnalysis(random);
          final score = calculator.calculatePopulationScore(analysis);

          expect(
            score,
            lessThanOrEqualTo(25),
            reason: 'Population score should never exceed 25',
          );
          expect(
            score,
            greaterThanOrEqualTo(0),
            reason: 'Population score should never be negative',
          );
        }
      });

      test('CRITICAL population impact has base score 25', () {
        final analysis = _createAnalysisWithPopulation('CRITICAL');
        final score = calculator.calculatePopulationScore(analysis);
        expect(score, equals(25));
      });

      test('HIGH population impact has base score 20', () {
        final analysis = _createAnalysisWithPopulation('HIGH');
        final score = calculator.calculatePopulationScore(analysis);
        expect(score, lessThanOrEqualTo(25));
        expect(score, greaterThanOrEqualTo(20));
      });

      test('MEDIUM population impact has base score 12', () {
        final analysis = _createAnalysisWithPopulation('MEDIUM');
        final score = calculator.calculatePopulationScore(analysis);
        expect(score, lessThanOrEqualTo(25));
        expect(score, greaterThanOrEqualTo(12));
      });

      test('LOW population impact has base score 5', () {
        final analysis = _createAnalysisWithPopulation('LOW');
        final score = calculator.calculatePopulationScore(analysis);
        expect(score, lessThanOrEqualTo(25));
        expect(score, greaterThanOrEqualTo(5));
      });
    });

    // Feature: sevasetu-hierarchical-system, Property 5: Category Urgency Score Determinism
    // Validates: Requirements 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7
    group('Property 5: Category Urgency Score Determinism', () {
      test('POWER_CUT returns 15 points', () {
        expect(calculator.getCategoryUrgencyScore('POWER_CUT'), equals(15));
      });

      test('WATER_LEAK and SEWAGE_OVERFLOW return 14 points', () {
        expect(calculator.getCategoryUrgencyScore('WATER_LEAK'), equals(14));
        expect(
          calculator.getCategoryUrgencyScore('SEWAGE_OVERFLOW'),
          equals(14),
        );
      });

      test('POTHOLE returns 12 points', () {
        expect(calculator.getCategoryUrgencyScore('POTHOLE'), equals(12));
      });

      test('DRAINAGE_PROBLEM returns 11 points', () {
        expect(
          calculator.getCategoryUrgencyScore('DRAINAGE_PROBLEM'),
          equals(11),
        );
      });

      test('STREETLIGHT returns 10 points', () {
        expect(calculator.getCategoryUrgencyScore('STREETLIGHT'), equals(10));
      });

      test('GARBAGE returns 8 points', () {
        expect(calculator.getCategoryUrgencyScore('GARBAGE'), equals(8));
      });

      test('OTHER and unknown return 6 points', () {
        expect(calculator.getCategoryUrgencyScore('OTHER'), equals(6));
        expect(calculator.getCategoryUrgencyScore('UNKNOWN'), equals(6));
      });

      test('category urgency is deterministic over 100 iterations', () {
        final random = Random(42);

        for (int i = 0; i < 100; i++) {
          final category =
              IssueCategory.all[random.nextInt(IssueCategory.all.length)];
          final score1 = calculator.getCategoryUrgencyScore(category);
          final score2 = calculator.getCategoryUrgencyScore(category);
          expect(score1, equals(score2));
        }
      });
    });

    // Feature: sevasetu-hierarchical-system, Property 6: Community Score Logarithmic Scaling with Cap
    // Validates: Requirements 8.1, 8.2, 8.3, 8.4, 8.5
    group('Property 6: Community Score Logarithmic Scaling with Cap', () {
      test('0 or negative upvotes return 0 points', () {
        expect(calculator.calculateCommunityScore(0), equals(0));
        expect(calculator.calculateCommunityScore(-1), equals(0));
        expect(calculator.calculateCommunityScore(-100), equals(0));
      });

      test('1-5 upvotes return equal points', () {
        for (int i = 1; i <= 5; i++) {
          expect(calculator.calculateCommunityScore(i), equals(i));
        }
      });

      test('6-20 upvotes follow formula: 5 + (upvotes - 5) * 0.5', () {
        expect(calculator.calculateCommunityScore(6), equals(5));
        expect(calculator.calculateCommunityScore(10), equals(7));
        expect(calculator.calculateCommunityScore(20), equals(12));
      });

      test('21-100 upvotes follow formula: 12 + (upvotes - 20) * 0.1', () {
        expect(calculator.calculateCommunityScore(21), equals(12));
        expect(calculator.calculateCommunityScore(50), equals(15));
        expect(calculator.calculateCommunityScore(100), equals(20));
      });

      test('upvotes > 100 are capped at 15 points', () {
        expect(calculator.calculateCommunityScore(101), equals(15));
        expect(calculator.calculateCommunityScore(500), equals(15));
        expect(calculator.calculateCommunityScore(10000), equals(15));
      });

      test('community score never exceeds 15 points', () {
        final random = Random(42);

        for (int i = 0; i < 100; i++) {
          final upvotes = random.nextInt(10000);
          final score = calculator.calculateCommunityScore(upvotes);
          expect(score, lessThanOrEqualTo(15));
        }
      });
    });

    // Feature: sevasetu-hierarchical-system, Property 7: Time Score Age-Based Rules
    // Validates: Requirements 9.1, 9.2, 9.3, 9.4, 9.5, 9.6
    group('Property 7: Time Score Age-Based Rules', () {
      test('age < 24 hours returns 10 points', () {
        final now = DateTime.now();
        expect(calculator.calculateTimeScore(now), equals(10));
        expect(
          calculator.calculateTimeScore(now.subtract(Duration(hours: 12))),
          equals(10),
        );
        expect(
          calculator.calculateTimeScore(now.subtract(Duration(hours: 23))),
          equals(10),
        );
      });

      test('age 1-3 days returns 8 points', () {
        final now = DateTime.now();
        expect(
          calculator.calculateTimeScore(now.subtract(Duration(days: 1))),
          equals(8),
        );
        expect(
          calculator.calculateTimeScore(now.subtract(Duration(days: 2))),
          equals(8),
        );
      });

      test('age 3-7 days returns 6 points', () {
        final now = DateTime.now();
        expect(
          calculator.calculateTimeScore(now.subtract(Duration(days: 3))),
          equals(6),
        );
        expect(
          calculator.calculateTimeScore(now.subtract(Duration(days: 6))),
          equals(6),
        );
      });

      test('age 7-14 days returns 7 points (bump for getting stale)', () {
        final now = DateTime.now();
        expect(
          calculator.calculateTimeScore(now.subtract(Duration(days: 7))),
          equals(7),
        );
        expect(
          calculator.calculateTimeScore(now.subtract(Duration(days: 13))),
          equals(7),
        );
      });

      test('age 14-30 days returns 8 points (overdue)', () {
        final now = DateTime.now();
        expect(
          calculator.calculateTimeScore(now.subtract(Duration(days: 14))),
          equals(8),
        );
        expect(
          calculator.calculateTimeScore(now.subtract(Duration(days: 29))),
          equals(8),
        );
      });

      test('age > 30 days returns 10 points (needs urgent attention)', () {
        final now = DateTime.now();
        expect(
          calculator.calculateTimeScore(now.subtract(Duration(days: 30))),
          equals(10),
        );
        expect(
          calculator.calculateTimeScore(now.subtract(Duration(days: 100))),
          equals(10),
        );
      });
    });

    // Feature: sevasetu-hierarchical-system, Property 10: Priority Zone Bonus Determinism
    // Validates: Requirements 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 12.7
    group('Property 10: Priority Zone Bonus Determinism', () {
      test('criticalInfrastructure returns 20 points', () {
        expect(
          calculator.getZonePriorityBonus(PriorityZone.criticalInfrastructure),
          equals(20),
        );
      });

      test('educationalZone returns 15 points', () {
        expect(
          calculator.getZonePriorityBonus(PriorityZone.educationalZone),
          equals(15),
        );
      });

      test('commercialHub returns 12 points', () {
        expect(
          calculator.getZonePriorityBonus(PriorityZone.commercialHub),
          equals(12),
        );
      });

      test('residentialDense returns 10 points', () {
        expect(
          calculator.getZonePriorityBonus(PriorityZone.residentialDense),
          equals(10),
        );
      });

      test('industrial returns 8 points', () {
        expect(
          calculator.getZonePriorityBonus(PriorityZone.industrial),
          equals(8),
        );
      });

      test('residentialSparse returns 5 points', () {
        expect(
          calculator.getZonePriorityBonus(PriorityZone.residentialSparse),
          equals(5),
        );
      });

      test('rural returns 3 points', () {
        expect(calculator.getZonePriorityBonus(PriorityZone.rural), equals(3));
      });
    });

    // Feature: sevasetu-hierarchical-system, Property 1: Priority Score Bounds
    // Validates: Requirements 4.1, 4.8
    group('Property 1: Priority Score Bounds', () {
      test('priority score is always within [0, 100]', () {
        final random = Random(42);

        for (int i = 0; i < 100; i++) {
          final issue = _generateRandomCivicIssue(random);
          final analysis = random.nextBool()
              ? _generateRandomAIAnalysis(random)
              : null;

          final score = calculator.calculatePriorityScore(issue, analysis);

          expect(
            score,
            greaterThanOrEqualTo(0),
            reason: 'Priority score should never be negative',
          );
          expect(
            score,
            lessThanOrEqualTo(100),
            reason: 'Priority score should never exceed 100',
          );
        }
      });
    });

    // Feature: sevasetu-hierarchical-system, Property 15: Component Score Bounds
    // Validates: Requirements 4.2, 4.3, 4.4, 4.5, 4.6, 4.7
    group('Property 15: Component Score Bounds', () {
      test('severity component never exceeds 30', () {
        for (final severity in SeverityLevel.all) {
          final score = calculator.calculateSeverityScore(severity);
          expect(score, lessThanOrEqualTo(30));
        }
      });

      test('population component never exceeds 25', () {
        final random = Random(42);
        for (int i = 0; i < 100; i++) {
          final analysis = _generateRandomAIAnalysis(random);
          final score = calculator.calculatePopulationScore(analysis);
          expect(score, lessThanOrEqualTo(25));
        }
      });

      test('category urgency component never exceeds 15', () {
        for (final category in IssueCategory.all) {
          final score = calculator.getCategoryUrgencyScore(category);
          expect(score, lessThanOrEqualTo(15));
        }
      });

      test('community support component never exceeds 15', () {
        final random = Random(42);
        for (int i = 0; i < 100; i++) {
          final upvotes = random.nextInt(10000);
          final score = calculator.calculateCommunityScore(upvotes);
          expect(score, lessThanOrEqualTo(15));
        }
      });

      test('time factor component never exceeds 10', () {
        final random = Random(42);
        for (int i = 0; i < 100; i++) {
          final daysAgo = random.nextInt(365);
          final createdAt = DateTime.now().subtract(Duration(days: daysAgo));
          final score = calculator.calculateTimeScore(createdAt);
          expect(score, lessThanOrEqualTo(10));
        }
      });
    });

    // Feature: sevasetu-hierarchical-system, Property 11: High Priority Determination
    // Validates: Requirements 13.1, 13.2, 13.3
    group('Property 11: High Priority Determination', () {
      test('score > 70 is high priority', () {
        expect(calculator.isHighPriority(71, null), isTrue);
        expect(calculator.isHighPriority(100, null), isTrue);
      });

      test('score <= 70 without other factors is not high priority', () {
        expect(calculator.isHighPriority(70, null), isFalse);
        expect(calculator.isHighPriority(50, null), isFalse);
      });

      test('CRITICAL severity is always high priority', () {
        final analysis = _createAnalysisWithSeverity('CRITICAL');
        expect(calculator.isHighPriority(30, analysis), isTrue);
        expect(calculator.isHighPriority(0, analysis), isTrue);
      });

      test('chaos score >= 0.7 is high priority', () {
        // Create analysis with high chaos indicators
        final analysis = AIAnalysis(
          detectedCategory: IssueCategory.sewageOverflow,
          confidenceScore: 0.9,
          severityLevel: SeverityLevel.high,
          affectedAreaSqm: 100,
          populationImpact: PopulationImpact.critical,
          hazardIndicators: [
            HazardIndicator.flooding,
            HazardIndicator.structuralDamage,
            HazardIndicator.fireHazard,
          ],
          recommendedPriority: 90,
          analysisNotes: '',
          analyzedAt: DateTime.now(),
        );

        expect(calculator.isHighPriority(30, analysis), isTrue);
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

CivicIssue _generateRandomCivicIssue(Random random) {
  return CivicIssue(
    id: 'issue_${random.nextInt(10000)}',
    category: IssueCategory.all[random.nextInt(IssueCategory.all.length)],
    description: 'Test issue',
    imageUrl: 'https://example.com/image.jpg',
    location: GeoPoint(
      latitude: 20.0 + random.nextDouble() * 10,
      longitude: 70.0 + random.nextDouble() * 10,
    ),
    district: 'TestDistrict',
    state: 'TestState',
    upvotes: random.nextInt(200),
    createdAt: DateTime.now().subtract(Duration(days: random.nextInt(60))),
  );
}

AIAnalysis _createAnalysisWithPopulation(String populationImpact) {
  return AIAnalysis(
    detectedCategory: IssueCategory.pothole,
    confidenceScore: 0.9,
    severityLevel: SeverityLevel.medium,
    affectedAreaSqm: 10.0,
    populationImpact: populationImpact,
    hazardIndicators: [],
    recommendedPriority: 50,
    analysisNotes: '',
    analyzedAt: DateTime.now(),
  );
}

AIAnalysis _createAnalysisWithSeverity(String severity) {
  return AIAnalysis(
    detectedCategory: IssueCategory.pothole,
    confidenceScore: 0.9,
    severityLevel: severity,
    affectedAreaSqm: 10.0,
    populationImpact: PopulationImpact.medium,
    hazardIndicators: [],
    recommendedPriority: 50,
    analysisNotes: '',
    analyzedAt: DateTime.now(),
  );
}
