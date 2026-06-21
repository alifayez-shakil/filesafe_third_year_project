import 'package:flutter/material.dart';

/// Represents a single notification stored in the database.
class NotificationItem {
  final String id;
  final NotificationType type;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.type,
    required this.message,
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    return NotificationItem(
      id: map['id'] as String,
      type: NotificationType.fromString(map['type'] as String? ?? ''),
      message: map['message'] as String? ?? '',
      isRead: map['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.value,
      'message': message,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  NotificationItem copyWith({
    String? id,
    NotificationType? type,
    String? message,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      type: type ?? this.type,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ─── UI Helpers ──────────────────────────────────────────────

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  IconData get icon {
    switch (type) {
      case NotificationType.shareReceived:
        return Icons.folder_shared_rounded;
      case NotificationType.shareCreated:
        return Icons.link_rounded;
      case NotificationType.shareRevoked:
        return Icons.link_off_rounded;
      case NotificationType.uploadComplete:
        return Icons.cloud_done_rounded;
      case NotificationType.storageWarning:
        return Icons.warning_amber_rounded;
    }
  }

  Color get color {
    switch (type) {
      case NotificationType.shareReceived:
        return Colors.blue;
      case NotificationType.shareCreated:
        return Colors.green;
      case NotificationType.shareRevoked:
        return Colors.red;
      case NotificationType.uploadComplete:
        return Colors.teal;
      case NotificationType.storageWarning:
        return Colors.orange;
    }
  }
}

enum NotificationType {
  shareReceived('share_received'),
  shareCreated('share_created'),
  shareRevoked('share_revoked'),
  uploadComplete('upload_complete'),
  storageWarning('storage_warning');

  final String value;
  const NotificationType(this.value);

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationType.shareReceived,
    );
  }
}
