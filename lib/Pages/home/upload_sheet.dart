import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' hide FileType;
import 'package:mime/mime.dart';
import '../../config/security_config.dart';

class UploadSheet extends StatefulWidget {
  final VoidCallback onUploaded;
  final VoidCallback onExtractZip;

  /// Callback when a real file is picked and validated.
  /// Passes the file name, raw bytes and mimeType.
  final void Function(String fileName, Uint8List bytes, String mimeType)? onFilePicked;

  const UploadSheet({
    super.key,
    required this.onUploaded,
    required this.onExtractZip,
    this.onFilePicked,
  });

  @override
  State<UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends State<UploadSheet> {
  bool _uploading = false;

  Future<void> _pickRealFile() async {
    // 1. Let the user choose a file
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    final platformFile = result.files.single;
    String fileName;
    Uint8List bytes;

    // 2. Get file data (different for web vs mobile)
    if (platformFile.bytes != null) {
      // Web – use bytes directly
      fileName = platformFile.name;
      bytes = platformFile.bytes!;
    } else if (platformFile.path != null) {
      // Mobile – read bytes from the file
      final file = File(platformFile.path!);
      fileName = file.path.split(Platform.pathSeparator).last;
      bytes = await file.readAsBytes();
    } else {
      // Fallback (should not happen)
      return;
    }

    // 3. Detect MIME type
    final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';

    // 4. Validate using SecurityConfig
    final validationError = SecurityConfig.validateFile(
      fileName: fileName,
      mimeType: mimeType,
      sizeBytes: bytes.length,
    );

    if (validationError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validationError),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // 5. Valid file → notify parent with bytes
    if (mounted) {
      widget.onFilePicked?.call(fileName, bytes, mimeType);
      Navigator.pop(context); // close the bottom sheet
    }
  }

  Future<void> _pickFolder() async {
    // 1. Let user choose a directory
    final String? directoryPath = await FilePicker.platform.getDirectoryPath();
    if (directoryPath == null) return;

    setState(() => _uploading = true);

    try {
      final dir = Directory(directoryPath);
      final List<FileSystemEntity> entities = await dir.list(recursive: true).toList();

      int count = 0;
      for (var entity in entities) {
        if (entity is File) {
          final fileName = entity.path.split(Platform.pathSeparator).last;
          final bytes = await entity.readAsBytes();

          final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';

          final validationError = SecurityConfig.validateFile(
            fileName: fileName,
            mimeType: mimeType,
            sizeBytes: bytes.length,
          );

          if (validationError == null) {
            widget.onFilePicked?.call(fileName, bytes, mimeType);
            count++;
          }
        }
      }
      if (mounted && count == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid files found in folder')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Folder upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar for bottom sheet
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Upload File',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              'Pick a file from your device or extract a ZIP archive',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 24),

            if (_uploading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(
                    color: Colors.amber,
                    strokeWidth: 3,
                  ),
                ),
              )
            else
              Row(
                children: [
                  // Extract ZIP button
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.unarchive_outlined,
                      label: 'Extract ZIP',
                      onTap: widget.onExtractZip,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Real file picker button
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.cloud_upload_outlined,
                      label: 'File',
                      onTap: _pickRealFile,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Folder picker button
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.folder_open_outlined,
                      label: 'Folder',
                      onTap: _pickFolder,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.amber.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        highlightColor: Colors.amber.withOpacity(0.1),
        splashColor: Colors.amber.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.amber.withOpacity(0.2),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.amber, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
