import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../Pages/smart/secure_pin_page.dart';
import '../../services/file_service.dart';
import '../../utils/models/file_item.dart';
import '../../utils/widgets/file_icon.dart';

class FileCard extends StatefulWidget {
  final FileItem file;
  final VoidCallback? onTap;
  final VoidCallback? onChanged;
  final VoidCallback? onShred;

  const FileCard({
    super.key,
    required this.file,
    this.onTap,
    this.onChanged,
    this.onShred,
  });

  @override
  State<FileCard> createState() => _FileCardState();
}

class _FileCardState extends State<FileCard> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          widget.file.isStarred = !widget.file.isStarred;
        });
        FileService.toggleStar(widget.file.id);
        widget.onChanged?.call();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            FileIcon(type: widget.file.type, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.file.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.file.sizeFormatted,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
            if (widget.file.isStarred)
              const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
            IconButton(
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () => _showOptionsSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FileOptionsSheet(
        file: widget.file,
        onChanged: widget.onChanged,
        onShred: widget.onShred,
      ),
    );
  }
}

// ─── Options Bottom Sheet ──────────────────────────────

class _FileOptionsSheet extends StatefulWidget {
  final FileItem file;
  final VoidCallback? onChanged;
  final VoidCallback? onShred;

  const _FileOptionsSheet({required this.file, this.onChanged, this.onShred});

  @override
  State<_FileOptionsSheet> createState() => _FileOptionsSheetState();
}

class _FileOptionsSheetState extends State<_FileOptionsSheet> {
  // ✅ Lock/Unlock logic (fully working)
  Future<void> _lockFile(FileItem file) async {
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
        widget.onChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File unlocked'),
            behavior: SnackBarBehavior.floating,
          ),
        );
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
        widget.onChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File locked'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  FileIcon(type: widget.file.type, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.file.name,
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

            // ✅ Lock/Unlock tile (now works)
            _actionTile(
              Icons.lock_rounded,
              widget.file.isLocked ? 'Unlock' : 'Lock',
              Colors.amber,
              onTap: () {
                Navigator.pop(context);
                _lockFile(widget.file);
              },
            ),
            _actionTile(
              Icons.delete_outline_rounded,
              'Shred (delete)',
              Colors.red,
              onTap: () {
                Navigator.pop(context);
                widget.onShred?.call();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(
    IconData icon,
    String label,
    Color color, {
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }
}
