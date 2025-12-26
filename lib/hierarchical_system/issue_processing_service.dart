import 'package:supabase_flutter/supabase_flutter.dart';
import 'hierarchical_system_service.dart';
import 'models/ai_analysis.dart';
import 'models/civic_issue.dart';
import 'models/geo_point.dart';

/// Service to integrate the hierarchical system with the Flutter UI.
/// Handles issue creation with AI analysis and priority calculation.
class IssueProcessingService {
  final HierarchicalSystemService _hierarchicalService;
  final SupabaseClient _supabase;

  IssueProcessingService({
    HierarchicalSystemService? hierarchicalService,
    SupabaseClient? supabase,
  }) : _hierarchicalService =
           hierarchicalService ??
           HierarchicalSystemService(supabase: Supabase.instance.client),
       _supabase = supabase ?? Supabase.instance.client;

  /// Create a new civic issue with AI analysis and automatic routing.
  Future<IssueCreationResult> createIssueWithAnalysis({
    required String userId,
    required String category,
    required String description,
    required double latitude,
    required double longitude,
    required String address,
    required String district,
    required String state,
    required List<String> mediaUrls,
    String? voiceNoteUrl,
  }) async {
    String? issueId;

    try {
      // Step 1: Create the issue first (without AI analysis)
      issueId =
          await _supabase.rpc(
                'create_civic_issue_v2',
                params: {
                  'p_user_id': userId,
                  'p_category': category,
                  'p_description': description,
                  'p_lat': latitude,
                  'p_lng': longitude,
                  'p_address': address,
                  'p_district': district,
                  'p_state': state,
                  'p_media_urls': mediaUrls,
                  'p_voice_note_url': voiceNoteUrl,
                  'p_ai_analysis': null,
                },
              )
              as String?;

      if (issueId == null) {
        throw Exception('Failed to create issue - no ID returned');
      }

      // Step 2: If we have media, analyze with AI
      AIAnalysis? aiAnalysis;
      if (mediaUrls.isNotEmpty) {
        try {
          // Create a temporary CivicIssue for processing
          final tempIssue = CivicIssue(
            id: issueId,
            category: category,
            description: description,
            location: GeoPoint(latitude: latitude, longitude: longitude),
            district: district,
            state: state,
            imageUrl: mediaUrls.first,
            upvotes: 0,
            status: IssueStatus.pending,
            createdAt: DateTime.now(),
          );

          // Process through hierarchical system
          final result = await _hierarchicalService.processNewIssue(tempIssue);
          aiAnalysis = result.aiAnalysis;

          // Step 3: Update the issue with AI analysis results
          await _supabase.rpc(
            'update_issue_ai_analysis',
            params: {
              'p_issue_id': issueId,
              'p_ai_analysis': aiAnalysis.toJson(),
              'p_priority_score': result.priorityScore,
              'p_is_high_priority': result.isHighPriority,
              'p_escalation_level': result.escalationResult.level.name,
            },
          );

          // Step 4: Assign to office if available
          if (result.assignmentResult != null) {
            await _supabase.rpc(
              'assign_issue_to_office',
              params: {
                'p_issue_id': issueId,
                'p_office_id': result.assignmentResult!.office.id,
                'p_escalated': result.assignmentResult!.escalated,
              },
            );
          }

          return IssueCreationResult(
            issueId: issueId,
            success: true,
            aiAnalysis: aiAnalysis,
            priorityScore: result.priorityScore,
            isHighPriority: result.isHighPriority,
            assignedDepartment: result.department.name,
            assignedOfficeName: result.assignmentResult?.office.name,
            escalationLevel: result.escalationResult.level.name,
          );
        } catch (aiError) {
          // AI analysis failed, but issue was created
          print('AI Analysis failed: $aiError');
          return IssueCreationResult(
            issueId: issueId,
            success: true,
            aiAnalysis: null,
            priorityScore: 50,
            isHighPriority: false,
            assignedDepartment: null,
            assignedOfficeName: null,
            escalationLevel: 'none',
            warning: 'Issue created but AI analysis failed: $aiError',
          );
        }
      }

      // No media - return basic result
      return IssueCreationResult(
        issueId: issueId,
        success: true,
        aiAnalysis: null,
        priorityScore: 50,
        isHighPriority: false,
        assignedDepartment: null,
        assignedOfficeName: null,
        escalationLevel: 'none',
      );
    } catch (e) {
      return IssueCreationResult(
        issueId: issueId,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Recalculate priority for an existing issue (e.g., after upvote).
  Future<void> recalculatePriority(String issueId) async {
    try {
      final response = await _supabase
          .from('civic_issues')
          .select()
          .eq('id', issueId)
          .single();

      final issue = _mapResponseToIssue(response);
      final newScore = await _hierarchicalService.recalculatePriority(issue);
      final isHighPriority = _hierarchicalService.checkHighPriority(
        newScore,
        issue.aiAnalysis,
      );

      await _supabase
          .from('civic_issues')
          .update({
            'priority_score': newScore,
            'is_high_priority': isHighPriority,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', issueId);
    } catch (e) {
      print('Error recalculating priority: $e');
      rethrow;
    }
  }

  CivicIssue _mapResponseToIssue(Map<String, dynamic> response) {
    double lat = 0, lng = 0;
    final location = response['location'] as String?;
    if (location != null) {
      final match = RegExp(r'POINT\(([^ ]+) ([^ ]+)\)').firstMatch(location);
      if (match != null) {
        lng = double.parse(match.group(1)!);
        lat = double.parse(match.group(2)!);
      }
    }

    AIAnalysis? aiAnalysis;
    final aiJson = response['ai_analysis'] as Map<String, dynamic>?;
    if (aiJson != null) {
      aiAnalysis = AIAnalysis.fromJson(aiJson);
    }

    final mediaFiles = response['media_files'] as List<dynamic>?;
    final statusStr = response['status'] as String? ?? 'pending';

    return CivicIssue(
      id: response['id'] as String,
      category: response['category'] as String? ?? 'OTHER',
      description: response['description'] as String? ?? '',
      location: GeoPoint(latitude: lat, longitude: lng),
      district: response['district'] as String? ?? '',
      state: response['state'] as String? ?? '',
      imageUrl: mediaFiles?.isNotEmpty == true
          ? mediaFiles!.first as String
          : '',
      upvotes: response['upvotes'] as int? ?? 0,
      priorityScore: response['priority_score'] as int? ?? 0,
      isHighPriority: response['is_high_priority'] as bool? ?? false,
      status: _parseStatus(statusStr),
      aiAnalysis: aiAnalysis,
      createdAt: DateTime.parse(response['created_at'] as String),
    );
  }

  IssueStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'assigned':
        return IssueStatus.assigned;
      case 'in_progress':
      case 'inprogress':
        return IssueStatus.inProgress;
      case 'resolved':
      case 'completed':
        return IssueStatus.resolved;
      case 'escalated':
        return IssueStatus.escalated;
      default:
        return IssueStatus.pending;
    }
  }
}

/// Result of creating an issue with AI analysis.
class IssueCreationResult {
  final String? issueId;
  final bool success;
  final AIAnalysis? aiAnalysis;
  final int? priorityScore;
  final bool? isHighPriority;
  final String? assignedDepartment;
  final String? assignedOfficeName;
  final String? escalationLevel;
  final String? error;
  final String? warning;

  IssueCreationResult({
    this.issueId,
    required this.success,
    this.aiAnalysis,
    this.priorityScore,
    this.isHighPriority,
    this.assignedDepartment,
    this.assignedOfficeName,
    this.escalationLevel,
    this.error,
    this.warning,
  });
}
