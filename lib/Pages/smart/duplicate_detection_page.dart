import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/models/file_item.dart';
import '../../utils/widgets/file_icon.dart';
import '../../utils/widgets/shimmer_loading.dart'; // adjust path

class DuplicateDetectionPage extends StatefulWidget {
  final List<FileItem> files;
  final void Function(FileItem) onDelete;
  const DuplicateDetectionPage({
    super.key,
    required this.files,
    required this.onDelete,
  });
  @override
  State<DuplicateDetectionPage> createState() => _DuplicateDetectionPageState();
}

class _DuplicateDetectionPageState extends State<DuplicateDetectionPage> {
  bool _scanning = true;
  final Set<String> _toDelete = {};

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _scanning = false);
    });
  }

  Map<String, List<FileItem>> get _nameDups {
    final map = <String, List<FileItem>>{};
    for (final f in widget.files.where((f) => !f.isDeleted)) {
      map.putIfAbsent(f.name.toLowerCase(), () => []).add(f);
    }
    return Map.fromEntries(map.entries.where((e) => e.value.length > 1));
  }

  Map<int, List<FileItem>> get _sizeDups {
    final map = <int, List<FileItem>>{};
    for (final f in widget.files.where((f) => !f.isDeleted)) {
      map.putIfAbsent(f.sizeBytes, () => []).add(f);
    }
    return Map.fromEntries(
      map.entries.where((e) => e.value.length > 1 && e.key > 0),
    );
  }

  int get _totalDups => _nameDups.values.fold(0, (s, g) => s + g.length - 1);

  int get _wastedBytes => _nameDups.values.fold(0, (s, g) {
    int w = 0;
    for (int i = 1; i < g.length; i++) {
      w += g[i].sizeBytes;
    }
    return s + w;
  });

  String _fmt(int b) {
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final nameDups = _nameDups;
    final sizeDups = _sizeDups;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duplicate Detection'),
        actions: [
          if (_toDelete.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: Text(
                'Delete ${_toDelete.length}',
                style: const TextStyle(color: Colors.red),
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                final count = _toDelete.length;
                for (final id in List.of(_toDelete)) {
                  FileItem? f;
                  try {
                    f = widget.files.firstWhere((f) => f.id == id);
                  } catch (_) {
                    continue;
                  }
                  if (f != null) {
                    widget.onDelete(f);
                  }
                }
                setState(() => _toDelete.clear());
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$count duplicates moved to Recycle Bin'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
        ],
      ),
      body: _scanning
          ? const DashboardShimmer()
          : (nameDups.isEmpty && sizeDups.isEmpty)
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No duplicates found!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All ${widget.files.length} files are unique',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_totalDups duplicate files found',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Wasting ${_fmt(_wastedBytes)} of storage',
                                style: TextStyle(
                                  color: Colors.orange[800],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (nameDups.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(
                          Icons.copy_outlined,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Same File Name',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${nameDups.length} groups',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...nameDups.entries.map(
                      (e) => _DupGroup(
                        label: e.key,
                        files: e.value,
                        selectedIds: _toDelete,
                        onToggle: (id) {
                          HapticFeedback.lightImpact(); // haptic on toggle
                          setState(
                            () => _toDelete.contains(id)
                                ? _toDelete.remove(id)
                                : _toDelete.add(id),
                          );
                        },
                      ),
                    ),
                  ],

                  if (sizeDups.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(
                          Icons.storage_outlined,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Same File Size',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Possible duplicates',
                            style: TextStyle(color: Colors.blue, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...sizeDups.entries.map(
                      (e) => _DupGroup(
                        label: 'Size: ${_fmt(e.key)}',
                        files: e.value,
                        selectedIds: _toDelete,
                        onToggle: (id) {
                          HapticFeedback.lightImpact(); // haptic on toggle
                          setState(
                            () => _toDelete.contains(id)
                                ? _toDelete.remove(id)
                                : _toDelete.add(id),
                          );
                        },
                        isSizeGroup: true,
                      ),
                    ),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}

class _DupGroup extends StatelessWidget {
  final String label;
  final List<FileItem> files;
  final Set<String> selectedIds;
  final void Function(String) onToggle;
  final bool isSizeGroup;
  const _DupGroup({
    required this.label,
    required this.files,
    required this.selectedIds,
    required this.onToggle,
    this.isSizeGroup = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSizeGroup
                      ? Icons.storage_outlined
                      : Icons.file_copy_outlined,
                  size: 14,
                  color: Colors.orange[700],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${files.length} copies',
                  style: TextStyle(color: Colors.orange[600], fontSize: 11),
                ),
              ],
            ),
          ),
          ...files.asMap().entries.map((e) {
            final isOrig = e.key == 0;
            final f = e.value;
            final sel = selectedIds.contains(f.id);
            return ListTile(
              dense: true,
              leading: FileIcon(type: f.type, size: 36),
              title: Text(
                f.name,
                style: TextStyle(
                  fontSize: 13,
                  color: sel ? Colors.red : null,
                  decoration: sel ? TextDecoration.lineThrough : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                isOrig
                    ? '✓ Original · ${f.sizeFormatted}'
                    : 'Copy · ${f.sizeFormatted}',
                style: TextStyle(
                  fontSize: 11,
                  color: isOrig ? Colors.green[600] : Colors.grey[500],
                ),
              ),
              trailing: isOrig
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Keep',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : Checkbox(
                      value: sel,
                      activeColor: Colors.red,
                      onChanged: (_) => onToggle(f.id),
                    ),
            );
          }),
        ],
      ),
    );
  }
}
