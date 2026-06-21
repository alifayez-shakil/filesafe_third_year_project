import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart';
import '../utils/models/notification_item.dart';

class NotificationProvider extends ChangeNotifier {
  List<NotificationItem> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = true;
  RealtimeChannel? _channel;

  List<NotificationItem> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  void startListening(String userId) {
    // ✅ Use Supabase.instance.client (not an undefined _supabase)
    _channel = Supabase.instance.client
        .channel('public:notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            final newRow = payload.newRecord as Map<String, dynamic>;
            if (newRow['user_id'] == userId) {
              final item = NotificationItem.fromMap(newRow);
              _notifications.insert(0, item);
              _unreadCount++;
              notifyListeners();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            final updatedRow = payload.newRecord as Map<String, dynamic>;
            final index = _notifications.indexWhere(
              (n) => n.id == updatedRow['id'],
            );
            if (index != -1) {
              _notifications[index] = NotificationItem.fromMap(updatedRow);
              _unreadCount = _notifications.where((n) => !n.isRead).length;
              notifyListeners();
            }
          },
        )
        .subscribe();
  }

  Future<void> loadNotifications() async {
    _isLoading = true;
    notifyListeners();
    try {
      _notifications = await NotificationService.getNotifications();
      _unreadCount = await NotificationService.getUnreadCount();
    } catch (e) {
      // Handle error silently
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> markAsRead(String notificationId) async {
    await NotificationService.markAsRead(notificationId);
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    if (_unreadCount == 0) return;
    await NotificationService.markAllAsRead();
    _notifications = _notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();
    _unreadCount = 0;
    notifyListeners();
  }

  Future<void> deleteNotification(String notificationId) async {
    await NotificationService.deleteNotification(notificationId);
    _notifications.removeWhere((n) => n.id == notificationId);
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    notifyListeners();
  }

  Future<void> deleteAllRead() async {
    await NotificationService.deleteAllRead();
    _notifications.removeWhere((n) => n.isRead);
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadNotifications();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
