import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../utils/models/folder_item.dart';
import 'folder_details_page.dart';
import '../../utils/models/file_item.dart';
import '../../services/folder_service.dart';
import '../../services/file_service.dart';
import '../../services/lock_service.dart';
import '../../services/zip_service.dart';
import '../../utils/widgets/shimmer_loading.dart';
import '../smart/secure_pin_page.dart';

class FoldersTab extends StatefulWidget {
  final List<FolderItem> folders;
  final List<FileItem> files;
  final VoidCallback onChanged;
  final void Function(FileItem)? onOpen;
  final void Function(FileItem) onDelete;
  final void Function(FileItem) onShare;
  final void Function(FileItem) onMove;
  final void Function(FileItem) onRename;
  final void Function(FileItem) onDownload;

  const FoldersTab({
    super.key,
    required this.folders,
    required this.files,
    required this.onChanged,
    this.onOpen,
    required this.onDelete,
    required this.onShare,
    required this.onMove,
    required this.onRename,
    required this.onDownload,
  });

  @override
  State<FoldersTab> createState() => _FoldersTabState();
}

class _FoldersTabState extends State<FoldersTab> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() => _loading = false);
  }

  Future<void> _createFolder() async {
    HapticFeedback.lightImpact();
    final ctrl = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'New Folder',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder name',
            border: UnderlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text(
              'Create',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await FolderService.createFolder(result);
        widget.onChanged();
        _showSnackBar('Folder created');
      } catch (e) {
        _showSnackBar('Failed to create folder: $e', isError: true);
      }
    }
  }

  Future<void> _renameFolder(FolderItem folder) async {
    HapticFeedback.lightImpact();
    final ctrl = TextEditingController(text: folder.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Rename Folder',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'New folder name',
            border: UnderlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text(
              'Rename',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == folder.name) return;

    try {
      await FolderService.renameFolder(folder.id, newName);
      widget.onChanged();
      _showSnackBar('Folder renamed to "$newName"');
    } catch (e) {
      _showSnackBar('Failed to rename: $e', isError: true);
    }
  }

  Future<void> _zipFolder(FolderItem folder) async {
    HapticFeedback.mediumImpact();

    final folderFiles = widget.files
        .where((f) => f.folderId == folder.id)
        .toList();
    if (folderFiles.isEmpty) {
      _showSnackBar('Folder is empty. Nothing to zip.', isError: true);
      return;
    }

    if (folderFiles.length > 20) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Large Folder'),
          content: Text(
            'This folder contains ${folderFiles.length} files. Zipping may take a while. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final Map<String, Uint8List> filesToZip = {};
      for (final file in folderFiles) {
        final bytes = await FileService.downloadFile(file.id);
        filesToZip[file.name] = bytes;
      }

      final zipBytes = ZipService.createZip(filesToZip);
      final dir = await getApplicationDocumentsDirectory();
      final zipName =
          '${folder.name}_${DateTime.now().millisecondsSinceEpoch}.zip';
      final zipFile = File('${dir.path}/$zipName');
      await zipFile.writeAsBytes(zipBytes);

      if (mounted) {
        Navigator.pop(context);
        _showSnackBar('ZIP saved: ${zipFile.path}');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showSnackBar('Failed to create ZIP: $e', isError: true);
      }
    }
  }

  Future<void> _deleteFolder(FolderItem folder) async {
    HapticFeedback.mediumImpact();
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Folder?'),
        content: Text(
          'Are you sure you want to delete "${folder.name}"? Files inside will be moved to the root (no folder).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FolderService.deleteFolder(folder.id);
      widget.onChanged();
      _showSnackBar('Folder deleted successfully');
    } catch (e) {
      _showSnackBar('Failed to delete: $e', isError: true);
    }
  }

  Future<void> _toggleFolderLock(FolderItem folder) async {
    HapticFeedback.lightImpact();

    try {
      final isLocked = await LockService.isFolderLocked(folder.id);
      if (!mounted) return;

      if (isLocked) {
        final success = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => SecurePinPage(
              mode: PinMode.unlock,
              fileId: folder.id,
              entityType: 'folder',
            ),
          ),
        );
        if (success == true) {
          widget.onChanged();
          _showSnackBar('Folder unlocked');
        }
      } else {
        final success = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => SecurePinPage(
              mode: PinMode.create,
              fileId: folder.id,
              entityType: 'folder',
            ),
          ),
        );
        if (success == true) {
          widget.onChanged();
          _showSnackBar('Folder locked');
        }
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.redAccent : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'create_folder',
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: _createFolder,
        icon: const Icon(Icons.create_new_folder_rounded, size: 20),
        label: const Text('New Folder'),
      ),
      body: _loading
          ? const DashboardShimmer()
          : widget.folders.isEmpty
          ? _buildEmptyState(theme)
          : RefreshIndicator(
              onRefresh: () async {
                widget.onChanged();
                setState(() {});
              },
              color: Colors.amber.shade700,
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 84),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.15,
                ),
                itemCount: widget.folders.length,
                itemBuilder: (context, i) {
                  final folder = widget.folders[i];
                  final fileCount = widget.files
                      .where((f) => f.folderId == folder.id)
                      .length;
                  return _buildFolderCard(context, theme, folder, fileCount);
                },
              ),
            ),
    );
  }

  Widget _buildFolderCard(
    BuildContext context,
    ThemeData theme,
    FolderItem folder,
    int fileCount,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            final folderFiles = widget.files
                .where((f) => f.folderId == folder.id)
                .toList();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FolderDetailPage(
                  folderName: folder.name,
                  folderFiles: folderFiles,
                  onOpen: widget.onOpen!,
                  onDelete: widget.onDelete,
                  onShare: widget.onShare,
                  onMove: widget.onMove,
                  onRename: widget.onRename,
                  onDownload: widget.onDownload,
                  onChanged: widget.onChanged,
                  onLockToggle: () => _toggleFolderLock(folder),
                  isLocked: folder.isLocked,
                  // ─── Refresh callback ──────────────────────────────────
                  onRefresh: () async {
                    // Return the latest file list for this folder
                    return widget.files
                        .where((f) => f.folderId == folder.id)
                        .toList();
                  },
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.folder_rounded,
                        color: Colors.amber.shade700,
                        size: 28,
                      ),
                    ),
                    _buildContextMenu(folder),
                  ],
                ),
                const Spacer(),
                Text(
                  folder.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '$fileCount ${fileCount == 1 ? 'file' : 'files'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    if (folder.isLocked)
                      Row(
                        children: [
                          Icon(
                            Icons.lock_rounded,
                            size: 14,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Locked',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_off_outlined,
            size: 72,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No folders yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextMenu(FolderItem folder) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, size: 20),
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (val) {
        switch (val) {
          case 'rename':
            _renameFolder(folder);
            break;
          case 'zip':
            _zipFolder(folder);
            break;
          case 'lock':
            _toggleFolderLock(folder);
            break;
          case 'delete':
            _deleteFolder(folder);
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, color: Colors.blue, size: 18),
              SizedBox(width: 8),
              Text('Rename'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'zip',
          child: Row(
            children: [
              Icon(Icons.folder_zip_outlined, color: Colors.orange, size: 18),
              SizedBox(width: 8),
              Text('Zip Folder'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'lock',
          child: Row(
            children: [
              Icon(Icons.lock_outline, color: Colors.amber, size: 18),
              SizedBox(width: 8),
              Text('Lock/Unlock'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }
}
