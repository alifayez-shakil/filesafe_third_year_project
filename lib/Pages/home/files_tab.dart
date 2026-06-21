import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/models/file_item.dart';
import '../../utils/widgets/file_icon.dart';
import '../../services/file_service.dart';
import '../../utils/helpers/date_helper.dart';
import '../smart/secure_pin_page.dart';

class FilesTab extends StatefulWidget {
  final List<FileItem> files;
  final void Function(FileItem) onOpen, onDelete, onShare;
  final void Function(FileItem) onMove;
  final void Function(FileItem) onRename;
  final void Function(FileItem) onDownload;
  final VoidCallback onChanged;
  final bool selectMode;
  final Set<String> selectedIds;
  final VoidCallback onSelectionChanged;

  const FilesTab({
    super.key,
    required this.files,
    required this.onOpen,
    required this.onDelete,
    required this.onShare,
    required this.onMove,
    required this.onRename,
    required this.onDownload,
    required this.onChanged,
    required this.selectMode,
    required this.selectedIds,
    required this.onSelectionChanged,
  });

  @override
  State<FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<FilesTab> {
  bool _isGridView = false;
  String _sortBy = 'date';

  void _toggleView() {
    HapticFeedback.lightImpact();
    setState(() => _isGridView = !_isGridView);
  }

  String _heroTag(FileItem file) {
    return '${file.type.name}-${file.id}';
  }

  List<FileItem> get _sortedFiles {
    final list = List.of(widget.files);
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

  Future<void> _toggleLock(FileItem file) async {
    HapticFeedback.lightImpact();
    if (file.isLocked) {
      final success = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => SecurePinPage(
            mode: PinMode.unlock,
            fileId: file.id,
            entityType: 'file',
          ),
        ),
      );
      if (success == true) {
        setState(() => file.isLocked = false);
        widget.onChanged();
        _showSnackBar('${file.name} unlocked');
      }
    } else {
      final success = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => SecurePinPage(
            mode: PinMode.create,
            fileId: file.id,
            entityType: 'file',
          ),
        ),
      );
      if (success == true) {
        setState(() => file.isLocked = true);
        widget.onChanged();
        _showSnackBar('${file.name} locked');
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _handleItemTap(FileItem file) {
    HapticFeedback.lightImpact();
    if (widget.selectMode) {
      _toggleSelection(file);
    } else {
      widget.onOpen(file);
    }
  }

  void _handleItemLongPress(FileItem file) {
    HapticFeedback.mediumImpact();
    _toggleSelection(file);
  }

  void _toggleSelection(FileItem file) {
    setState(() {
      if (widget.selectedIds.contains(file.id)) {
        widget.selectedIds.remove(file.id);
      } else {
        widget.selectedIds.add(file.id);
      }
      widget.onSelectionChanged();
    });
  }

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
                ListTile(
                  leading: Icon(
                    file.isLocked
                        ? Icons.lock_open_rounded
                        : Icons.lock_rounded,
                    color: file.isLocked ? Colors.green : Colors.amber,
                  ),
                  title: Text(file.isLocked ? 'Unlock File' : 'Lock Securely'),
                  onTap: () {
                    Navigator.pop(context);
                    _toggleLock(file);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.folder_open_rounded,
                    color: Colors.indigo,
                  ),
                  title: const Text('Move to Folder'),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onMove(file);
                  },
                ),
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
                  },
                ),
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
                ListTile(
                  leading: const Icon(
                    Icons.edit_outlined,
                    color: Colors.indigo,
                  ),
                  title: const Text('Rename'),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onRename(file);
                  },
                ),
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
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRowItem(FileItem file, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.amber.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? Colors.amber : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onTap: () => _handleItemTap(file),
        onLongPress: () => _handleItemLongPress(file),
        leading: widget.selectMode
            ? Checkbox(
                value: isSelected,
                activeColor: Colors.amber,
                onChanged: (val) => _handleItemTap(file),
              )
            : Hero(
                tag: _heroTag(file),
                child: FileIcon(type: file.type, size: 40),
              ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                file.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (file.isLocked)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.lock_rounded, color: Colors.red, size: 16),
              ),
            if (file.isStarred)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.star_rounded, color: Colors.amber, size: 16),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              file.sizeFormatted,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            Text(
              DateHelper.timeAgo(file.uploadedAt),
              style: TextStyle(color: Colors.grey[400], fontSize: 11),
            ),
          ],
        ),
        trailing: widget.selectMode
            ? null
            : IconButton(
                icon: const Icon(Icons.more_vert_rounded),
                onPressed: () => _showActionMenu(context, file),
              ),
      ),
    );
  }

  Widget _buildGridItem(FileItem file, bool isSelected) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _handleItemTap(file),
      onLongPress: () => _handleItemLongPress(file),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.amber.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.amber : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  Hero(
                    tag: _heroTag(file),
                    child: FileIcon(type: file.type, size: 52),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    file.name,
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
                    file.sizeFormatted,
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                  Text(
                    DateHelper.timeAgo(file.uploadedAt),
                    style: TextStyle(color: Colors.grey[400], fontSize: 10),
                  ),
                ],
              ),
            ),
            if (widget.selectMode)
              Positioned(
                top: 4,
                left: 4,
                child: Checkbox(
                  value: isSelected,
                  activeColor: Colors.amber,
                  onChanged: (val) => _handleItemTap(file),
                ),
              ),
            Positioned(
              top: 8,
              right: widget.selectMode ? 8 : 4,
              child: widget.selectMode
                  ? const SizedBox.shrink()
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (file.isLocked)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 2),
                            child: Icon(
                              Icons.lock_rounded,
                              color: Colors.red,
                              size: 14,
                            ),
                          ),
                        if (file.isStarred)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 2),
                            child: Icon(
                              Icons.star_rounded,
                              color: Colors.amber,
                              size: 14,
                            ),
                          ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            size: 20,
                            color: Colors.grey,
                          ),
                          onPressed: () => _showActionMenu(context, file),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_outlined, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text(
              'No files inside this vault',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final sorted = _sortedFiles;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'All Items (${sorted.length})',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 12),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.sort_rounded, color: Colors.grey),
                    tooltip: 'Sort by',
                    onSelected: (val) => setState(() => _sortBy = val),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'date',
                        child: Text('Date (newest)'),
                      ),
                      const PopupMenuItem(value: 'name', child: Text('Name')),
                      const PopupMenuItem(value: 'size', child: Text('Size')),
                      const PopupMenuItem(value: 'type', child: Text('Type')),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: Icon(
                  _isGridView
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded,
                  color: Colors.black87,
                ),
                tooltip: _isGridView
                    ? 'Switch to List View'
                    : 'Switch to Grid View',
                onPressed: _toggleView,
              ),
            ],
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _isGridView
                ? GridView.builder(
                    key: const ValueKey('GridFiles'),
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.9,
                        ),
                    itemCount: sorted.length,
                    itemBuilder: (_, i) {
                      final file = sorted[i];
                      final isSel =
                          widget.selectMode &&
                          widget.selectedIds.contains(file.id);
                      return _buildGridItem(file, isSel);
                    },
                  )
                : ListView.builder(
                    key: const ValueKey('ListFiles'),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: sorted.length,
                    itemBuilder: (_, i) {
                      final file = sorted[i];
                      final isSel =
                          widget.selectMode &&
                          widget.selectedIds.contains(file.id);
                      return _buildRowItem(file, isSel);
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
