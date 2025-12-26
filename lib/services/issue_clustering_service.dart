import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for automatic issue clustering based on proximity and similarity
class IssueClusteringService {
  final SupabaseClient _supabase;

  /// Default cluster radius in meters
  static const double defaultClusterRadius = 50.0;

  /// Maximum cluster radius in meters
  static const double maxClusterRadius = 200.0;

  IssueClusteringService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  /// Find or create cluster for a new issue
  Future<ClusterResult> processNewIssue(String issueId) async {
    try {
      // Get issue details
      final issue = await _getIssueDetails(issueId);
      if (issue == null) {
        return ClusterResult(success: false, error: 'Issue not found');
      }

      final location = _parseLocation(issue['location'] as String?);
      if (location == null) {
        return ClusterResult(success: false, error: 'Issue has no location');
      }

      final category = issue['category'] as String;

      // Find nearby similar issues
      final nearbyIssues = await _findNearbyIssues(
        latitude: location['latitude']!,
        longitude: location['longitude']!,
        category: category,
        excludeIssueId: issueId,
        radiusMeters: maxClusterRadius,
      );

      if (nearbyIssues.isEmpty) {
        // No nearby issues, create new cluster with this issue as primary
        final clusterId = await _createCluster(issueId);
        return ClusterResult(
          success: true,
          clusterId: clusterId,
          isNewCluster: true,
          clusterSize: 1,
        );
      }

      // Check if any nearby issue is already in a cluster
      final existingCluster = await _findExistingCluster(nearbyIssues);

      if (existingCluster != null) {
        // Add to existing cluster
        await _addToCluster(existingCluster, issueId);
        final clusterSize = await _getClusterSize(existingCluster);

        // Update priority scores for all issues in cluster
        await _updateClusterPriorities(existingCluster);

        return ClusterResult(
          success: true,
          clusterId: existingCluster,
          isNewCluster: false,
          clusterSize: clusterSize,
        );
      }

      // Create new cluster with this issue and nearest similar issue
      final nearestIssue = nearbyIssues.first;
      final clusterId = await _createCluster(issueId);
      await _addToCluster(clusterId, nearestIssue['id'] as String);

      return ClusterResult(
        success: true,
        clusterId: clusterId,
        isNewCluster: true,
        clusterSize: 2,
      );
    } catch (e) {
      return ClusterResult(success: false, error: 'Error processing issue: $e');
    }
  }

  /// Get all clusters with their issues
  Future<List<IssueCluster>> getClusters({
    String? category,
    String? status,
    int limit = 50,
  }) async {
    try {
      var query = _supabase
          .from('issue_clusters')
          .select('''
            id,
            primary_issue_id,
            cluster_radius,
            created_at,
            cluster_members(
              issue_id,
              civic_issues(
                id, category, description, address, status, 
                priority_score, upvotes, location, created_at
              )
            )
          ''')
          .order('created_at', ascending: false)
          .limit(limit);

      final response = await query;

      return (response as List).map((data) {
        final members = (data['cluster_members'] as List)
            .map((m) => m['civic_issues'] as Map<String, dynamic>)
            .toList();

        return IssueCluster(
          id: data['id'] as String,
          primaryIssueId: data['primary_issue_id'] as String,
          radius: (data['cluster_radius'] as num).toDouble(),
          createdAt: DateTime.parse(data['created_at'] as String),
          issues: members,
        );
      }).toList();
    } catch (e) {
      print('Error getting clusters: $e');
      return [];
    }
  }

  /// Get cluster details by ID
  Future<IssueCluster?> getClusterDetails(String clusterId) async {
    try {
      final response = await _supabase
          .from('issue_clusters')
          .select('''
            id,
            primary_issue_id,
            cluster_radius,
            created_at,
            cluster_members(
              issue_id,
              civic_issues(
                id, category, description, address, status, 
                priority_score, upvotes, location, created_at, media_files
              )
            )
          ''')
          .eq('id', clusterId)
          .single();

      final members = (response['cluster_members'] as List)
          .map((m) => m['civic_issues'] as Map<String, dynamic>)
          .toList();

      return IssueCluster(
        id: response['id'] as String,
        primaryIssueId: response['primary_issue_id'] as String,
        radius: (response['cluster_radius'] as num).toDouble(),
        createdAt: DateTime.parse(response['created_at'] as String),
        issues: members,
      );
    } catch (e) {
      print('Error getting cluster details: $e');
      return null;
    }
  }

