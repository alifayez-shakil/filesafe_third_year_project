import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../utils/models/file_item.dart';
import '../../../utils/widgets/file_icon.dart';
import '../../../utils/helpers/date_helper.dart';
import '../../../services/file_service.dart';
import '../smart/secure_pin_page.dart';

class FolderDetailPage extends StatefulWidget {
  final String folderName;
  final List<FileItem> folderFiles;
  final void Function(FileItem) onOpen;
  final void Function(FileItem) onDelete;
  final void Function(FileItem) onShare;
  final void Function(FileItem) onMove;
  final void Function(FileItem) onRename;
  final void Function(FileItem) onDownload;
  final VoidCallback onChanged;
  final VoidCallback? onLockToggle;
  final bool isLocked;
  final Future<List<FileItem>> Function() onRefresh;

  const FolderDetailPage({
    super.key,
    required this.folderName,
    required this.folderFiles,
    required this.onOpen,
    required this.onDelete,
    required this.onShare,
    required this.onMove,
    required this.onRename,
    required this.onDownload,
    required this.onChanged,
    this.onLockToggle,
    this.isLocked = false,
    required this.onRefresh,
  });

  @override
  State<FolderDetailPage> createState() => _FolderDetailPageState();
}

class _FolderDetailPageState extends State<FolderDetailPage> {
  List<FileItem> _folderFiles = [];
  String _sortBy = 'date';
  bool _isGridView = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _folderFiles = List.from(widget.folderFiles);
  }

  // ─── Refresh logic ──────────────────────────────────────────────
  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final fresh = await widget.onRefresh();
      setState(() => _folderFiles = fresh);
    } catch (_) {
      // ignore
    }
    setState(() => _refreshing = false);
  }

  // ─── Sort & helpers ────────────────────────────────────────────
  List<FileItem> get _sortedFiles {
    final list = List.of(_folderFiles);
    switch (_sortBy) {
      case 'name':
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'size':
        list.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
        break;
      case 'type':
        list.sort((a, b) => a.type.name.compareTo(b.type.name));
        break;
      default:
        list.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
        break;
    }
    return list;
  }

  String _heroTag(FileItem file) => '${file.type.name}-${file.id}';

  // ─── Action menu ────────────────────────────────────────────────
  void _showActionMenu(BuildContext context, FileItem file) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      FileIcon(type: file.type, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          file.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),

                // ── Lock/Unlock ──
                ListTile(
                  leading: Icon(
                    file.isLocked
                        ? Icons.lock_open_rounded
                        : Icons.lock_rounded,
                    color: file.isLocked ? Colors.green : Colors.amber,
                  ),
                  title: Text(file.isLocked ? 'Unlock File' : 'Lock Securely'),
                  onTap: () async {
                    Navigator.pop(context);
                    final success = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SecurePinPage(
                          mode: file.isLocked ? PinMode.unlock : PinMode.create,
                          fileId: file.id,
                          entityType: 'file',
                        ),
                      ),
                    );
                    if (success == true) {
                      setState(() => file.isLocked = !file.isLocked);
                      widget.onChanged();
                      await _refresh(); // refresh to sync with parent
                    }
                  },
                ),

                // ── Move ──
                ListTile(
                  leading: const Icon(
                    Icons.folder_open_rounded,
                    color: Colors.indigo,
                  ),
                  title: const Text('Move to Folder'),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onMove(file);
                    // Wait for parent to update, then refresh
                    Future.delayed(const Duration(milliseconds: 600), _refresh);
                  },
                ),

                // ── Star/Unstar ──
                ListTile(
                  leading: Icon(
                    file.isStarred
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: file.isStarred ? Colors.amber : Colors.grey,
                  ),
                  title: Text(file.isStarred ? 'Unstar File' : 'Star File'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => file.isStarred = !file.isStarred);
                    FileService.toggleStar(file.id);
                    widget.onChanged();
                    _refresh();
                  },
                ),

                // ── Share ──
                ListTile(
                  leading: Icon(
                    Icons.share_rounded,
                    color: Colors.blue.shade700,
                  ),
                  title: const Text('Share Link'),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onShare(file);
                  },
                ),

                // ── Rename ──
                ListTile(
                  leading: const Icon(
                    Icons.edit_outlined,
                    color: Colors.indigo,
                  ),
                  title: const Text('Rename'),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onRename(file);
                    widget.onChanged();
                    Future.delayed(const Duration(milliseconds: 600), _refresh);
                  },
                ),

                // ── Download ──
                ListTile(
                  leading: const Icon(
                    Icons.download_rounded,
                    color: Colors.green,
                  ),
                  title: const Text('Download'),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onDownload(file);
                  },
                ),

                const Divider(),

                // ── Delete (Move to Bin) ──
                ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red.shade600,
                  ),
                  title: const Text(
                    'Move to Bin',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onDelete(file);
                    widget.onChanged();
                    Future.delayed(const Duration(milliseconds: 600), _refresh);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sorted = _sortedFiles;

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      appBar: AppBar(
        title: Text(
          widget.folderName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded, color: Colors.grey),
            tooltip: 'Sort by',
            onSelected: (val) => setState(() => _sortBy = val),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'date', child: Text('Date (newest)')),
              const PopupMenuItem(value: 'name', child: Text('Name')),
              const PopupMenuItem(value: 'size', child: Text('Size')),
              const PopupMenuItem(value: 'type', child: Text('Type')),
            ],
          ),
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: Colors.black87,
            ),
            tooltip: _isGridView
                ? 'Switch to List View'
                : 'Switch to Grid View',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: Colors.amber,
        child: _folderFiles.isEmpty
            ? _buildEmptyState(theme)
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildFolderHeaderCard(theme, isDark),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Files (${sorted.length})',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    sliver: _isGridView
                        ? SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.9,
                                ),
                            delegate: SliverChildBuilderDelegate(
                              (context, i) => _buildGridItem(theme, sorted[i]),
                              childCount: sorted.length,
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildListTile(theme, sorted[i]),
                              ),
                              childCount: sorted.length,
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  // ─── UI Helpers ─────────────────────────────────────────────────
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 80,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'This folder is empty',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderHeaderCard(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF1E40AF), const Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.4)
                : const Color(0xFF1E40AF).withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.folder_copy_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.folderName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_folderFiles.length} items',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          if (widget.onLockToggle != null)
            IconButton(
              icon: Icon(
                widget.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                color: widget.isLocked
                    ? Colors.red.shade300
                    : Colors.green.shade300,
              ),
              onPressed: widget.onLockToggle,
              tooltip: widget.isLocked ? 'Unlock Folder' : 'Lock Folder',
            ),
        ],
      ),
    );
  }

  Widget _buildListTile(ThemeData theme, FileItem f) {
    final iconConfig = _getIconConfigForType(theme, f.type);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      shadowColor: Colors.black.withOpacity(0.05),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => widget.onOpen(f),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconConfig.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  iconConfig.icon,
                  color: iconConfig.iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          f.sizeFormatted,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateHelper.timeAgo(f.uploadedAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                color: theme.colorScheme.onSurfaceVariant,
                onPressed: () => _showActionMenu(context, f),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridItem(ThemeData theme, FileItem f) {
    final iconConfig = _getIconConfigForType(theme, f.type);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => widget.onOpen(f),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              Hero(
                tag: _heroTag(f),
                child: FileIcon(type: f.type, size: 48),
              ),
              const SizedBox(height: 12),
              Text(
                f.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                f.sizeFormatted,
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
              Text(
                DateHelper.timeAgo(f.uploadedAt),
                style: TextStyle(color: Colors.grey[400], fontSize: 10),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                onPressed: () => _showActionMenu(context, f),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _IconConfig _getIconConfigForType(ThemeData theme, FileType type) {
    switch (type) {
      case FileType.pdf:
        return _IconConfig(
          Icons.picture_as_pdf_rounded,
          Colors.red.shade100,
          Colors.red.shade700,
        );
      case FileType.image:
        return _IconConfig(
          Icons.image_rounded,
          Colors.blue.shade100,
          Colors.blue.shade700,
        );
      case FileType.video:
        return _IconConfig(
          Icons.videocam_rounded,
          Colors.orange.shade100,
          Colors.orange.shade700,
        );
      case FileType.audio:
        return _IconConfig(
          Icons.headphones_rounded,
          Colors.purple.shade100,
          Colors.purple.shade700,
        );
      case FileType.document:
        return _IconConfig(
          Icons.description_rounded,
          Colors.teal.shade100,
          Colors.teal.shade700,
        );
      default:
        return _IconConfig(
          Icons.insert_drive_file_rounded,
          Colors.grey.shade200,
          Colors.grey.shade700,
        );
    }
  }
}

class _IconConfig {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  _IconConfig(this.icon, this.backgroundColor, this.iconColor);
}
