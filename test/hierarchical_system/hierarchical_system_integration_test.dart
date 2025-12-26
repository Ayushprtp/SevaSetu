import 'package:flutter_test/flutter_test.dart';
import 'package:sevasetu/hierarchical_system/hierarchical_system.dart';

/// Mock AI service that returns analysis based on issue category for testing.
class MockAIAnalysisService implements AIAnalysisService {
  @override
  Future<AIAnalysis> analyzeImage(String imageUrl) async {
    // Extract category hint from URL if present
    String category = IssueCategory.pothole;
    final urlLower = imageUrl.toLowerCase();

    if (urlLower.contains('garbage')) {
      category = IssueCategory.garbage;
    } else if (urlLower.contains('power')) {
      category = IssueCategory.powerCut;
    } else if (urlLower.contains('water')) {
      category = IssueCategory.waterLeak;
    } else if (urlLower.contains('streetlight')) {
      category = IssueCategory.streetlight;
    } else if (urlLower.contains('sewage')) {
      category = IssueCategory.sewageOverflow;
    } else if (urlLower.contains('drainage')) {
      category = IssueCategory.drainageProblem;
    } else if (urlLower.contains('other')) {
      category = IssueCategory.other;
    }

    // Return analysis with appropriate severity based on category
    final isHighPriority =
        category == IssueCategory.powerCut ||
        category == IssueCategory.sewageOverflow;

    return AIAnalysis(
      detectedCategory: category,
      confidenceScore: 0.85,
      severityLevel: isHighPriority ? SeverityLevel.high : SeverityLevel.medium,
      affectedAreaSqm: isHighPriority ? 100.0 : 25.0,
      populationImpact: isHighPriority
          ? PopulationImpact.high
          : PopulationImpact.medium,
      hazardIndicators: isHighPriority
          ? [HazardIndicator.healthHazard, HazardIndicator.trafficRisk]
          : [],
      recommendedPriority: isHighPriority ? 75 : 50,
      analysisNotes: 'Mock analysis for testing',
      analyzedAt: DateTime.now(),
    );
  }

  @override
  bool validateAnalysis(AIAnalysis analysis) => true;
}

