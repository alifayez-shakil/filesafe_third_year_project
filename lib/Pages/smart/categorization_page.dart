import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/models/file_item.dart';
import '../../utils/widgets/file_icon.dart';

class CategorizationPage extends StatefulWidget {
  final List<FileItem> files;
  final void Function(FileItem) onOpen; // ← new: tap to open file
  const CategorizationPage({
    super.key,
    required this.files,
    required this.onOpen,
  });

  @override
  State<CategorizationPage> createState() => _CategorizationPageState();
}

class _CategorizationPageState extends State<CategorizationPage> {
  FileCategory? _sel;

  static const _meta = {
    FileCategory.work: _M('Work', Icons.work_outline, Color(0xFF3B82F6)),
    FileCategory.personal: _M(
      'Personal',
      Icons.person_outline,
      Color(0xFF10B981),
    ),
    FileCategory.media: _M(
      'Media',
      Icons.perm_media_outlined,
      Color(0xFF8B5CF6),
    ),
    FileCategory.code: _M('Code', Icons.code, Color(0xFFF59E0B)),
    FileCategory.archive: _M(
      'Archive',
      Icons.folder_zip_outlined,
      Color(0xFF6B7280),
    ),
    FileCategory.uncategorized: _M(
      'Other',
      Icons.help_outline,
      Color(0xFF9CA3AF),
    ),
  };

  List<FileItem> get _active =>
      widget.files.where((f) => !f.isDeleted).toList();

  Map<FileCategory, List<FileItem>> get _grouped {
    final m = <FileCategory, List<FileItem>>{};
    for (final f in _active) {
      m.putIfAbsent(f.category, () => []).add(f);
    }
    return m;
  }

  // ── Hero tag generator (same convention) ──────
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
    final grouped = _grouped;
    final filtered = _sel == null ? _active : (grouped[_sel] ?? []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Categories'),
        actions: [
          if (_sel != null)
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact(); // haptic on clear filter
                setState(() => _sel = null);
              },
              child: const Text(
                'Show All',
                style: TextStyle(color: Colors.amber),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: FileCategory.values.map((cat) {
                final m = _meta[cat]!;
                final count = grouped[cat]?.length ?? 0;
                if (count == 0) return const SizedBox.shrink();
                final active = _sel == cat;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact(); // haptic on chip
                    setState(() => _sel = active ? null : cat);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: active ? m.color : m.color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: active ? m.color : m.color.withOpacity(0.25),
                        width: active ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          m.icon,
                          color: active ? Colors.white : m.color,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          m.label,
                          style: TextStyle(
                            color: active ? Colors.white : m.color,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '$count files',
                          style: TextStyle(
                            color: active
                                ? Colors.white70
                                : m.color.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.category_outlined,
                          size: 60,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No files here',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final f = filtered[i];
                      final m = _meta[f.category]!;
                      return Hero(
                        tag: _heroTag(f),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              HapticFeedback.lightImpact(); // haptic on file tap
                              widget.onOpen(f);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  FileIcon(type: f.type),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          f.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 4,
                                          children: f.autoTags
                                              .take(4)
                                              .map(
                                                (t) => Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: m.color.withOpacity(
                                                      0.1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    t,
                                                    style: TextStyle(
                                                      color: m.color,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: m.color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(m.icon, color: m.color, size: 12),
                                        const SizedBox(width: 3),
                                        Text(
                                          m.label,
                                          style: TextStyle(
                                            color: m.color,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _M {
  final String label;
  final IconData icon;
  final Color color;
  const _M(this.label, this.icon, this.color);
}
