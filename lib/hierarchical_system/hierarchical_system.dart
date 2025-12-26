/// SevaSetu Hierarchical System
///
/// A comprehensive civic issue management system that combines:
/// - AI-powered image analysis for automatic categorization
/// - Multi-factor priority scoring algorithm
/// - Department routing based on issue category
/// - Office assignment with distance-based selection
/// - Emergency detection and escalation handling
///
/// Usage:
/// ```dart
/// import 'package:sevasetu/hierarchical_system/hierarchical_system.dart';
///
/// final service = HierarchicalSystemService(
///   aiService: GeminiAIAnalysisService(apiKey: 'your-api-key'),
///   supabase: Supabase.instance.client,
/// );
///
/// final result = await service.processNewIssue(issue);
/// print('Priority: ${result.priorityScore}');
/// print('Department: ${result.department}');
/// print('Assigned to: ${result.assignmentResult?.office.name}');
/// ```
library hierarchical_system;

// Models
export 'models/ai_analysis.dart';
export 'models/civic_issue.dart';
export 'models/enums.dart';
export 'models/geo_point.dart';
export 'models/office.dart';

// Services
export 'services/ai_analysis_service.dart';
export 'services/chaos_detector.dart';
export 'services/department_router.dart';
export 'services/escalation_handler.dart';
export 'services/office_assigner.dart';
export 'services/priority_calculator.dart';

// Main Service
export 'hierarchical_system_service.dart';

// UI Integration Service
export 'issue_processing_service.dart';
