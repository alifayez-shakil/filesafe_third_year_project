import 'package:flutter/material.dart';
import '../../../utils/models/file_item.dart';
import '../media/timeline_page.dart';
import '../media/image_gallery_page.dart';
import '../smart/categorization_page.dart';
import '../smart/storage_analyzer_page.dart';
import '../smart/recycle_bin_page.dart';
import '../smart/file_lock.dart';
import '../media/media_player_page.dart';
import '../media/text_editor_page.dart';
import '../account/setting_page.dart';
import '../smart/duplicate_detection_page.dart';
import '../sharing/shared_by_me.dart';
import '../sharing/shared_with_me.dart';

class ActionsTab extends StatelessWidget {
  final void Function(Widget) push;
  final List<FileItem> allFiles;
  final int binCount;
  final void Function(int) onNavigate;
  final void Function(FileItem) onOpen, onDelete;
  final void Function(FileItem) onRestore, onPermDelete;

  const ActionsTab({
    super.key,
    required this.push,
    required this.allFiles,
    required this.binCount,
    required this.onNavigate,
    required this.onOpen,
    required this.onDelete,
    required this.onRestore,
    required this.onPermDelete,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_ActionItem>[
      // ── Primary ────────────────
      _ActionItem(
        Icons.lock_person_rounded,
        'Locked\nFiles',
        Colors.red,
        () => push(FileLockPage()),
      ),
      _ActionItem(
        Icons.photo_library_rounded,
        'Gallery',
        Colors.pinkAccent,
        () => push(ImageGalleryPage(imageFiles: allFiles)),
      ),
      _ActionItem(
        Icons.timeline_rounded,
        'Timeline',
        Colors.greenAccent,
        () => push(TimelinePage(files: allFiles, onOpen: onOpen)),
      ),
      _ActionItem(
        Icons.upload_file_rounded,
        'Upload',
        const Color(0xFF3B82F6),
        () => onNavigate(1),
      ),
      _ActionItem(
        Icons.auto_awesome_rounded,
        'Smart\nSort',
        Colors.indigo,
        () => push(CategorizationPage(files: allFiles, onOpen: onOpen)),
      ),
      _ActionItem(
        Icons.pie_chart_rounded,
        'Storage',
        Colors.green,
        () => push(StorageAnalyzerPage(files: allFiles, onOpen: onOpen)),
      ),
      _ActionItem(
        binCount > 0
            ? Icons.delete_forever_rounded
            : Icons.delete_outline_rounded,
        'Bin',
        binCount > 0 ? Colors.red : Colors.grey,
        () => push(
          RecycleBinPage(
            files: allFiles,
            onRestore: onRestore,
            onPermanentDelete: onPermDelete,
          ),
        ),
      ),

      // ── Sharing ────────────────
      _ActionItem(
        Icons.link_rounded,
        'Open Shared\nLink',
        Colors.blue,
        () => push(SharedWithMePage()),
      ),
      _ActionItem(
        Icons.ios_share_rounded,
        'Shared\nBy Me',
        Colors.teal,
        () => push(SharedByMePage()),
      ),

      // ── Media & tools ──────────
      _ActionItem(Icons.headphones_rounded, 'Music', Colors.purple, () {
        final audioTracks = allFiles
            .where((f) => f.type == FileType.audio)
            .map(
              (f) => AudioTrack(
                title: f.name,
                artist: 'Unknown',
                filePath: f.id,
                isFileId: true,
              ),
            )
            .toList();
        if (audioTracks.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No audio files found')));
          return;
        }
        push(MediaPlayerPage(tracks: audioTracks));
      }),
      _ActionItem(
        Icons.edit_note_rounded,
        'Editor',
        Colors.orange,
        () => push(const TextEditorPage(fileName: 'new_note.txt')),
      ),
      _ActionItem(
        Icons.settings_rounded,
        'Settings',
        Colors.blueGrey,
        () => push(const SettingsPage()),
      ),
      _ActionItem(
        Icons.difference_rounded,
        'Duplicates',
        Colors.red,
        () => push(DuplicateDetectionPage(files: allFiles, onDelete: onDelete)),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'All Actions',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.95,
            ),
            itemBuilder: (context, index) => _actionCard(context, items[index]),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(BuildContext context, _ActionItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.color.withValues(alpha: isDark ? 0.15 : 0.12),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: item.onTap,
          splashColor: item.color.withValues(alpha: 0.1),
          highlightColor: item.color.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, color: item.color, size: 24),
                ),
                const SizedBox(height: 10),
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: isDark
                        ? item.color.withValues(alpha: 0.9)
                        : item.color.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionItem(this.icon, this.label, this.color, this.onTap);
}
