import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Custom exception for ZIP-specific errors.
class ZipException implements Exception {
  final String message;
  const ZipException(this.message);
  @override
  String toString() => 'ZipException: $message';
}

class ZipService {
  static const int maxExtractionSize = 500 * 1024 * 1024; // 500 MB limit

  /// Create a ZIP archive from a map of file names to their raw bytes.
  static Uint8List createZip(Map<String, Uint8List> files) {
    if (files.isEmpty) {
      throw const ZipException('No files provided to create ZIP.');
    }

    final archive = Archive();
    for (final entry in files.entries) {
      final fileName = _sanitizeFileName(entry.key);
      final bytes = entry.value;
      final archiveFile = ArchiveFile(fileName, bytes.length, bytes);
      archive.addFile(archiveFile);
    }

    final encoder = ZipEncoder();
    final encoded = encoder.encode(archive);
    if (encoded == null) {
      throw const ZipException('Failed to encode ZIP archive.');
    }
    return Uint8List.fromList(encoded);
  }

  /// Extract all files from a ZIP archive (bytes).
  /// Optionally reports progress via [onProgress].
  static Future<Map<String, Uint8List>> extractFilesFromBytes(
    Uint8List bytes, {
    void Function(int total, int extracted)? onProgress,
  }) async {
    if (bytes.isEmpty) {
      throw const ZipException('ZIP file is empty or corrupted.');
    }

    if (bytes.length > maxExtractionSize) {
      throw ZipException(
        'ZIP file exceeds maximum allowed size (${maxExtractionSize ~/ (1024 * 1024)} MB).',
      );
    }

    try {
      final decoder = ZipDecoder();
      final archive = decoder.decodeBytes(bytes);

      if (archive.isEmpty) {
        throw const ZipException('ZIP archive contains no files.');
      }

      final extracted = <String, Uint8List>{};
      int count = 0;
      final total = archive.where((f) => f.isFile).length;

      for (final file in archive) {
        if (!file.isFile) continue;

        final name = _sanitizeFileName(file.name);
        // Skip empty file names
        if (name.isEmpty) continue;

        // Skip files with suspicious size (0 bytes)
        if (file.size == 0) continue;

        extracted[name] = Uint8List.fromList(file.content as List<int>);
        count++;

        if (onProgress != null) {
          onProgress(total, count);
        }
      }

      return extracted;
    } on ArchiveException catch (e) {
      throw ZipException('Failed to decompress ZIP file: ${e.message}');
    } catch (e) {
      throw ZipException('Unexpected error: $e');
    }
  }

  /// Extract all files from a ZIP archive on disk.
  static Future<Map<String, Uint8List>> extractFilesFromPath(
    String zipPath, {
    void Function(int total, int extracted)? onProgress,
  }) async {
    try {
      final file = File(zipPath);
      if (!await file.exists()) {
        throw ZipException('ZIP file not found: $zipPath');
      }

      final bytes = await file.readAsBytes();
      return extractFilesFromBytes(bytes, onProgress: onProgress);
    } catch (e) {
      if (e is ZipException) rethrow;
      throw ZipException('Failed to read ZIP file: $e');
    }
  }

  /// Sanitise file name to prevent path traversal attacks.
  static String _sanitizeFileName(String name) {
    // Remove any leading path separators or ".."
    var sanitized = name
        .replaceAll(RegExp(r'^(\.\.?)[\\/]+'), '')
        .replaceAll(RegExp(r'[\\/]+\.\.?[\\/]+'), '/');

    sanitized = sanitized.replaceAll('\\', '/');

    while (sanitized.startsWith('/')) {
      sanitized = sanitized.substring(1);
    }

    if (sanitized.isEmpty) {
      sanitized = 'unnamed_file';
    }

    return sanitized;
  }
}
