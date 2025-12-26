import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing push notifications
class PushNotificationService {
  final SupabaseClient _supabase;

  PushNotificationService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  /// Register device token for push notifications
  Future<void> registerDeviceToken(String token) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('device_tokens').upsert({
      'user_id': userId,
      'token': token,
      'platform': _getPlatform(),
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,token');
  }

  /// Unregister device token
  Future<void> unregisterDeviceToken(String token) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase
        .from('device_tokens')
        .delete()
        .eq('user_id', userId)
        .eq('token', token);
  }

  /// Send notification to a specific user
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _supabase.from('notifications').insert({
      'user_id': userId,
      'title': title,
      'body': body,
      'data': data,
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Notify worker of new assignment
  Future<void> notifyWorkerAssignment({
    required String workerId,
    required String issueId,
    required String issueCategory,
    required String issueAddress,
  }) async {
    await sendNotificationToUser(
      userId: workerId,
      title: 'New Issue Assigned',
      body: 'You have been assigned a $issueCategory issue at $issueAddress',
      data: {'type': 'assignment', 'issue_id': issueId},
    );
  }

  /// Notify citizen of status change
  Future<void> notifyCitizenStatusChange({
    required String citizenId,
    required String issueId,
    required String oldStatus,
    required String newStatus,
    required String issueCategory,
  }) async {
    final statusMessages = {
      'assigned': 'has been assigned to a worker',
      'in_progress': 'is now being worked on',
      'resolved': 'has been resolved',
      'escalated': 'has been escalated for priority handling',
    };

    final message = statusMessages[newStatus] ?? 'status has been updated';

    await sendNotificationToUser(
      userId: citizenId,
      title: 'Issue Update',
      body: 'Your $issueCategory issue $message',
      data: {
        'type': 'status_change',
        'issue_id': issueId,
        'old_status': oldStatus,
        'new_status': newStatus,
      },
    );
  }

  /// Get user's notifications
  Future<List<Map<String, dynamic>>> getNotifications({
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    var query = _supabase.from('notifications').select().eq('user_id', userId);

    if (unreadOnly) {
      query = query.eq('is_read', false);
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);
    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  /// Get unread notification count
  Future<int> getUnreadCount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    final response = await _supabase
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);

    return (response as List).length;
  }

  String _getPlatform() {
    // This would be determined by the platform
    return 'mobile';
  }
}
