import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/models/notification_item.dart';

class NotificationService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static String get _userId {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    return user.id;
  }

  static Future<List<NotificationItem>> getNotifications() async {
    final data = await _supabase
        .from('notifications')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false);
    return (data as List<dynamic>)
        .map((e) => NotificationItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  static Future<int> getUnreadCount() async {
    final response = await _supabase
        .from('notifications')
        .select('id')
        .eq('user_id', _userId)
        .eq('is_read', false)
        .count();
    return (response as dynamic).count ?? 0;
  }

  static Future<void> markAsRead(String notificationId) async {
    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId)
        .eq('user_id', _userId);
  }

  static Future<void> markAllAsRead() async {
    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', _userId)
        .eq('is_read', false);
  }

  static Future<void> deleteNotification(String notificationId) async {
    await _supabase
        .from('notifications')
        .delete()
        .eq('id', notificationId)
        .eq('user_id', _userId);
  }

  static Future<void> deleteAllRead() async {
    await _supabase
        .from('notifications')
        .delete()
        .eq('user_id', _userId)
        .eq('is_read', true);
  }

  static Future<void> createNotification({
    required NotificationType type,
    required String message,
  }) async {
    await _supabase.from('notifications').insert({
      'user_id': _userId,
      'type': type.value,
      'message': message,
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> createNotificationForUser({
    required String userId,
    required NotificationType type,
    required String message,
  }) async {
    await _supabase.from('notifications').insert({
      'user_id': userId,
      'type': type.value,
      'message': message,
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
