import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart' hide FileType;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mime/mime.dart';
import '../../../services/auth_service.dart';
import '../../../services/file_service.dart';
import '../../../services/zip_service.dart';
import '../../../services/upload_manager.dart';
import '../../../services/folder_service.dart';
import '../../../services/lock_service.dart';
import '../../../services/encryption_service.dart';
import '../../../services/notification_service.dart';
import '../../../utils/models/file_item.dart';
import '../../../utils/widgets/file_icon.dart';
import '../../services/download_history_service.dart';
import '../../utils/models/folder_item.dart';
import '../../utils/widgets/file_upload_badges.dart';
import '../../utils/widgets/shimmer_loading.dart';
import '../smart/secure_pin_page.dart';
import 'dashboard_tab.dart';
import 'files_tab.dart';
import 'folders_tab.dart';
import 'action_tab.dart';
import 'upload_sheet.dart';
import 'search_delegate.dart';
import '../media/pdf_reader_page.dart';
import '../media/text_editor_page.dart';
import '../media/image_viewer_page.dart';
import '../media/spreadsheet_viewer_page.dart';
import '../media/code_viewer_page.dart';
import '../smart/recycle_bin_page.dart';
import '../sharing/share_page.dart';
import '../account/profile_page.dart';
import '../account/notification_page.dart';
import '../media/media_player_page.dart';
import '../media/video_player_page.dart';
import '../../../providers/shared_count_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../utils/models/notification_item.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  bool _selectMode = false;
  final Set<String> _selectedIds = {};

  List<FileItem> _files = [];
  List<FolderItem> _folders = [];
  bool _filesLoading = true;
  bool _foldersLoading = true;
  String _userName = 'User';

  List<FileItem> get _active => _files.where((f) => !f.isDeleted).toList();
  List<FileItem> get _recent => (List.of(
    _active,
  )..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt))).take(4).toList();
  List<FileItem> get _starred => _active.where((f) => f.isStarred).toList();
  int get _binCount => _files.where((f) => f.isDeleted).length;
  int get _totalBytes => _active.fold(0, (s, f) => s + f.sizeBytes);

  @override
  void initState() {
    super.initState();
    _loadData();
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      if (user.email != null) {
        context.read<SharedCountProvider>().startListening(user.email!);
      }
      context.read<NotificationProvider>().startListening(user.id);
      context.read<NotificationProvider>().loadNotifications();
    }
  }

  Future<void> _loadData() async {
    try {
      await EncryptionService.getRawKey();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Encryption key missing. Please log in again.'),
            backgroundColor: Colors.orange[800],
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Logout',
              textColor: Colors.white,
              onPressed: () async {
                await AuthService.logout();
                if (!context.mounted) return;
                context.go('/login');
              },
            ),
          ),
        );
      }
    }
    // Load files, folders, and user name in parallel
    await Future.wait([_loadFiles(), _loadFolders(), _loadUserName()]);
  }

  Future<void> _loadUserName() async {
    try {
      final name = await AuthService.getUserName();
      if (mounted) {
        setState(() {
          _userName = name.isNotEmpty ? name : 'User';
        });
      }
    } catch (_) {}
  }

  Future<void> _loadFiles() async {
    try {
      final files = await FileService.getFiles();
      if (mounted) {
        setState(() {
          _files = files;
          _filesLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _filesLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not load files: $e')));
      }
    }
  }

  Future<void> _loadFolders() async {
    try {
      final folders = await FolderService.getFolders();
      if (mounted) {
        setState(() {
          _folders = folders;
          _foldersLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _foldersLoading = false);
    }
  }

  void _push(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  // ── Bulk actions ──────────────────────────────────────
  void _bulkStar() {
    final toStar = _active.where((f) => _selectedIds.contains(f.id));
    for (final f in toStar) {
      f.isStarred = true;
      FileService.toggleStar(f.id);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_selectedIds.length} files starred'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
  }

  void _bulkDelete() {
    final toDelete = _active.where((f) => _selectedIds.contains(f.id)).toList();
    for (final f in toDelete) {
      _softDelete(f);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${toDelete.length} files moved to bin'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
  }

  void _softDelete(FileItem f) {
    setState(() {
      f.isDeleted = true;
      f.deletedAt = DateTime.now();
      f.isStarred = false;
    });

    FileService.deleteFile(f.id).catchError((e) {
      if (mounted) {
        setState(() {
          f.isDeleted = false;
          f.deletedAt = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  void _restore(FileItem f) {
    setState(() {
      f.isDeleted = false;
      f.deletedAt = null;
    });
    FileService.restoreFile(f.id);
  }

  void _permDelete(FileItem f) {
    setState(() => _files.remove(f));
    FileService.permanentDelete(f.id);
  }

  void _showShareDialog(FileItem file) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SharePage(file: file)),
    );
  }

  void _openFile(FileItem f) async {
    final locked = await LockService.isFileLocked(f.id);
    if (!mounted) return;

    if (locked) {
      final unlocked = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => SecurePinPage(
            mode: PinMode.unlock,
            fileId: f.id,
            entityType: 'file',
          ),
        ),
      );
      if (!mounted) return;
      if (unlocked != true) return;
      f.isLocked = false;
      setState(() {});
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    if (!mounted) return;
    if (connectivityResult.contains(ConnectivityResult.none)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You are offline.')));
      return;
    }

    try {
      final bytes = await FileService.downloadFile(f.id);
      if (!mounted) return;

      if (f.type == FileType.image) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ImageViewerPage(fileName: f.name, imageBytes: bytes),
          ),
        );
        return;
      }

      if (!kIsWeb) {
        // ✅ SAFE: Always use downloadToTempFile
        final localPath = await FileService.downloadToTempFile(
          f.id,
          fileName: f.name,
        );
        f.isDownloaded = true;
        f.localPath = localPath;
        _openLocalFile(f, localPath);
      } else {
        _showGenericDetailDialog(f);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error opening file: $e')));
    }
  }

  Future<void> _openLocalFile(FileItem f, String localPath) async {
    HapticFeedback.lightImpact();
    final ext = f.extension;

    const codeExts = [
      'dart',
      'java',
      'kt',
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
      'sql',
      'sh',
      'bash',
      'md',
    ];
    if (codeExts.contains(ext)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CodeViewerPage(
            fileName: f.name,
            filePath: localPath,
            fileId: f.id,
          ),
        ),
      );
      return;
    }

    if (ext == 'pdf') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfReaderPage(
            fileName: f.name,
            filePath: localPath,
            isFileId: false,
          ),
        ),
      );
      return;
    }

    const imageExts = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'];
    if (imageExts.contains(ext)) {
      try {
        final file = File(localPath);
        if (!await file.exists()) {
          _showGenericDetailDialog(f);
          return;
        }
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ImageViewerPage(
              fileName: f.name,
              imageBytes: bytes,
              localPath: localPath,
            ),
          ),
        );
      } catch (_) {
        _showGenericDetailDialog(f);
      }
      return;
    }

    const audioExts = ['mp3', 'wav', 'aac', 'm4a', 'flac', 'ogg'];
    if (audioExts.contains(ext)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MediaPlayerPage(
            tracks: [
              AudioTrack(title: f.name, artist: 'Unknown', filePath: localPath),
            ],
          ),
        ),
      );
      return;
    }

    const videoExts = ['mp4', 'mov', 'avi', 'mkv', 'webm'];
    if (videoExts.contains(ext)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerPage(
            videos: [
              VideoItem(
                title: f.name,
                filePath: localPath,
                resolution: '',
                duration: '',
              ),
            ],
          ),
        ),
      );
      return;
    }

    const sheetExts = ['csv', 'xls', 'xlsx'];
    if (sheetExts.contains(ext)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              SpreadsheetViewerPage(filePath: localPath, fileName: f.name),
        ),
      );
      return;
    }

    try {
      final content = await File(localPath).readAsString();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TextEditorPage(
            fileName: f.name,
            initialContent: content,
            fileId: f.id,
          ),
        ),
      );
    } catch (_) {
      _showGenericDetailDialog(f);
    }
  }

  void _showGenericDetailDialog(FileItem f) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(f.name, overflow: TextOverflow.ellipsis),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FileIcon(type: f.type, size: 60),
              const SizedBox(height: 12),
              _row('Type', f.extensionUpper),
              _row('Size', f.sizeFormatted),
              _row('Uploaded', f.uploadedBy),
              if (f.aiSummary != null && f.aiSummary!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.08),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: Colors.amber,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'AI INSIGHT SUMMARY',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        f.aiSummary!,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _row(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            l,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );

  Future<void> _downloadSelectedAsZip() async {
    final selected = _active.where((f) => _selectedIds.contains(f.id)).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No files selected')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          int completed = 0;
          final total = selected.length;

          return AlertDialog(
            title: const Text('Creating ZIP…'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.amber),
                const SizedBox(height: 16),
                Text('Zipping $completed / $total files…'),
              ],
            ),
          );
        },
      ),
    );

    try {
      final Map<String, Uint8List> filesToZip = {};
      int completed = 0;
      for (final file in selected) {
        final bytes = await FileService.downloadFile(file.id);
        filesToZip[file.name] = bytes;
        completed++;
      }

      final zipBytes = ZipService.createZip(filesToZip);
      final dir = await getApplicationDocumentsDirectory();
      final zipName = 'filesafe_${DateTime.now().millisecondsSinceEpoch}.zip';
      final zipFile = File('${dir.path}/$zipName');
      await zipFile.writeAsBytes(zipBytes);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ZIP saved to ${zipFile.path}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _selectMode = false;
          _selectedIds.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ZIP creation failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildBatchActionBar() {
    final count = _selectedIds.length;
    return Positioned(
      bottom: kBottomNavigationBarHeight + 8,
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Text(
                '$count selected',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              _batchIcon(
                Icons.star_rounded,
                Colors.amber,
                'Star all',
                _bulkStar,
              ),
              _batchIcon(
                Icons.delete_rounded,
                Colors.red,
                'Delete all',
                _bulkDelete,
              ),
              _batchIcon(
                Icons.download_rounded,
                Colors.blue,
                'Download ZIP',
                _downloadSelectedAsZip,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _batchIcon(
    IconData icon,
    Color color,
    String tooltip,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButton(
        icon: Icon(icon, color: color),
        tooltip: tooltip,
        onPressed: onTap,
        splashRadius: 20,
      ),
    );
  }

  Future<List<FileItem>> _triggerSemanticSearch(String searchPhrase) async {
    if (searchPhrase.trim().isEmpty) return _active;

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return _active
          .where(
            (f) => f.name.toLowerCase().contains(searchPhrase.toLowerCase()),
          )
          .toList();
    }

    try {
      return await FileService.searchFiles(searchPhrase);
    } catch (e) {
      debugPrint("Semantic search error: $e");
      return _active
          .where(
            (f) => f.name.toLowerCase().contains(searchPhrase.toLowerCase()),
          )
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_filesLoading || _foldersLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('FileSafe')),
        body: const DashboardShimmer(),
      );
    }

    final dashboard = RefreshIndicator(
      onRefresh: _loadFiles,
      color: Colors.amber,
      child: DashboardTab(
        recent: _recent,
        starred: _starred,
        allFiles: _files,
        totalFiles: _active.length,
        totalFolders: _folders.length,
        totalBytes: _totalBytes,
        binCount: _binCount,
        userName: _userName,
        onNavigate: (i) => setState(() => _tab = i),
        onOpen: _openFile,
        onDelete: _softDelete,
        onRestore: _restore,
        onPermDelete: _permDelete,
        push: _push,
      ),
    );

    final pages = [
      dashboard,
      FilesTab(
        files: _active,
        onOpen: _openFile,
        onDelete: _softDelete,
        onShare: _showShareDialog,
        onMove: _moveFileToFolder,
        onRename: _renameFile,
        onDownload: _downloadFile,
        onChanged: () => setState(() {}),
        selectMode: _selectMode,
        selectedIds: _selectedIds,
        onSelectionChanged: () => setState(() {}),
      ),
      FoldersTab(
        folders: _folders,
        files: _active,
        onChanged: () => setState(() {}),
        onOpen: _openFile,
        onDelete: _softDelete,
        onShare: _showShareDialog,
        onMove: _moveFileToFolder,
        onRename: _renameFile,
        onDownload: _downloadFile,
      ),
      ActionsTab(
        push: _push,
        allFiles: _files,
        binCount: _binCount,
        onNavigate: (i) => setState(() => _tab = i),
        onOpen: _openFile,
        onDelete: _softDelete,
        onRestore: _restore,
        onPermDelete: _permDelete,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.asset(
                'assets/images/FileSafe_logo.png',
                width: 20,
                height: 20,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'FileSafe',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          if (_tab == 1)
            IconButton(
              icon: Icon(_selectMode ? Icons.check_circle : Icons.checklist),
              tooltip: _selectMode ? 'Cancel selection' : 'Select files',
              onPressed: () => setState(() {
                _selectMode = !_selectMode;
                if (!_selectMode) _selectedIds.clear();
              }),
            ),
          if (_binCount > 0)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _push(
                    RecycleBinPage(
                      files: _files,
                      onRestore: _restore,
                      onPermanentDelete: _permDelete,
                    ),
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$_binCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => showSearch(
              context: context,
              delegate: FileSearchDelegate(
                _active,
                _openFile,
                onSemanticQuery: _triggerSemanticSearch,
              ),
            ),
          ),
          Consumer<NotificationProvider>(
            builder: (context, provider, child) {
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => _push(const NotificationPage()),
                  ),
                  if (provider.unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 12,
                          minHeight: 12,
                        ),
                        child: Text(
                          '${provider.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => _push(const ProfilePage()),
          ),
        ],
      ),
      body: Stack(
        children: [
          pages[_tab],
          if (_selectMode && _tab == 1) _buildBatchActionBar(),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: UploadProgressBadge(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          if (i == 3) context.read<SharedCountProvider>().reset();
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Files',
          ),
          const NavigationDestination(
            icon: Icon(Icons.create_new_folder_outlined),
            selectedIcon: Icon(Icons.create_new_folder),
            label: 'Folders',
          ),
          Consumer<SharedCountProvider>(
            builder: (context, sharedCount, child) {
              return NavigationDestination(
                icon: sharedCount.unread > 0
                    ? Badge(
                        label: Text('${sharedCount.unread}'),
                        child: const Icon(Icons.apps_outlined),
                      )
                    : const Icon(Icons.apps_outlined),
                selectedIcon: sharedCount.unread > 0
                    ? Badge(
                        label: Text('${sharedCount.unread}'),
                        child: const Icon(Icons.apps),
                      )
                    : const Icon(Icons.apps),
                label: 'Actions',
              );
            },
          ),
        ],
      ),
      floatingActionButton: _tab == 1 && !_selectMode
          ? FloatingActionButton.extended(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload File'),
              onPressed: _showUploadSheet,
            )
          : null,
    );
  }

  void _showUploadSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => UploadSheet(
        onUploaded: () => setState(() {}),
        onExtractZip: _extractZip,
        onFilePicked: (String fileName, Uint8List bytes, String mimeType) {
          final uploadManager = context.read<UploadManager>();
          final task = UploadTask(fileName: fileName, totalBytes: bytes.length);
          uploadManager.addTask(task);

          FileService.uploadFile(
                fileName: fileName,
                bytes: bytes,
                mimeType: mimeType,
              )
              .then((_) {
                if (mounted) {
                  task.markCompleted();
                  _loadFiles();
                }
              })
              .catchError((e) {
                if (mounted) {
                  task.markFailed(e.toString());
                }
              });
        },
      ),
    );
  }

  Future<void> _extractZip() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final extractedFiles = await ZipService.extractFilesFromPath(
        result.files.single.path!,
      );
      if (!mounted) return;

      final uploadManager = context.read<UploadManager>();
      int uploaded = 0;

      for (var entry in extractedFiles.entries) {
        final rawName = entry.key;
        final fileName = rawName.split(Platform.pathSeparator).last;
        final bytes = entry.value;
        final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';

        final task = UploadTask(fileName: fileName, totalBytes: bytes.length);
        uploadManager.addTask(task);

        await FileService.uploadFile(
              fileName: fileName,
              bytes: bytes,
              mimeType: mimeType,
            )
            .then((_) {
              task.status = UploadStatus.completed;
              uploaded++;
              if (uploaded == extractedFiles.length) {
                NotificationService.createNotification(
                  type: NotificationType.uploadComplete,
                  message: 'Successfully uploaded $uploaded files from ZIP',
                );
              }
            })
            .catchError((e) {
              task.status = UploadStatus.failed;
              task.errorMessage = e.toString();
              uploadManager.refresh();
            });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Extracted and uploaded $uploaded files from ZIP'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadFiles();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Extraction failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _moveFileToFolder(FileItem file) async {
    final folders = _folders;

    final selectedFolderId = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose a folder'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Root (no folder)'),
                onTap: () => Navigator.pop(ctx, null),
              ),
              ...folders.map(
                (f) => ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(f.name),
                  onTap: () => Navigator.pop(ctx, f.id),
                ),
              ),
              if (folders.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('No folders yet. Create one first.'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'CANCEL'),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedFolderId == 'CANCEL') return;

    try {
      await FolderService.moveFile(file.id, selectedFolderId);
      _loadFiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File moved'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Move failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _renameFile(FileItem file) async {
    final controller = TextEditingController(text: file.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename file'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'New name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == file.name) return;

    try {
      await FileService.renameFile(file.id, newName);
      file.name = newName;
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Renamed to "$newName"'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rename failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _downloadFile(FileItem file) async {
    try {
      final tempPath = await FileService.downloadToTempFile(
        file.id,
        fileName: file.name,
      );
      if (!mounted) return;

      // Move to Downloads folder (or Documents)
      final dir =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final finalFile = File('${dir.path}/${file.name}');
      await File(tempPath).copy(finalFile.path);
      await File(tempPath).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to ${finalFile.path}'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
