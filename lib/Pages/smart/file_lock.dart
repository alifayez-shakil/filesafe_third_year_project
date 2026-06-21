import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/lock_service.dart';
import '../../utils/widgets/shimmer_loading.dart';
import 'secure_pin_page.dart';

class FileLockPage extends StatefulWidget {
  const FileLockPage({super.key});

  @override
  State<FileLockPage> createState() => _FileLockPageState();
}

class _FileLockPageState extends State<FileLockPage> {
  List<Map<String, dynamic>> _lockedFiles = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final files = await LockService.getLockedFiles();
      if (mounted) {
        setState(() {
          _lockedFiles = files;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _unlock(String fileId, String fileName) async {
    HapticFeedback.lightImpact();

    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SecurePinPage(
          mode: PinMode.unlock,
          fileId: fileId,
          entityType: 'file',
        ),
      ),
    );

    if (success == true) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$fileName successfully unlocked'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      _load();
    }
  }

  String _formatSize(dynamic bytesInput) {
    if (bytesInput == null) return '0 B';
    final int? bytes = bytesInput is int
        ? bytesInput
        : int.tryParse(bytesInput.toString());
    if (bytes == null) return '0 B';

    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1F2937),
            size: 16,
          ),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Secure Vault',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color(0xFF1F2937),
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        actions: [
          if (!_loading && _error == null && _lockedFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              key: const ValueKey('count-badge'),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_lockedFiles.length} Locked',
                    style: TextStyle(
                      color: Colors.red.shade600,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildCurrentState(theme),
      ),
    );
  }

  Widget _buildCurrentState(ThemeData theme) {
    if (_loading) {
      return const KeyedSubtree(
        key: ValueKey('loading'),
        child: DashboardShimmer(),
      );
    }
    if (_error != null) {
      return _buildErrorState();
    }
    if (_lockedFiles.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      key: const ValueKey('content-list'),
      onRefresh: _load,
      color: Colors.redAccent,
      backgroundColor: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: _lockedFiles.length,
        itemBuilder: (context, i) {
          final file = _lockedFiles[i];
          final fileId = file['id'].toString();
          final fileName = file['name']?.toString() ?? 'Untitled_File';
          final fileSizeDisplay = _formatSize(file['size']);

          return Dismissible(
            key: Key('dismiss-$fileId'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) async {
              await _unlock(fileId, fileName);
              return false;
            },
            background: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              alignment: Alignment.centerRight,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Swipe to Unlock',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.lock_open_rounded, color: Colors.white, size: 18),
                ],
              ),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                ),
                title: Text(
                  fileName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF111827),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    fileSizeDisplay,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  ),
                ),
                trailing: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _unlock(fileId, fileName),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      key: const ValueKey('empty-state'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.gpp_good_rounded,
                size: 48,
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your vault is clear',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'All personal documents and files are fully decrypted and available in your library.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      key: const ValueKey('error-state'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Connection interrupted',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error ?? 'Could not parse secure file entries.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Sync Vault'),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