  /// Get cluster for a specific issue
  Future<String?> getIssueCluster(String issueId) async {
    try {
      final response = await _supabase
          .from('cluster_members')
          .select('cluster_id')
          .eq('issue_id', issueId)
          .maybeSingle();

      return response?['cluster_id'] as String?;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getIssueDetails(String issueId) async {
    try {
      return await _supabase
          .from('civic_issues')
          .select('id, category, location, status')
          .eq('id', issueId)
          .single();
    } catch (e) {
      return null;
    }
  }

  Map<String, double>? _parseLocation(String? location) {
    if (location == null) return null;
    final regex = RegExp(r'POINT\(([^ ]+) ([^ ]+)\)');
    final match = regex.firstMatch(location);
    if (match == null) return null;
    return {
      'longitude': double.parse(match.group(1)!),
      'latitude': double.parse(match.group(2)!),
    };
  }

  Future<List<Map<String, dynamic>>> _findNearbyIssues({
    required double latitude,
    required double longitude,
    required String category,
    required String excludeIssueId,
    required double radiusMeters,
  }) async {
    try {
      final response = await _supabase.rpc(
        'find_nearby_similar_issues',
        params: {
          'p_lat': latitude,
          'p_lng': longitude,
          'p_category': category,
          'p_exclude_id': excludeIssueId,
          'p_radius_meters': radiusMeters,
        },
      );
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      // Fallback: get all issues of same category and filter manually
      final response = await _supabase
          .from('civic_issues')
          .select('id, location, category')
          .eq('category', category)
          .neq('id', excludeIssueId)
          .neq('status', 'resolved');

      return (response as List).cast<Map<String, dynamic>>().where((issue) {
        final loc = _parseLocation(issue['location'] as String?);
        if (loc == null) return false;
        final distance = _calculateDistance(
          latitude,
          longitude,
          loc['latitude']!,
          loc['longitude']!,
        );
        return distance <= radiusMeters;
      }).toList();
    }
  }

  Future<String?> _findExistingCluster(
    List<Map<String, dynamic>> issues,
  ) async {
    for (final issue in issues) {
      final clusterId = await getIssueCluster(issue['id'] as String);
      if (clusterId != null) return clusterId;
    }
    return null;
  }

  Future<String> _createCluster(String primaryIssueId) async {
    final response = await _supabase
        .from('issue_clusters')
        .insert({
          'primary_issue_id': primaryIssueId,
          'cluster_radius': defaultClusterRadius.toInt(),
        })
        .select('id')
        .single();

    final clusterId = response['id'] as String;
    await _addToCluster(clusterId, primaryIssueId);
    return clusterId;
  }

  Future<void> _addToCluster(String clusterId, String issueId) async {
    await _supabase.from('cluster_members').upsert({
      'cluster_id': clusterId,
      'issue_id': issueId,
    }, onConflict: 'cluster_id,issue_id');
  }

  Future<int> _getClusterSize(String clusterId) async {
    final response = await _supabase
        .from('cluster_members')
        .select('issue_id')
        .eq('cluster_id', clusterId);
    return (response as List).length;
  }

  Future<void> _updateClusterPriorities(String clusterId) async {
    // Get all issues in cluster
    final members = await _supabase
        .from('cluster_members')
        .select('issue_id')
        .eq('cluster_id', clusterId);

    final clusterSize = (members as List).length;
    final clusterBonus = clusterSize * 5; // 5 points per clustered issue

    // Update priority for each issue
    for (final member in members) {
      await _supabase.rpc(
        'boost_issue_priority',
        params: {'p_issue_id': member['issue_id'], 'p_bonus': clusterBonus},
      );
    }
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;
}

/// Result of cluster processing
class ClusterResult {
  final bool success;
  final String? clusterId;
  final bool isNewCluster;
  final int clusterSize;
  final String? error;

  ClusterResult({
    required this.success,
    this.clusterId,
    this.isNewCluster = false,
    this.clusterSize = 0,
    this.error,
  });
}

/// Represents a cluster of related issues
class IssueCluster {
  final String id;
  final String primaryIssueId;
  final double radius;
  final DateTime createdAt;
  final List<Map<String, dynamic>> issues;

  IssueCluster({
    required this.id,
    required this.primaryIssueId,
    required this.radius,
    required this.createdAt,
    required this.issues,
  });

  int get size => issues.length;

  int get totalUpvotes =>
      issues.fold(0, (sum, issue) => sum + (issue['upvotes'] as int? ?? 0));

  int get highestPriority => issues.fold(0, (max, issue) {
    final score = issue['priority_score'] as int? ?? 0;
    return score > max ? score : max;
  });
}
