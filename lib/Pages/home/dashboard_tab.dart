import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../utils/models/file_item.dart';
import '../../../utils/widgets/file_card.dart';
import '../../../services/auth_service.dart';
import '../account/profile_page.dart';
import '../media/timeline_page.dart';
import '../smart/categorization_page.dart';
import '../smart/storage_analyzer_page.dart';
import '../smart/recycle_bin_page.dart';

class DashboardTab extends StatefulWidget {
  final List<FileItem> recent, starred, allFiles;
  final int totalFiles, totalFolders, totalBytes, binCount;
  final String userName;
  final void Function(int) onNavigate;
  final void Function(FileItem) onOpen, onDelete;
  final void Function(FileItem) onRestore, onPermDelete;
  final void Function(Widget) push;

  const DashboardTab({
    super.key,
    required this.recent,
    required this.starred,
    required this.allFiles,
    required this.totalFiles,
    required this.totalFolders,
    required this.totalBytes,
    required this.binCount,
    required this.userName,
    required this.onNavigate,
    required this.onOpen,
    required this.onDelete,
    required this.onRestore,
    required this.onPermDelete,
    required this.push,
  });

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  String _userEmail = '';
  String _storageUsed = '';
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final email = await AuthService.getUserEmail();
      final profile = await AuthService.getProfile();
      if (mounted) {
        setState(() {
          _userEmail = email;
          if (profile != null) {
            final usedMB = (profile.storageUsed / (1024 * 1024)).round();
            final totalMB = (profile.quotaBytes / (1024 * 1024)).round();
            _storageUsed =
                '$usedMB MB / ${(totalMB / 1024).toStringAsFixed(1)} GB';
          }
          _loadingProfile = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  String _fmt(int b) {
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        // This will trigger parent refresh
        widget.onNavigate(0);
        return Future.value();
      },
      color: Colors.amber,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero card (with user name) ──────────────
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
                  Text(
                    'Welcome back, ${widget.userName}!',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Your files are safe',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip(
                        Icons.insert_drive_file,
                        '${widget.totalFiles} Files',
                      ),
                      _chip(Icons.folder, '${widget.totalFolders} Folders'),
                      _chip(Icons.storage, _fmt(widget.totalBytes)),
                      if (widget.binCount > 0)
                        _chip(
                          Icons.delete_outline,
                          '${widget.binCount} Deleted',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Profile card (with email + storage) ──────
            InkWell(
              onTap: () => widget.push(const ProfilePage()),
              borderRadius: BorderRadius.circular(16),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.amber,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if (_userEmail.isNotEmpty)
                              Text(
                                _userEmail,
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                            if (!_loadingProfile && _storageUsed.isNotEmpty)
                              Text(
                                _storageUsed,
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Quick Actions (two rows) ──────────────────
            const Text(
              'Quick Actions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                _act(
                  context,
                  Icons.timeline,
                  'Timeline',
                  Colors.greenAccent,
                  () => context.push(
                    '/timeline',
                    extra: {'files': widget.allFiles, 'onOpen': widget.onOpen},
                  ),
                ),
                const SizedBox(width: 10),
                _act(
                  context,
                  Icons.upload_file,
                  'Upload',
                  const Color(0xFF3B82F6),
                  () => widget.onNavigate(1),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                _act(
                  context,
                  Icons.auto_awesome,
                  'Smart\nSort',
                  Colors.indigo,
                  () => widget.push(
                    CategorizationPage(
                      files: widget.allFiles,
                      onOpen: widget.onOpen,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _act(
                  context,
                  Icons.pie_chart_outline,
                  'Storage',
                  Colors.green,
                  () => widget.push(
                    StorageAnalyzerPage(
                      files: widget.allFiles,
                      onOpen: widget.onOpen,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _act(
                  context,
                  Icons.delete_outline,
                  'Bin',
                  widget.binCount > 0 ? Colors.red : Colors.grey,
                  () => widget.push(
                    RecycleBinPage(
                      files: widget.allFiles,
                      onRestore: widget.onRestore,
                      onPermanentDelete: widget.onPermDelete,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Starred files (capped at 3) ──────────────
            if (widget.starred.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Starred',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  if (widget.starred.length > 3)
                    TextButton(
                      onPressed: () => widget.onNavigate(1),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.amber,
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text(
                        'See all ${widget.starred.length} starred →',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ...widget.starred
                  .take(3)
                  .map((f) => FileCard(file: f, onTap: () => widget.onOpen(f))),
            ],

            // ── Recent files ──────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Files',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextButton(
                  onPressed: () => widget.onNavigate(1),
                  child: const Text(
                    'See all',
                    style: TextStyle(color: Colors.amber),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Empty state (no files) ────────────────────
            if (widget.recent.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No files yet',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upload your first file to get started',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.upload_file, size: 18),
                        label: const Text('Upload Now'),
                        onPressed: () => widget.onNavigate(1),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...widget.recent.map(
                (f) => FileCard(file: f, onTap: () => widget.onOpen(f)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 13),
        const SizedBox(width: 4),
        Text(t, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    ),
  );

  Widget _act(
    BuildContext ctx,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
