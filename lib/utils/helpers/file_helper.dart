import 'dart:convert';

/// File‑related utility helpers (sizes, types, icons).
class FileHelper {
  FileHelper._();

  // ── File size formatting ───────────────────────────────
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  // ── MIME type guesser ─────────────────────────────────
  static String guessMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'aac':
        return 'audio/aac';
      case 'zip':
        return 'application/zip';
      case '7z':
        return 'application/x-7z-compressed';
      case 'rar':
        return 'application/x-rar-compressed';
      case 'csv':
        return 'text/csv';
      case 'txt':
        return 'text/plain';
      // ── New additions ──
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'json':
        return 'application/json';
      case 'html':
        return 'text/html';
      case 'css':
        return 'text/css';
      case 'dart':
        return 'text/x-dart';
      case 'md':
        return 'text/markdown';
      case 'ts':
        return 'text/typescript';
      case 'xml':
        return 'application/xml';
      case 'yaml':
      case 'yml':
        return 'application/x-yaml';
      default:
        return 'application/octet-stream';
    }
  }

  // ── File type icon (emoji) ────────────────────────────
  static String fileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'bmp'].contains(ext))
      return '🖼️';
    if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext)) return '🎬';
    if (['mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a'].contains(ext)) return '🎵';
    if (ext == 'pdf') return '📕';
    if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) return '🗜️';
    if (['xls', 'xlsx', 'csv'].contains(ext)) return '📊';
    // ✅ FIXED: PowerPoint uses presentation emoji, not spreadsheet
    if (['ppt', 'pptx'].contains(ext)) return '📑';
    if (['doc', 'docx'].contains(ext)) return '📝';
    if ([
      'dart',
      'java',
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
      'kt',
      'sql',
      'sh',
      'bash',
      'md',
    ].contains(ext))
      return '💻';
    return '📄';
  }

  // ── File extension from name ───────────────────────────
  static String extension(String fileName) {
    return fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
  }

  // ── Byte-level type detection ─────────────────────────
  static String detectTypeFromBytes(List<int> bytes) {
    if (bytes.length < 4) return 'unknown';

    // PDF
    if (bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46)
      return 'pdf';
    // PNG
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47)
      return 'png';
    // JPEG
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return 'jpg';
    // GIF
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return 'gif';
    // BMP
    if (bytes[0] == 0x42 && bytes[1] == 0x4D) return 'bmp';

    // ── MP4 / MOV (ftyp box at offset 4) – with error handling ──
    if (bytes.length > 8) {
      try {
        final ftyp = String.fromCharCodes(bytes.sublist(4, 8));
        if (['ftyp', 'moov', 'free', 'mdat'].contains(ftyp)) return 'mp4';
      } catch (_) {
        // Not valid UTF-8 – fall through
      }
    }

    // MP3 — ID3 header or sync bytes
    if (bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) return 'mp3';
    if (bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0) return 'mp3';

    // WAV — RIFF header
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46)
      return 'wav';

    // ZIP (also .xlsx, .docx, .pptx internally)
    if (bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04) {
      return 'zip';
    }

    // Text (UTF-8)
    try {
      final sample = bytes.length < 512 ? bytes.length : 512;
      utf8.decode(bytes.sublist(0, sample));
      return 'text';
    } catch (_) {}

    return 'unknown';
  }
}
