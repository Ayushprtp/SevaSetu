import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// Service for exporting performance reports in PDF/CSV formats
class ReportExportService {
  final SupabaseClient _supabase;

  ReportExportService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  /// Generate CSV report for issues
  Future<ExportResult> exportIssuesToCsv({
    String? state,
    String? department,
    String? officeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final issues = await _fetchIssues(
        state: state,
        department: department,
        officeId: officeId,
        startDate: startDate,
        endDate: endDate,
      );

      final csv = _generateCsv(issues);
      final file = await _saveToFile(csv, 'issues_report.csv');

      return ExportResult(success: true, filePath: file.path);
    } catch (e) {
      return ExportResult(success: false, error: 'Export failed: $e');
    }
  }

  /// Generate performance summary report
  Future<ExportResult> exportPerformanceReport({
    required String reportType, // 'state', 'department', 'office', 'worker'
    String? state,
    String? department,
    String? officeId,
    String? workerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final data = await _fetchPerformanceData(
        reportType: reportType,
        state: state,
        department: department,
        officeId: officeId,
        workerId: workerId,
        startDate: startDate,
        endDate: endDate,
      );

      final csv = _generatePerformanceCsv(data, reportType);
      final fileName = '${reportType}_performance_report.csv';
      final file = await _saveToFile(csv, fileName);

      return ExportResult(success: true, filePath: file.path);
    } catch (e) {
      return ExportResult(success: false, error: 'Export failed: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchIssues({
    String? state,
    String? department,
    String? officeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = _supabase.from('civic_issues').select('''
      id, category, description, address, status, priority_score,
      upvotes, created_at, updated_at, state, district,
      assigned_department, assigned_office_id, assigned_worker_id,
      is_high_priority, severity_level
    ''');

    if (state != null) query = query.eq('state', state);
    if (department != null) query = query.eq('assigned_department', department);
    if (officeId != null) query = query.eq('assigned_office_id', officeId);
    if (startDate != null) {
      query = query.gte('created_at', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('created_at', endDate.toIso8601String());
    }

    final response = await query.order('created_at', ascending: false);
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> _fetchPerformanceData({
    required String reportType,
    String? state,
    String? department,
    String? officeId,
    String? workerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Fetch aggregated performance data based on report type
    final issues = await _fetchIssues(
      state: state,
      department: department,
      officeId: officeId,
      startDate: startDate,
      endDate: endDate,
    );

    return _aggregatePerformanceData(issues, reportType);
  }

  Map<String, dynamic> _aggregatePerformanceData(
    List<Map<String, dynamic>> issues,
    String reportType,
  ) {
    final total = issues.length;
    final resolved = issues.where((i) => i['status'] == 'resolved').length;
    final pending = issues.where((i) => i['status'] == 'pending').length;
    final inProgress = issues.where((i) => i['status'] == 'in_progress').length;
    final highPriority = issues
        .where((i) => i['is_high_priority'] == true)
        .length;

    // Group by category
    final byCategory = <String, int>{};
    for (final issue in issues) {
      final cat = issue['category'] as String? ?? 'Unknown';
      byCategory[cat] = (byCategory[cat] ?? 0) + 1;
    }

    return {
      'total_issues': total,
      'resolved_issues': resolved,
      'pending_issues': pending,
      'in_progress_issues': inProgress,
      'high_priority_issues': highPriority,
      'resolution_rate': total > 0
          ? (resolved / total * 100).toStringAsFixed(1)
          : '0',
      'by_category': byCategory,
    };
  }

  String _generateCsv(List<Map<String, dynamic>> issues) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln(
      'ID,Category,Description,Address,Status,Priority Score,'
      'Upvotes,High Priority,Severity,State,District,Department,'
      'Created At,Updated At',
    );

    // Data rows
    for (final issue in issues) {
      buffer.writeln(
        [
          issue['id'],
          _escapeCsv(issue['category']),
          _escapeCsv(issue['description']),
          _escapeCsv(issue['address']),
          issue['status'],
          issue['priority_score'],
          issue['upvotes'],
          issue['is_high_priority'],
          issue['severity_level'],
          _escapeCsv(issue['state']),
          _escapeCsv(issue['district']),
          _escapeCsv(issue['assigned_department']),
          issue['created_at'],
          issue['updated_at'],
        ].join(','),
      );
    }

    return buffer.toString();
  }

  String _generatePerformanceCsv(Map<String, dynamic> data, String reportType) {
    final buffer = StringBuffer();

    buffer.writeln('Performance Report - ${reportType.toUpperCase()}');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('');
    buffer.writeln('Metric,Value');
    buffer.writeln('Total Issues,${data['total_issues']}');
    buffer.writeln('Resolved Issues,${data['resolved_issues']}');
    buffer.writeln('Pending Issues,${data['pending_issues']}');
    buffer.writeln('In Progress Issues,${data['in_progress_issues']}');
    buffer.writeln('High Priority Issues,${data['high_priority_issues']}');
    buffer.writeln('Resolution Rate,${data['resolution_rate']}%');
    buffer.writeln('');
    buffer.writeln('Issues by Category');

    final byCategory = data['by_category'] as Map<String, int>;
    for (final entry in byCategory.entries) {
      buffer.writeln('${entry.key},${entry.value}');
    }

    return buffer.toString();
  }

  String _escapeCsv(dynamic value) {
    if (value == null) return '';
    final str = value.toString();
    if (str.contains(',') || str.contains('"') || str.contains('\n')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }

  Future<File> _saveToFile(String content, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(content);
    return file;
  }
}

/// Result of export operation
class ExportResult {
  final bool success;
  final String? filePath;
  final String? error;

  ExportResult({required this.success, this.filePath, this.error});
}
