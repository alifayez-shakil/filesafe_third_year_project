class UserProfile {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final int storageUsed;
  final int quotaBytes;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    required this.storageUsed,
    required this.quotaBytes,
    required this.createdAt,
  });

  double get storagePercent => storageUsed / quotaBytes;
  String get storageFormatted => '${_fmt(storageUsed)} / ${_fmt(quotaBytes)}';
  bool get isNearLimit => storagePercent > 0.8;

  static String _fmt(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      fullName: map['full_name'] as String? ?? '',
      avatarUrl: map['avatar_url'] as String?,
      storageUsed: (map['storage_used'] as int?) ?? 0,
      quotaBytes: (map['quota_bytes'] as int?) ?? 1073741824,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
