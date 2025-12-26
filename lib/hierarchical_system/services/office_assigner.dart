import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/civic_issue.dart';
import '../models/enums.dart';
import '../models/geo_point.dart';
import '../models/office.dart';

/// Assigns civic issues to the nearest appropriate government office.
class OfficeAssigner {
  final SupabaseClient? _supabase;

  OfficeAssigner({SupabaseClient? supabase}) : _supabase = supabase;

  /// Assign an issue to the nearest office.
  ///
  /// Process:
  /// 1. Find all offices of the department in the issue's district
  /// 2. If district offices exist, select the nearest one
  /// 3. If no district offices, escalate to state-level offices
  /// 4. Return assignment result with escalation status
  Future<AssignmentResult> assignIssue(
    CivicIssue issue,
    Department department,
  ) async {
    // First, try to find offices in the district
    final districtOffices = await findOffices(department, issue.district);

    if (districtOffices.isNotEmpty) {
      final nearestOffice = selectByDistance(districtOffices, issue.location);
      final distance = nearestOffice.location.distanceTo(issue.location);

      return AssignmentResult(
        office: nearestOffice,
        escalated: false,
        distance: distance,
      );
    }

    // No district offices found, escalate to state level
    final stateOffices = await findStateOffices(department, issue.state);

    if (stateOffices.isNotEmpty) {
      final nearestOffice = selectByDistance(stateOffices, issue.location);
      final distance = nearestOffice.location.distanceTo(issue.location);

      return AssignmentResult(
        office: nearestOffice,
        escalated: true,
        distance: distance,
      );
    }

    // No offices found at all - this shouldn't happen in production
    throw NoOfficeAvailableException(
      department: department,
      district: issue.district,
      state: issue.state,
    );
  }

  /// Find all offices of a department in a specific district.
  Future<List<Office>> findOffices(
    Department department,
    String district,
  ) async {
    if (_supabase == null) {
      // Return empty list if no Supabase client (for testing)
      return [];
    }

    try {
      final response = await _supabase
          .from('offices')
          .select()
          .eq('department', department.name)
          .eq('district', district)
          .eq('is_state_level', false);

      return (response as List)
          .map((json) => Office.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error finding offices: $e');
      return [];
    }
  }

  /// Find state-level offices for a department.
  Future<List<Office>> findStateOffices(
    Department department,
    String state,
  ) async {
    if (_supabase == null) {
      // Return empty list if no Supabase client (for testing)
      return [];
    }

    try {
      final response = await _supabase
          .from('offices')
          .select()
          .eq('department', department.name)
          .eq('state', state)
          .eq('is_state_level', true);

      return (response as List)
          .map((json) => Office.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error finding state offices: $e');
      return [];
    }
  }

  /// Select the nearest office from a list based on distance to a location.
  ///
  /// Uses the Haversine formula via GeoPoint.distanceTo() to calculate
  /// the distance between the issue location and each office.
  Office selectByDistance(List<Office> offices, GeoPoint location) {
    if (offices.isEmpty) {
      throw ArgumentError('Cannot select from empty office list');
    }

    Office nearestOffice = offices.first;
    double minDistance = nearestOffice.location.distanceTo(location);

    for (final office in offices.skip(1)) {
      final distance = office.location.distanceTo(location);
      if (distance < minDistance) {
        minDistance = distance;
        nearestOffice = office;
      }
    }

    return nearestOffice;
  }

  /// Calculate distance between two points (for external use).
  double calculateDistance(GeoPoint from, GeoPoint to) {
    return from.distanceTo(to);
  }
}

/// Exception thrown when no office is available for assignment.
class NoOfficeAvailableException implements Exception {
  final Department department;
  final String district;
  final String state;

  NoOfficeAvailableException({
    required this.department,
    required this.district,
    required this.state,
  });

  @override
  String toString() {
    return 'NoOfficeAvailableException: No office found for department '
        '${department.name} in district $district or state $state';
  }
}
