enum FileType {
  image,
  pdf,
  document,
  video,
  audio,
  archive,
  code,
  spreadsheet,
  other,
}

enum FileCategory { work, personal, media, code, archive, uncategorized }

class FileItem {
  final String id;
  String name;
  final FileType type;
  final int sizeBytes;
  final DateTime uploadedAt;
  final String uploadedBy;
  final String? folderId;
  bool isLocked;
  bool isStarred;
  bool isDeleted;
  DateTime? deletedAt;
  bool isDownloaded;
  String? localPath;
  String? aiSummary;

  FileItem({
    required this.id,
    required this.name,
    required this.type,
    required this.sizeBytes,
    required this.uploadedAt,
    required this.uploadedBy,
    this.folderId,
    this.isLocked = false,
    this.isStarred = false,
    this.isDeleted = false,
    this.deletedAt,
    this.isDownloaded = false,
    this.localPath,
    this.aiSummary,
  });

  factory FileItem.fromSupabase(Map<String, dynamic> json) {
    final mime = json['type'] as String? ?? '';
    final fileName = json['name'] as String? ?? '';
    final type = _parseType(mime, fileName: fileName);

    return FileItem(
      id: json['id'] as String,
      name: fileName,
      type: type,
      sizeBytes: (json['size'] as int?) ?? 0,
      uploadedAt: json['uploaded_at'] != null
          ? DateTime.parse(json['uploaded_at'] as String)
          : DateTime.now(),
      uploadedBy: '', // ← Note: Would need a join with profiles to populate
      folderId: json['folder_id'] as String?,
      isLocked: json['is_locked'] as bool? ?? false,
      isStarred: json['starred'] as bool? ?? false,
      isDeleted: json['is_deleted'] as bool? ?? false,
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'] as String)
          : null,
      isDownloaded: false,
      localPath: null,
    );
  }

  static FileType _parseType(String mime, {String fileName = ''}) {
    if (mime.startsWith('image/')) return FileType.image;
    if (mime.startsWith('audio/')) return FileType.audio;
    if (mime.startsWith('video/')) return FileType.video;
    if (mime == 'application/pdf') return FileType.pdf;
    if (mime.contains('spreadsheet') ||
        mime.contains('excel') ||
        mime.contains('csv')) {
      return FileType.spreadsheet;
    }
    if (mime.startsWith('text/x-') ||
        mime == 'application/javascript' ||
        mime == 'application/json' ||
        mime == 'application/xml') {
      return FileType.code;
    }
    if (mime.contains('zip') || mime.contains('archive')) {
      return FileType.archive;
    }

    // ── Extension fallback ──
    final ext = fileName.split('.').last.toLowerCase();
    if ([
      'dart',
      'java',
      'kt',
      'py',
      'js',
      'ts',
      'html',
      'css',
      'json',
      'xml',
      'yaml',
      'swift',
      'cpp',
      'c',
      'cs',
      'sql',
      'sh',
      'bash',
      'md',
    ].contains(ext)) {
      return FileType.code;
    }
    if (['csv', 'xls', 'xlsx'].contains(ext)) return FileType.spreadsheet;
    if (['m4a', 'mp3', 'wav', 'aac', 'flac', 'ogg'].contains(ext)) {
      return FileType.audio; // ✅ Added m4a
    }
    if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext)) {
      return FileType.video;
    }
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext)) {
      return FileType.image;
    }
    if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) {
      return FileType.archive;
    }

    return FileType.document;
  }

  String get sizeFormatted {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get extension =>
      name.contains('.') ? name.split('.').last.toLowerCase() : '';
  String get extensionUpper => extension.toUpperCase();

  // ── Category with better logic ──────────────────────
  FileCategory get category {
    // First, use the detected type
    switch (type) {
      case FileType.code:
        return FileCategory.code;
      case FileType.archive:
        return FileCategory.archive;
      case FileType.image:
      case FileType.video:
      case FileType.audio:
        return FileCategory.media;
      case FileType.pdf:
      case FileType.document:
      case FileType.spreadsheet:
        return FileCategory.work;
      default:
        break;
    }

    // Fallback: extension-based
    final ext = extension;
    final n = name.toLowerCase();

    if (['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'].contains(ext)) {
      return FileCategory.work;
    }
    if (n.contains('report') ||
        n.contains('budget') ||
        n.contains('invoice') ||
        n.contains('meeting') ||
        n.contains('project') ||
        n.contains('spec')) {
      return FileCategory.work;
    }
    if (n.contains('photo') ||
        n.contains('personal') ||
        n.contains('diary') ||
        n.contains('private')) {
      return FileCategory.personal;
    }

    return FileCategory.uncategorized;
  }

  // ── Auto-tags ────────────────────────────────────────
  List<String> get autoTags {
    final tags = <String>[];
    final ext = extension;
    final n = name.toLowerCase();

    if (['pdf', 'doc', 'docx'].contains(ext)) tags.add('Document');
    if (['xls', 'xlsx', 'csv'].contains(ext)) tags.add('Spreadsheet');
    if (['ppt', 'pptx'].contains(ext)) tags.add('Presentation');
    if (['mp4', 'mov', 'avi', 'mkv'].contains(ext)) tags.add('Video');
    if (['mp3', 'wav', 'aac', 'm4a', 'flac'].contains(ext)) tags.add('Audio');
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) tags.add('Image');
    if (['zip', 'rar', '7z'].contains(ext)) tags.add('Archive');
    if (n.contains('report')) tags.add('Report');
    if (n.contains('meeting') || n.contains('notes')) tags.add('Meeting');
    if (n.contains('budget') || n.contains('finance')) tags.add('Finance');
    if (isStarred) tags.add('Starred');
    if (DateTime.now().difference(uploadedAt).inDays < 7) tags.add('Recent');

    return tags.isEmpty ? ['General'] : tags;
  }
}
