/// Represents a file share record
class ShareItem {
  final String id;
  final String fileId;
  final String fileName;
  final String sharedByName;
  final String sharedWithEmail;
  final String permission;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isRevoked;

  ShareItem({
    required this.id,
    required this.fileId,
    required this.fileName,
    required this.sharedByName,
    required this.sharedWithEmail,
    required this.permission,
    required this.createdAt,
    this.expiresAt,
    this.isRevoked = false,
  });

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isActive => !isRevoked && !isExpired;

  factory ShareItem.fromMap(Map<String, dynamic> map) {
    final sender = map['sender'] as Map<String, dynamic>?;
    final senderName = sender?['full_name'] as String?;

    final file = map['file'] as Map<String, dynamic>?;
    final fileName = file?['name'] as String? ?? 'Unknown';
    final fallbackName = map['shared_by']?['email'] as String?;

    return ShareItem(
      id: map['id'] as String,
      fileId: map['file_id'] as String,
      fileName: fileName,
      sharedByName: senderName ?? fallbackName ?? 'Unknown',
      sharedWithEmail: map['shared_with_email'] as String? ?? '',
      permission: map['permission'] as String? ?? 'VIEW',
      createdAt: DateTime.parse(map['created_at'] as String),
      expiresAt: map['expires_at'] != null
          ? DateTime.parse(map['expires_at'] as String)
          : null,
      isRevoked: map['is_revoked'] as bool? ?? false,
    );
  }
}