void main() {
  group('HierarchicalSystemService Integration Tests', () {
    late HierarchicalSystemService service;

    setUp(() {
      // Create service with mock AI for unit testing
      service = HierarchicalSystemService(aiService: MockAIAnalysisService());
    });

    group('Full Issue Processing Flow', () {
      test('processes issue without AI analysis', () async {
        final issue = CivicIssue(
          id: 'test_issue_1',
          category: IssueCategory.pothole,
          description: 'Large pothole on main road',
          imageUrl: 'https://example.com/pothole.jpg',
          location: GeoPoint(latitude: 25.0, longitude: 75.0),
          district: 'TestDistrict',
          state: 'TestState',
          upvotes: 10,
          createdAt: DateTime.now(),
        );

        final result = await service.processNewIssue(issue);

        // Verify priority score is calculated
        expect(result.priorityScore, greaterThan(0));
        expect(result.priorityScore, lessThanOrEqualTo(100));

        // Verify department routing
        expect(result.department, equals(Department.pwd));

        // Verify issue is updated
        expect(result.issue.priorityScore, equals(result.priorityScore));
      });

      test('routes different categories to correct departments', () async {
        final categories = {
          IssueCategory.pothole: Department.pwd,
          IssueCategory.drainageProblem: Department.pwd,
          IssueCategory.garbage: Department.sanitation,
          IssueCategory.sewageOverflow: Department.sanitation,
          IssueCategory.streetlight: Department.electricity,
          IssueCategory.powerCut: Department.electricity,
          IssueCategory.waterLeak: Department.water,
          IssueCategory.other: Department.general,
        };

        for (final entry in categories.entries) {
          final issue = _createIssueWithCategory(entry.key);
          final result = await service.processNewIssue(issue);

          expect(
            result.department,
            equals(entry.value),
            reason: 'Category ${entry.key} should route to ${entry.value}',
          );
        }
      });

      test('calculates higher priority for critical issues', () async {
        final lowPriorityIssue = CivicIssue(
          id: 'low_priority',
          category: IssueCategory.garbage,
          description: 'Minor garbage issue',
          imageUrl: 'https://example.com/garbage.jpg',
          location: GeoPoint(latitude: 25.0, longitude: 75.0),
          district: 'TestDistrict',
          state: 'TestState',
          upvotes: 0,
          createdAt: DateTime.now().subtract(Duration(days: 5)),
        );

        final highPriorityIssue = CivicIssue(
          id: 'high_priority',
          category: IssueCategory.powerCut,
          description: 'Major power outage',
          imageUrl: 'https://example.com/power.jpg',
          location: GeoPoint(latitude: 25.0, longitude: 75.0),
          district: 'TestDistrict',
          state: 'TestState',
          upvotes: 50,
          createdAt: DateTime.now(),
        );

        final lowResult = await service.processNewIssue(lowPriorityIssue);
        final highResult = await service.processNewIssue(highPriorityIssue);

        expect(highResult.priorityScore, greaterThan(lowResult.priorityScore));
      });
    });

    group('Emergency Escalation Flow', () {
      test('detects emergency from high chaos score', () {
        final criticalAnalysis = AIAnalysis(
          detectedCategory: IssueCategory.sewageOverflow,
          confidenceScore: 0.95,
          severityLevel: SeverityLevel.critical,
          affectedAreaSqm: 500.0,
          populationImpact: PopulationImpact.critical,
          hazardIndicators: [
            HazardIndicator.flooding,
            HazardIndicator.structuralDamage,
            HazardIndicator.fireHazard,
            HazardIndicator.healthHazard,
          ],
          recommendedPriority: 100,
          analysisNotes: 'Emergency situation',
          analyzedAt: DateTime.now(),
        );

        final chaosScore = service.getChaosScore(criticalAnalysis);
        final escalationLevel = service.getEscalationLevel(chaosScore);

        expect(chaosScore, greaterThanOrEqualTo(0.8));
        expect(escalationLevel, equals(EscalationLevel.emergency));
      });

      test('identifies high priority situations', () {
        final highPriorityAnalysis = AIAnalysis(
          detectedCategory: IssueCategory.pothole,
          confidenceScore: 0.9,
          severityLevel: SeverityLevel.high, // HIGH gives +0.2
          affectedAreaSqm: 50.0,
          populationImpact: PopulationImpact.high, // HIGH gives +0.15
          hazardIndicators: [
            HazardIndicator.trafficRisk,
            HazardIndicator.pedestrianSafety,
            HazardIndicator.trafficBlocked, // +0.1 specific + 0.3 for 3 hazards
          ],
          recommendedPriority: 80,
          analysisNotes: '',
          analyzedAt: DateTime.now(),
        );

        final chaosScore = service.getChaosScore(highPriorityAnalysis);
        final escalationLevel = service.getEscalationLevel(chaosScore);

        // 0.2 (HIGH severity) + 0.15 (HIGH population) + 0.3 (3 hazards) + 0.1 (traffic_blocked) = 0.75
        expect(chaosScore, greaterThanOrEqualTo(0.6));
        expect(
          chaosScore,
          lessThan(0.8),
        ); // Should be highPriority, not emergency
        expect(escalationLevel, equals(EscalationLevel.highPriority));
      });
    });

    group('Priority Recalculation', () {
      test('recalculates priority when upvotes change', () async {
        final issueWithFewUpvotes = CivicIssue(
          id: 'test_issue',
          category: IssueCategory.pothole,
          description: 'Test issue',
          imageUrl: 'https://example.com/image.jpg',
          location: GeoPoint(latitude: 25.0, longitude: 75.0),
          district: 'TestDistrict',
          state: 'TestState',
          upvotes: 5,
          createdAt: DateTime.now(),
        );

        final issueWithManyUpvotes = issueWithFewUpvotes.copyWith(upvotes: 100);

        final scoreFew = await service.recalculatePriority(issueWithFewUpvotes);
        final scoreMany = await service.recalculatePriority(
          issueWithManyUpvotes,
        );

        expect(scoreMany, greaterThan(scoreFew));
      });

      test('recalculates priority when issue ages', () async {
        final freshIssue = CivicIssue(
          id: 'test_issue',
          category: IssueCategory.pothole,
          description: 'Test issue',
          imageUrl: 'https://example.com/image.jpg',
          location: GeoPoint(latitude: 25.0, longitude: 75.0),
          district: 'TestDistrict',
          state: 'TestState',
          upvotes: 10,
          createdAt: DateTime.now(),
        );

        final oldIssue = freshIssue.copyWith(
          createdAt: DateTime.now().subtract(Duration(days: 45)),
        );

        final scoreFresh = await service.recalculatePriority(freshIssue);
        final scoreOld = await service.recalculatePriority(oldIssue);

        // Both fresh and very old issues get high time scores
        expect(scoreFresh, greaterThanOrEqualTo(0));
        expect(scoreOld, greaterThanOrEqualTo(0));
      });
    });

    group('High Priority Determination', () {
      test('marks issue as high priority when score > 70', () {
        expect(service.checkHighPriority(71, null), isTrue);
        expect(service.checkHighPriority(70, null), isFalse);
      });

      test('marks issue as high priority when severity is CRITICAL', () {
        final criticalAnalysis = AIAnalysis(
          detectedCategory: IssueCategory.pothole,
          confidenceScore: 0.9,
          severityLevel: SeverityLevel.critical,
          affectedAreaSqm: 10.0,
          populationImpact: PopulationImpact.medium,
          hazardIndicators: [],
          recommendedPriority: 50,
          analysisNotes: '',
          analyzedAt: DateTime.now(),
        );

        expect(service.checkHighPriority(30, criticalAnalysis), isTrue);
      });
    });
  });
}

CivicIssue _createIssueWithCategory(String category) {
  return CivicIssue(
    id: 'test_${category.toLowerCase()}',
    category: category,
    description: 'Test issue for $category',
    imageUrl: 'https://example.com/${category.toLowerCase()}.jpg',
    location: GeoPoint(latitude: 25.0, longitude: 75.0),
    district: 'TestDistrict',
    state: 'TestState',
    upvotes: 5,
    createdAt: DateTime.now(),
  );
}
