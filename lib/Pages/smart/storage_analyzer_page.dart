import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/models/file_item.dart';
import '../../utils/widgets/file_icon.dart';

class StorageAnalyzerPage extends StatelessWidget {
  final List<FileItem> files;
  final void Function(FileItem)? onOpen; // ← optional: open file from the list

  const StorageAnalyzerPage({super.key, required this.files, this.onOpen});

  static const _colors = {
    FileType.pdf: Color(0xFFEF4444),
    FileType.image: Color(0xFF10B981),
    FileType.document: Color(0xFF3B82F6),
    FileType.video: Color(0xFF8B5CF6),
    FileType.audio: Color(0xFFF59E0B),
    FileType.archive: Color(0xFF6B7280),
    FileType.other: Color(0xFF9CA3AF),
  };

  static const _labels = {
    FileType.pdf: 'PDFs',
    FileType.image: 'Images',
    FileType.document: 'Documents',
    FileType.video: 'Videos',
    FileType.audio: 'Audio',
    FileType.archive: 'Archives',
    FileType.other: 'Other',
  };

  String _fmt(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1024 * 1024 * 1024)
      return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  // Hero tag generator (consistent with other pages)
  String _heroTag(FileItem file) {
    switch (file.type) {
      case FileType.image:
        return 'image-${file.name}';
      case FileType.video:
        return 'video-${file.name}';
      case FileType.pdf:
        return 'pdf-${file.name}';
      case FileType.document:
        return 'text-${file.name}';
      case FileType.audio:
        return 'audio-${file.name}';
      default:
        return 'file-${file.name}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = files.where((f) => !f.isDeleted).toList();
    final total = active.fold<int>(0, (s, f) => s + f.sizeBytes);

    final byType = <FileType, List<FileItem>>{};
    for (final f in active) {
      byType.putIfAbsent(f.type, () => []).add(f);
    }
    final sorted = byType.entries.toList()
      ..sort(
        (a, b) => b.value
            .fold<int>(0, (s, f) => s + f.sizeBytes)
            .compareTo(a.value.fold<int>(0, (s, f) => s + f.sizeBytes)),
      );

    return Scaffold(
      appBar: AppBar(title: const Text('Storage Analyzer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero card – total storage
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Storage Used',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _fmt(total),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${active.length} files',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      children: sorted.map((e) {
                        final bytes = e.value.fold<int>(
                          0,
                          (s, f) => s + f.sizeBytes,
                        );
                        final pct = total > 0 ? bytes / total : 0.0;
                        if (pct < 0.01) return const SizedBox.shrink();
                        return Expanded(
                          flex: (pct * 1000).round(),
                          child: Container(
                            height: 10,
                            color: _colors[e.key] ?? Colors.grey,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Breakdown by Type',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),

            ...sorted.map((e) {
              final bytes = e.value.fold<int>(0, (s, f) => s + f.sizeBytes);
              final pct = total > 0 ? bytes / total : 0.0;
              final color = _colors[e.key] ?? Colors.grey;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        FileIcon(type: e.key, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _labels[e.key] ?? 'Other',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _fmt(bytes),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    '${e.value.length} files',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${(pct * 100).toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: color.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 8),
            const Text(
              'Largest Files',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),

            // Largest files list – tappable with Hero & haptic
            ...(List.of(active)
                  ..sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes)))
                .take(5)
                .map(
                  (f) => Hero(
                    tag: _heroTag(f),
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        leading: FileIcon(type: f.type),
                        title: Text(
                          f.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          f.sizeFormatted,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: onOpen == null
                            ? null
                            : () {
                                HapticFeedback.lightImpact(); // haptic
                                onOpen!(f);
                              },
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
