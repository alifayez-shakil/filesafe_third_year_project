import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/models/file_item.dart';
import '../utils/models/file_response.dart';
import 'encryption_service.dart';

class FileService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const _bucket = 'files';

  static String get _userId {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    return user.id;
  }

  // ─── Sanitize file name ─────────────────────────────────────────
  /// Removes characters that are invalid on Windows/Linux/Android.
  static String _sanitizeFileName(String name) {
    // Invalid on Windows: \ / : * ? " < > |
    final invalidChars = RegExp(r'[\\/:*?"<>|]');
    String sanitized = name.replaceAll(invalidChars, '_');
    // Replace multiple underscores with single
    sanitized = sanitized.replaceAll(RegExp(r'_+'), '_');
    // Trim and limit length
    if (sanitized.length > 200) {
      sanitized = sanitized.substring(0, 200);
    }
    if (sanitized.isEmpty) {
      sanitized = 'file';
    }
    return sanitized;
  }

  // ── Get all non-deleted files ─────────────────────────────────
  static Future<List<FileItem>> getFiles() async {
    final data = await _supabase
        .from('files')
        .select()
        .eq('user_id', _userId)
        .eq('is_deleted', false)
        .order('uploaded_at', ascending: false);

    return (data as List<dynamic>)
        .map((e) => FileItem.fromSupabase(e as Map<String, dynamic>))
        .toList();
  }

  // ── Upload (encrypt → Storage → DB) ──────────────────────────
  static Future<void> uploadFile({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
    String? folderId,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    // Sanitize name for storage path, keep original for display
    final safeStorageName = _sanitizeFileName(fileName);
    final storagePath = '$userId/$safeStorageName';

    // 1. Encrypt
    final keyBytes = await EncryptionService.getRawKey();
    final encryptedBytes = EncryptionService.encryptBytes(
      bytes.toList(),
      keyBytes,
    );

    // 2. Upload to storage
    await _supabase.storage
        .from(_bucket)
        .uploadBinary(
          storagePath,
          encryptedBytes,
          fileOptions: const FileOptions(upsert: true),
        );

    // 3. Insert metadata – keep original fileName for display
    await _supabase.from('files').insert({
      'name': fileName,
      'stored_name': storagePath,
      'size': encryptedBytes.length,
      'type': mimeType ?? _guessMimeType(fileName),
      'user_id': userId,
      'folder_id': folderId,
      'uploaded_at': DateTime.now().toIso8601String(),
      'is_deleted': false,
      'starred': false,
      'encrypted': true,
    });
  }

  // ── Download + decrypt with fallback ──────────────────────────
  static Future<Uint8List> downloadFile(
    String fileId, {
    String? password, // optional password for fallback
  }) async {
    final record = await _supabase
        .from('files')
        .select('stored_name')
        .eq('id', fileId)
        .single();

    final storagePath = record['stored_name'] as String;

    final encryptedBytes = await _supabase.storage
        .from(_bucket)
        .download(storagePath);

    final keyBytes = await EncryptionService.getRawKey();

    // If password is provided, use fallback
    if (password != null && password.isNotEmpty) {
      return EncryptionService.decryptBytesWithFallback(
        encryptedBytes.toList(),
        keyBytes,
        password,
      );
    }

    // Otherwise, use the normal decryption
    return EncryptionService.decryptBytes(encryptedBytes.toList(), keyBytes);
  }

  // ─── Download file to temporary file (safe path) ─────────────
  static Future<String> downloadToTempFile(
    String fileId, {
    String? fileName,
    String? password, // pass the user's password
  }) async {
    final bytes = await downloadFile(fileId, password: password);
    final dir = await getTemporaryDirectory();

    String baseName = fileName ?? 'file';
    String ext = '';
    if (baseName.contains('.')) {
      ext = baseName.substring(baseName.lastIndexOf('.'));
      baseName = baseName.substring(0, baseName.lastIndexOf('.'));
    }
    // Sanitize the base name to remove invalid characters
    baseName = _sanitizeFileName(baseName);
    if (baseName.isEmpty) baseName = 'file';

    final unique =
        '${baseName}_${fileId}_${DateTime.now().microsecondsSinceEpoch}$ext';

    final file = File('${dir.path}/$unique');
    await file.writeAsBytes(bytes, flush: true);

    return file.path;
  }

  // ── Download shared file by storage path ─────────────────────
  static Future<Uint8List> downloadFileByPath(String storedName) async {
    final encryptedBytes = await _supabase.storage
        .from(_bucket)
        .download(storedName);
    final keyBytes = await EncryptionService.getRawKey();
    return EncryptionService.decryptBytes(encryptedBytes.toList(), keyBytes);
  }

  // ── Soft-delete ───────────────────────────────────────────────
  static Future<void> deleteFile(String fileId) async {
    await _supabase
        .from('files')
        .update({
          'is_deleted': true,
          'deleted_at': DateTime.now().toIso8601String(),
        })
        .eq('id', fileId);
  }

  // ── Permanent delete ─────────────────────────────────────────
  static Future<void> permanentDelete(String fileId) async {
    final record = await _supabase
        .from('files')
        .select('stored_name')
        .eq('id', fileId)
        .single();

    final storagePath = record['stored_name'] as String?;
    if (storagePath != null) {
      await _supabase.storage.from(_bucket).remove([storagePath]);
    }
    await _supabase.from('files').delete().eq('id', fileId);
  }

  // ── Rename ────────────────────────────────────────────────────
  static Future<void> renameFile(String fileId, String newName) async {
    await _supabase.from('files').update({'name': newName}).eq('id', fileId);
  }

  // ── Toggle star ───────────────────────────────────────────────
  static Future<void> toggleStar(String fileId) async {
    final record = await _supabase
        .from('files')
        .select('starred')
        .eq('id', fileId)
        .single();
    final current = record['starred'] as bool? ?? false;
    await _supabase
        .from('files')
        .update({'starred': !current})
        .eq('id', fileId);
  }

  // ── Restore from bin ──────────────────────────────────────────
  static Future<void> restoreFile(String fileId) async {
    await _supabase
        .from('files')
        .update({'is_deleted': false, 'deleted_at': null})
        .eq('id', fileId);
  }

  // ── Search ────────────────────────────────────────────────────
  static Future<List<FileItem>> searchFiles(String query) async {
    final data = await _supabase
        .from('files')
        .select()
        .eq('user_id', _userId)
        .eq('is_deleted', false)
        .ilike('name', '%$query%')
        .order('uploaded_at', ascending: false);
    return (data as List<dynamic>)
        .map((e) => FileItem.fromSupabase(e as Map<String, dynamic>))
        .toList();
  }

  // ── Update file content (re-encrypt) ─────────────────────────
  static Future<void> updateFileContent({
    required String fileId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    final keyBytes = await EncryptionService.getRawKey();
    final encryptedBytes = EncryptionService.encryptBytes(
      bytes.toList(),
      keyBytes,
    );
    final safeStorageName = _sanitizeFileName(fileName);
    final storagePath = '$userId/$safeStorageName';

    await _supabase.storage
        .from(_bucket)
        .uploadBinary(
          storagePath,
          encryptedBytes,
          fileOptions: const FileOptions(upsert: true),
        );

    await _supabase
        .from('files')
        .update({
          'size': encryptedBytes.length,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', fileId)
        .eq('user_id', userId);
  }

  // ── Get starred ───────────────────────────────────────────────
  static Future<List<FileItem>> getStarredFiles() async {
    final data = await _supabase
        .from('files')
        .select()
        .eq('user_id', _userId)
        .eq('starred', true)
        .eq('is_deleted', false)
        .order('uploaded_at', ascending: false);
    return (data as List<dynamic>)
        .map((e) => FileItem.fromSupabase(e as Map<String, dynamic>))
        .toList();
  }

  // ── Get files with FileResponse ──────────────────────────
  static Future<FileResponse<List<FileItem>>> getFilesSafe() async {
    try {
      final data = await _supabase
          .from('files')
          .select()
          .eq('user_id', _userId)
          .eq('is_deleted', false)
          .order('uploaded_at', ascending: false);

      final items = (data as List<dynamic>)
          .map((e) => FileItem.fromSupabase(e as Map<String, dynamic>))
          .toList();

      return FileResponse.ok(items);
    } catch (e) {
      return FileResponse.fail(e.toString());
    }
  }

  // ── Upload with FileResponse ──────────────────────────────
  static Future<FileResponse<void>> uploadFileSafe({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
    String? folderId,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not logged in');

      final safeStorageName = _sanitizeFileName(fileName);
      final storagePath = '$userId/$safeStorageName';

      final keyBytes = await EncryptionService.getRawKey();
      final encryptedBytes = EncryptionService.encryptBytes(
        bytes.toList(),
        keyBytes,
      );

      await _supabase.storage
          .from(_bucket)
          .uploadBinary(
            storagePath,
            encryptedBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      await _supabase.from('files').insert({
        'name': fileName,
        'stored_name': storagePath,
        'size': encryptedBytes.length,
        'type': mimeType ?? _guessMimeType(fileName),
        'user_id': userId,
        'folder_id': folderId,
        'uploaded_at': DateTime.now().toIso8601String(),
        'is_deleted': false,
        'starred': false,
        'encrypted': true,
      });

      return const FileResponse.ok(null);
    } catch (e) {
      return FileResponse.fail(e.toString());
    }
  }

  // ── MIME guesser ──────────────────────────────────────────────
  static String _guessMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    const map = {
      // ── Documents ──
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'txt': 'text/plain',
      'md': 'text/markdown',
      'rtf': 'application/rtf',
      'odt': 'application/vnd.oasis.opendocument.text',

      // ── Spreadsheets ──
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'csv': 'text/csv',
      'ods': 'application/vnd.oasis.opendocument.spreadsheet',

      // ── Presentations ──
      'ppt': 'application/vnd.ms-powerpoint',
      'pptx':
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'odp': 'application/vnd.oasis.opendocument.presentation',

      // ── Images ──
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'bmp': 'image/bmp',
      'svg': 'image/svg+xml',
      'ico': 'image/x-icon',
      'tiff': 'image/tiff',
      'tif': 'image/tiff',
      'heic': 'image/heic',
      'heif': 'image/heif',
      'avif': 'image/avif',

      // ── Videos ──
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'avi': 'video/x-msvideo',
      'mkv': 'video/x-matroska',
      'webm': 'video/webm',
      'wmv': 'video/x-ms-wmv',
      'flv': 'video/x-flv',
      'm4v': 'video/x-m4v',
      '3gp': 'video/3gpp',

      // ── Audio ──
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'm4a': 'audio/mp4',
      'aac': 'audio/aac',
      'flac': 'audio/flac',
      'ogg': 'audio/ogg',
      'opus': 'audio/opus',
      'wma': 'audio/x-ms-wma',
      'alac': 'audio/alac',

      // ── Archives ──
      'zip': 'application/zip',
      'rar': 'application/vnd.rar',
      '7z': 'application/x-7z-compressed',
      'tar': 'application/x-tar',
      'gz': 'application/gzip',
      'bz2': 'application/x-bzip2',
      'xz': 'application/x-xz',
      'tgz': 'application/gzip',
      'iso': 'application/x-iso9660-image',

      // ── Code ──
      'dart': 'text/x-dart',
      'py': 'text/x-python',
      'js': 'text/javascript',
      'mjs': 'text/javascript',
      'ts': 'text/typescript',
      'tsx': 'text/typescript-jsx',
      'jsx': 'text/jsx',
      'html': 'text/html',
      'htm': 'text/html',
      'css': 'text/css',
      'scss': 'text/x-scss',
      'sass': 'text/x-sass',
      'less': 'text/x-less',
      'json': 'application/json',
      'xml': 'application/xml',
      'yaml': 'application/x-yaml',
      'yml': 'application/x-yaml',
      'toml': 'application/toml',
      'sql': 'text/x-sql',
      'sh': 'text/x-shellscript',
      'bash': 'text/x-shellscript',
      'zsh': 'text/x-shellscript',
      'java': 'text/x-java',
      'kt': 'text/x-kotlin',
      'kts': 'text/x-kotlin-script',
      'groovy': 'text/x-groovy',
      'scala': 'text/x-scala',
      'go': 'text/x-go',
      'rs': 'text/x-rust',
      'cpp': 'text/x-c++src',
      'cc': 'text/x-c++src',
      'cxx': 'text/x-c++src',
      'c': 'text/x-csrc',
      'h': 'text/x-chdr',
      'hpp': 'text/x-c++hdr',
      'cs': 'text/x-csharp',
      'swift': 'text/x-swift',
      'rb': 'text/x-ruby',
      'php': 'text/x-php',
      'pl': 'text/x-perl',
      'lua': 'text/x-lua',
      'r': 'text/x-r',
      'dockerfile': 'text/x-dockerfile',
      'makefile': 'text/x-makefile',
      'cmake': 'text/x-cmake',
      'cmakelists': 'text/x-cmake',

      // ── Fonts ──
      'ttf': 'font/ttf',
      'otf': 'font/otf',
      'woff': 'font/woff',
      'woff2': 'font/woff2',

      // ── Other ──
      'epub': 'application/epub+zip',
      'mobi': 'application/x-mobipocket-ebook',
      'apk': 'application/vnd.android.package-archive',
      'ipa': 'application/iphone',
      'dmg': 'application/x-apple-diskimage',
      'exe': 'application/x-msdownload',
      'msi': 'application/x-msi',
      'deb': 'application/vnd.debian.binary-package',
      'rpm': 'application/x-rpm',
    };
    return map[ext] ?? 'application/octet-stream';
  }
}
