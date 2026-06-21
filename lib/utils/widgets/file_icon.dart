import 'package:flutter/material.dart';
import '../models/file_item.dart';

class FileIcon extends StatelessWidget {
  final FileType type;
  final double size;

  const FileIcon({super.key, required this.type, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconData(type);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: size * 0.55),
    );
  }

  static (IconData, Color) _iconData(FileType type) {
    return switch (type) {
      FileType.image => (Icons.image_outlined, const Color(0xFF10B981)),
      FileType.pdf => (Icons.picture_as_pdf_outlined, const Color(0xFFEF4444)),
      FileType.document => (
        Icons.description_outlined,
        const Color(0xFF3B82F6),
      ),
      FileType.video => (Icons.videocam_outlined, const Color(0xFF8B5CF6)),
      FileType.audio => (Icons.music_note_outlined, const Color(0xFFF59E0B)),
      FileType.archive => (Icons.folder_zip_outlined, const Color(0xFF6B7280)),
      FileType.code => (Icons.code_rounded, const Color(0xFF0EA5E9)),
      FileType.spreadsheet => (
        Icons.table_chart_outlined,
        const Color(0xFF16A34A),
      ),
      FileType.other => (
        Icons.insert_drive_file_outlined,
        const Color(0xFF6B7280),
      ),
    };
  }
}
