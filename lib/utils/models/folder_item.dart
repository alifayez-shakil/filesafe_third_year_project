class FolderItem {
  final String id;
  final String name;
  final DateTime createdAt;
  final int fileCount;
  final bool isLocked;

  FolderItem({
    required this.id,
    required this.name,
    required this.createdAt,
    this.fileCount = 0,
    this.isLocked = false,
  });

  factory FolderItem.fromMap(Map<String, dynamic> map) {
    return FolderItem(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      fileCount: map['file_count'] as int? ?? 0,
      isLocked: map['is_locked'] as bool? ?? false,
    );
  }

  FolderItem copyWith({bool? isLocked}) {
    return FolderItem(
      id: id,
      name: name,
      createdAt: createdAt,
      fileCount: fileCount,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}
