import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/models/file_item.dart';
import '../../utils/widgets/file_icon.dart';

class RecycleBinPage extends StatefulWidget {
  final List<FileItem> files;
  final void Function(FileItem) onRestore;
  final void Function(FileItem) onPermanentDelete;
  const RecycleBinPage({
    super.key,
    required this.files,
    required this.onRestore,
    required this.onPermanentDelete,
  });
  @override
  State<RecycleBinPage> createState() => _RecycleBinPageState();
}

class _RecycleBinPageState extends State<RecycleBinPage> {
  List<FileItem> get _deleted =>
      widget.files.where((f) => f.isDeleted).toList()..sort(
        (a, b) => (b.deletedAt ?? DateTime.now()).compareTo(
          a.deletedAt ?? DateTime.now(),
        ),
      );

  String _ago(DateTime? dt) {
    if (dt == null) return 'Unknown';
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  void _emptyBin() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Empty Recycle Bin'),
        content: Text(
          'Permanently delete all ${_deleted.length} files? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              HapticFeedback.mediumImpact(); // haptic on empty bin
              Navigator.pop(context);
              for (final f in List.of(_deleted)) widget.onPermanentDelete(f);
              setState(() {});
            },
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deleted = _deleted;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Recycle Bin${deleted.isNotEmpty ? " (${deleted.length})" : ""}',
        ),
        actions: [
          if (deleted.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              label: const Text('Empty', style: TextStyle(color: Colors.red)),
              onPressed: _emptyBin,
            ),
        ],
      ),
      body: deleted.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.delete_outline,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Recycle bin is empty',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Deleted files appear here for 30 days',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.orange,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Files are permanently deleted after 30 days',
                          style: TextStyle(
                            color: Colors.orange[800],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: deleted.length,
                    itemBuilder: (_, i) {
                      final f = deleted[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          leading: Opacity(
                            opacity: 0.5,
                            child: FileIcon(type: f.type),
                          ),
                          title: Text(
                            f.name,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                              decoration: TextDecoration.lineThrough,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${f.sizeFormatted} · Deleted ${_ago(f.deletedAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.restore,
                                  color: Colors.green,
                                  size: 22,
                                ),
                                tooltip: 'Restore',
                                onPressed: () {
                                  HapticFeedback.lightImpact(); // haptic on restore
                                  widget.onRestore(f);
                                  setState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('"${f.name}" restored'),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_forever,
                                  color: Colors.red,
                                  size: 22,
                                ),
                                tooltip: 'Delete permanently',
                                onPressed: () {
                                  HapticFeedback.lightImpact(); // haptic on permanent delete
                                  widget.onPermanentDelete(f);
                                  setState(() {});
                                },
                              ),
                            ],
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
