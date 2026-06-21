import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/download_history_service.dart';
import '../../services/share_service.dart';
import '../../utils/helpers/file_helper.dart';
import '../../utils/widgets/shimmer_loading.dart';
import '../media/pdf_reader_page.dart';
import '../media/image_viewer_page.dart';
import '../media/text_editor_page.dart';
import '../media/video_player_page.dart';
import '../media/media_player_page.dart';
import '../media/spreadsheet_viewer_page.dart';

class SharedWithMePage extends StatefulWidget {
  const SharedWithMePage({super.key});

  @override
  State<SharedWithMePage> createState() => _SharedWithMePageState();
}

class _SharedWithMePageState extends State<SharedWithMePage> {
  final _tokenCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  /// Extracts the token from a full URL or returns the input as‑is.
  String _extractToken(String input) {
    final trimmed = input.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) return segments.last;
    }
    return trimmed;
  }

  /// Main entry point: validate input, call the service, and handle the result.
  Future<void> _openLink() async {
    final rawInput = _tokenCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (rawInput.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter both the link/token and password.');
      return;
    }

    final token = _extractToken(rawInput);
    if (token.length < 10) {
      setState(() => _error = 'Invalid token — too short.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ShareService.openSharedLink(
        token: token,
        password: password,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      await _handleResult(result);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  /// Decides what to do based on the file type and permission.
  Future<void> _handleResult(SharedFileResult result) async {
    final bytes = result.bytes;
    final permission = result.permission;
    final fileName = result.fileName;
    final ext = FileHelper.extension(fileName);
    final fileType = FileHelper.detectTypeFromBytes(bytes);

    // ── DOWNLOAD permission — save immediately, no viewer ──
    if (permission == 'DOWNLOAD') {
      await _saveToDevice(bytes, fileName);
      return;
    }

    // ── VIEW / EDIT — open the appropriate viewer ──
    switch (fileType) {
      case 'pdf':
        await _openPdf(bytes, fileName);
        break;
      case 'png':
      case 'jpg':
      case 'gif':
      case 'bmp':
        _openImage(bytes, fileName);
        break;
      case 'mp4':
      case 'mov':
        await _openVideo(bytes, fileName);
        break;
      case 'mp3':
      case 'wav':
        await _openAudio(bytes, fileName);
        break;
      case 'zip':
        // XLSX, XLS, CSV are ZIP‑based; try spreadsheet viewer first
        if (['xlsx', 'xls', 'csv'].contains(ext)) {
          await _openSpreadsheet(bytes, fileName);
        } else {
          // Other ZIP files (e.g., .docx, .pptx, plain zip) – offer save
          _showSaveDialog(bytes, fileName);
        }
        break;
      case 'text':
        _openText(bytes, fileName, editable: permission == 'EDIT');
        break;
      default:
        _showSaveDialog(bytes, fileName);
    }
  }

  // ─── Individual viewer methods ─────────────────────────────

  Future<void> _openPdf(Uint8List bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfReaderPage(
          fileName: fileName,
          filePath: file.path,
          isFileId: false,
        ),
      ),
    );
  }

  void _openImage(Uint8List bytes, String fileName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageViewerPage(fileName: fileName, imageBytes: bytes),
      ),
    );
  }

  Future<void> _openVideo(Uint8List bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(
          videos: [
            VideoItem(
              title: fileName,
              filePath: file.path,
              resolution: '',
              duration: '',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAudio(Uint8List bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaPlayerPage(
          tracks: [
            AudioTrack(
              title: fileName,
              artist: 'Shared File',
              filePath: file.path,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSpreadsheet(Uint8List bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SpreadsheetViewerPage(
          filePath: file.path,
          fileName: fileName,
          isFileId: false,
        ),
      ),
    );
  }

  void _openText(Uint8List bytes, String fileName, {bool editable = false}) {
    final text = utf8.decode(bytes, allowMalformed: true);
    if (editable) {
      // EDIT permission – open editable text editor
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TextEditorPage(
            fileName: fileName,
            initialContent: text,
            fileId: null,
          ),
        ),
      );
    } else {
      // VIEW permission – read‑only dialog with copy
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(fileName, overflow: TextOverflow.ellipsis),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              child: SelectableText(
                text,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
                Navigator.pop(context);
              },
              child: const Text('Copy'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _saveToDevice(Uint8List bytes, String fileName) async {
    try {
      final dir =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      try {
        await DownloadHistoryService.logDownload(
          fileId: '',
          fileName: fileName,
          fileSizeBytes: bytes.length,
        );
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved: ${file.path}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showError('Failed to save: $e');
    }
  }

  /// Shows a dialog asking the user if they want to save an unknown file type.
  void _showSaveDialog(Uint8List bytes, String fileName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('File Received'),
        content: Text(
          '$fileName\n${FileHelper.formatBytes(bytes.length)}\n\n'
          'No viewer for this file type. Save to device?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(context);
              _saveToDevice(bytes, fileName);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ─── UI ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Shared Link'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.link_rounded, size: 48, color: Colors.amber),
            const SizedBox(height: 16),
            const Text(
              'Enter the shared link or token',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Paste the full URL or just the token',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Token / Link input
            TextField(
              controller: _tokenCtrl,
              decoration: InputDecoration(
                labelText: 'Share Link or Token',
                hintText: 'e.g. https://.../share/abc123 or just abc123',
                prefixIcon: const Icon(Icons.vpn_key),
                suffixIcon: _tokenCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _tokenCtrl.clear()),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Password input with visibility toggle
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Error message
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _loading ? null : _openLink,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text(
                        'Open File',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
