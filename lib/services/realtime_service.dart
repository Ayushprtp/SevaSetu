import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for real-time updates using Supabase Realtime
class RealtimeService {
  final SupabaseClient _supabase;
  final Map<String, RealtimeChannel> _channels = {};
  final Map<String, StreamController> _controllers = {};

  RealtimeService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  /// Subscribe to issue updates for a specific issue
  Stream<IssueUpdate> subscribeToIssue(String issueId) {
    final channelName = 'issue_$issueId';

    if (_controllers.containsKey(channelName)) {
      return (_controllers[channelName] as StreamController<IssueUpdate>)
          .stream;
    }

    final controller = StreamController<IssueUpdate>.broadcast();
    _controllers[channelName] = controller;

    final channel = _supabase.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'civic_issues',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: issueId,
          ),
          callback: (payload) {
            controller.add(
              IssueUpdate(
                type: UpdateType.statusChange,
                issueId: issueId,
                data: payload.newRecord,
                oldData: payload.oldRecord,
              ),
            );
          },
        )
        .subscribe();

    _channels[channelName] = channel;
    return controller.stream;
  }

  /// Subscribe to all issues in a specific area (for dashboard)
  Stream<IssueUpdate> subscribeToAreaIssues({
    String? state,
    String? department,
    String? officeId,
  }) {
    final channelName =
        'area_${state ?? 'all'}_${department ?? 'all'}_${officeId ?? 'all'}';

    if (_controllers.containsKey(channelName)) {
      return (_controllers[channelName] as StreamController<IssueUpdate>)
          .stream;
    }

    final controller = StreamController<IssueUpdate>.broadcast();
    _controllers[channelName] = controller;

    final channel = _supabase.channel(channelName);

    // Subscribe to inserts
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'civic_issues',
      callback: (payload) {
        final newRecord = payload.newRecord;
        // Filter by area if specified
        if (_matchesArea(newRecord, state, department, officeId)) {
          controller.add(
            IssueUpdate(
              type: UpdateType.newIssue,
              issueId: newRecord['id'] as String,
              data: newRecord,
            ),
          );
        }
      },
    );

    // Subscribe to updates
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'civic_issues',
      callback: (payload) {
        final newRecord = payload.newRecord;
        if (_matchesArea(newRecord, state, department, officeId)) {
          controller.add(
            IssueUpdate(
              type: UpdateType.statusChange,
              issueId: newRecord['id'] as String,
              data: newRecord,
              oldData: payload.oldRecord,
            ),
          );
        }
      },
    );

    channel.subscribe();
    _channels[channelName] = channel;
    return controller.stream;
  }

  /// Subscribe to worker's assigned issues
  Stream<IssueUpdate> subscribeToWorkerIssues(String workerId) {
    final channelName = 'worker_$workerId';

    if (_controllers.containsKey(channelName)) {
      return (_controllers[channelName] as StreamController<IssueUpdate>)
          .stream;
    }

    final controller = StreamController<IssueUpdate>.broadcast();
    _controllers[channelName] = controller;

    final channel = _supabase.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'civic_issues',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'assigned_worker_id',
            value: workerId,
          ),
          callback: (payload) {
            final type = payload.eventType == PostgresChangeEvent.insert
                ? UpdateType.newAssignment
                : UpdateType.statusChange;

            controller.add(
              IssueUpdate(
                type: type,
                issueId: payload.newRecord['id'] as String,
                data: payload.newRecord,
                oldData: payload.oldRecord,
              ),
            );
          },
        )
        .subscribe();

    _channels[channelName] = channel;
    return controller.stream;
  }

  /// Subscribe to notifications for current user
  Stream<NotificationUpdate> subscribeToNotifications() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return const Stream.empty();
    }

    final channelName = 'notifications_$userId';

    if (_controllers.containsKey(channelName)) {
      return (_controllers[channelName] as StreamController<NotificationUpdate>)
          .stream;
    }

    final controller = StreamController<NotificationUpdate>.broadcast();
    _controllers[channelName] = controller;

    final channel = _supabase.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            controller.add(
              NotificationUpdate(
                id: payload.newRecord['id'] as String,
                title: payload.newRecord['title'] as String,
                body: payload.newRecord['body'] as String,
                data: payload.newRecord['data'] as Map<String, dynamic>?,
                createdAt: DateTime.parse(
                  payload.newRecord['created_at'] as String,
                ),
              ),
            );
          },
        )
        .subscribe();

    _channels[channelName] = channel;
    return controller.stream;
  }

  /// Unsubscribe from a specific channel
  void unsubscribe(String channelName) {
    _channels[channelName]?.unsubscribe();
    _channels.remove(channelName);
    _controllers[channelName]?.close();
    _controllers.remove(channelName);
  }

  /// Unsubscribe from all channels
  void unsubscribeAll() {
    for (final channel in _channels.values) {
      channel.unsubscribe();
    }
    for (final controller in _controllers.values) {
      controller.close();
    }
    _channels.clear();
    _controllers.clear();
  }

  bool _matchesArea(
    Map<String, dynamic> record,
    String? state,
    String? department,
    String? officeId,
  ) {
    if (state != null && record['state'] != state) return false;
    if (department != null && record['assigned_department'] != department)
      return false;
    if (officeId != null && record['assigned_office_id'] != officeId)
      return false;
    return true;
  }

  void dispose() {
    unsubscribeAll();
  }
}

/// Types of issue updates
enum UpdateType { newIssue, statusChange, newAssignment, priorityChange }

/// Represents an issue update event
class IssueUpdate {
  final UpdateType type;
  final String issueId;
  final Map<String, dynamic> data;
  final Map<String, dynamic>? oldData;

  IssueUpdate({
    required this.type,
    required this.issueId,
    required this.data,
    this.oldData,
  });

  String? get newStatus => data['status'] as String?;
  String? get oldStatus => oldData?['status'] as String?;
  bool get statusChanged => oldStatus != null && newStatus != oldStatus;
}

/// Represents a notification update
class NotificationUpdate {
  final String id;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final DateTime createdAt;

  NotificationUpdate({
    required this.id,
    required this.title,
    required this.body,
    this.data,
    required this.createdAt,
  });
}
