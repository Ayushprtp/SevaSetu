import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/ai_analysis.dart';
import 'models/civic_issue.dart';
import 'models/enums.dart';
import 'models/office.dart';
import 'services/ai_analysis_service.dart';
import 'services/chaos_detector.dart';
import 'services/department_router.dart';
import 'services/escalation_handler.dart';
import 'services/office_assigner.dart';
import 'services/priority_calculator.dart';

/// Main facade for the SevaSetu Hierarchical System.
///
/// Orchestrates all components to process civic issues through:
/// 1. AI Analysis - Automatic categorization and severity assessment
/// 2. Priority Calculation - Multi-factor scoring
/// 3. Department Routing - Category to department mapping
/// 4. Office Assignment - Nearest office selection
/// 5. Escalation Handling - Emergency detection and escalation
class HierarchicalSystemService {
  final AIAnalysisService _aiService;
  final PriorityCalculator _priorityCalculator;
  final DepartmentRouter _departmentRouter;
  final OfficeAssigner _officeAssigner;
  final EscalationHandler _escalationHandler;
  final ChaosDetector _chaosDetector;

  HierarchicalSystemService({
    AIAnalysisService? aiService,
    PriorityCalculator? priorityCalculator,
    DepartmentRouter? departmentRouter,
    OfficeAssigner? officeAssigner,
    EscalationHandler? escalationHandler,
    ChaosDetector? chaosDetector,
    SupabaseClient? supabase,
  }) : _aiService = aiService ?? GeminiAIAnalysisService.withDefaults(),
       _chaosDetector = chaosDetector ?? ChaosDetector(),
       _priorityCalculator = priorityCalculator ?? PriorityCalculator(),
       _departmentRouter = departmentRouter ?? DepartmentRouter(),
       _officeAssigner = officeAssigner ?? OfficeAssigner(supabase: supabase),
       _escalationHandler = escalationHandler ?? EscalationHandler();

  /// Process a new civic issue through the complete pipeline.
  ///
  /// Steps:
  /// 1. Analyze image with AI (if available)
  /// 2. Calculate priority score
  /// 3. Route to appropriate department
  /// 4. Assign to nearest office
  /// 5. Handle escalation if needed
  Future<ProcessingResult> processNewIssue(CivicIssue issue) async {
    AIAnalysis? aiAnalysis;

    // Step 1: AI Analysis
    try {
      aiAnalysis = await _aiService.analyzeImage(issue.imageUrl);
    } catch (e) {
      // Fall back to manual category if AI fails
      print('AI Analysis failed: $e');
      aiAnalysis = createDefaultAnalysis(issue.category);
    }

    // Step 2: Calculate Priority Score
    final priorityScore = _priorityCalculator.calculatePriorityScore(
      issue,
      aiAnalysis,
    );
    final isHighPriority = _priorityCalculator.isHighPriority(
      priorityScore,
      aiAnalysis,
    );

    // Step 3: Route to Department
    final category = aiAnalysis.detectedCategory;
    final department = _departmentRouter.mapCategoryToDepartment(category);

    // Step 4: Assign to Office
    AssignmentResult? assignmentResult;
    try {
      assignmentResult = await _officeAssigner.assignIssue(issue, department);
    } catch (e) {
      // Handle case where no office is available
      print('Warning: Could not assign office: $e');
    }

    // Step 5: Handle Escalation
    final escalationResult = await _escalationHandler.handleEscalation(
      issue,
      aiAnalysis,
    );

    // Calculate final priority score
    // Use escalation override if provided, otherwise use calculated score with boost
    final finalPriorityScore =
        escalationResult.priorityScore ??
        (priorityScore +
                _escalationHandler.getPriorityBoost(escalationResult.level))
            .clamp(0, 100);

    // Build the updated issue
    final processedIssue = issue.copyWith(
      category: category,
      aiAnalysis: aiAnalysis,
      priorityScore: finalPriorityScore,
      isHighPriority:
          isHighPriority ||
          (escalationResult.level == EscalationLevel.emergency) ||
          (escalationResult.level == EscalationLevel.highPriority),
      status: escalationResult.level == EscalationLevel.emergency
          ? IssueStatus.escalated
          : issue.status,
    );

    return ProcessingResult(
      issue: processedIssue,
      aiAnalysis: aiAnalysis,
      priorityScore: processedIssue.priorityScore,
      isHighPriority: processedIssue.isHighPriority,
      department: department,
      assignmentResult: assignmentResult,
      escalationResult: escalationResult,
    );
  }

  /// Recalculate priority for an existing issue.
  ///
  /// Called when:
  /// - New upvote received
  /// - Issue age crosses threshold
  /// - Related issues reported nearby
  /// - Manual admin override
  Future<int> recalculatePriority(CivicIssue issue) async {
    final newScore = _priorityCalculator.calculatePriorityScore(
      issue,
      issue.aiAnalysis,
    );
    return newScore;
  }

  /// Get the department for a given category.
  Department getDepartmentForCategory(String category) {
    return _departmentRouter.mapCategoryToDepartment(category);
  }

  /// Calculate chaos score for an analysis.
  double getChaosScore(AIAnalysis analysis) {
    return _chaosDetector.calculateChaosScore(analysis);
  }

  /// Get escalation level for a chaos score.
  EscalationLevel getEscalationLevel(double chaosScore) {
    return _escalationHandler.getEscalationLevel(chaosScore);
  }

  /// Check if an issue qualifies as high priority.
  bool checkHighPriority(int priorityScore, AIAnalysis? aiAnalysis) {
    return _priorityCalculator.isHighPriority(priorityScore, aiAnalysis);
  }
}

/// Result of processing a civic issue through the system.
class ProcessingResult {
  final CivicIssue issue;
  final AIAnalysis aiAnalysis;
  final int priorityScore;
  final bool isHighPriority;
  final Department department;
  final AssignmentResult? assignmentResult;
  final EscalationResult escalationResult;

  const ProcessingResult({
    required this.issue,
    required this.aiAnalysis,
    required this.priorityScore,
    required this.isHighPriority,
    required this.department,
    this.assignmentResult,
    required this.escalationResult,
  });

  @override
  String toString() {
    return 'ProcessingResult(\n'
        '  issue: ${issue.id},\n'
        '  priority: $priorityScore,\n'
        '  highPriority: $isHighPriority,\n'
        '  department: $department,\n'
        '  assigned: ${assignmentResult?.office.name ?? "N/A"},\n'
        '  escalation: ${escalationResult.level}\n'
        ')';
  }
}
