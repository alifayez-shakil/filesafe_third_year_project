import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/file_service.dart';
import '../../utils/widgets/shimmer_loading.dart';

class PdfReaderPage extends StatefulWidget {
  final String? filePath;
  final String fileName;
  final bool isFileId;

  const PdfReaderPage({
    super.key,
    this.filePath,
    required this.fileName,
    this.isFileId = false,
  });

  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage> {
  PDFViewController? _pdfController;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _loading = true;
  bool _pdfLoading = true;

  List<int> _bookmarks = [];
  bool _showControls = true;
  String? _tempPath;
  String? _localFilePath;
  @override
  void initState() {
    super.initState();
    _loadBookmarks();
    _loadLastPage();
    _ensureFileExists();
  }

  Future<void> _ensureFileExists() async {
    if (widget.filePath == null) {
      setState(() {
        _loading = false;
        _pdfLoading = false;
      });
      return;
    }

    try {
      String localPath;

      if (widget.isFileId) {
        // Download file to temporary directory
        localPath = await FileService.downloadToTempFile(
          widget.filePath!,
          fileName: widget.fileName,
        );
        _tempPath = localPath;
      } else {
        // Already a local path – check existence
        localPath = widget.filePath!;
        final file = File(localPath);
        if (!await file.exists()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('PDF file not found on device.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() {
            _loading = false;
            _pdfLoading = false;
          });
          return;
        }
      }

      setState(() {
        _localFilePath = localPath;
        _loading = false;
        _pdfLoading = true;
      });

      // The PDFView will now load from _localFilePath.
      // It will call onRender when ready.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _loading = false;
        _pdfLoading = false;
      });
    }
  }

  // ── Bookmarks ────────────────────────────────────────────────
  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'bookmarks_${widget.fileName}';
    final saved = prefs.getStringList(key) ?? [];
    _bookmarks = saved
        .map((e) => int.tryParse(e) ?? -1)
        .where((e) => e > 0)
        .toList();
    if (mounted) setState(() {});
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'bookmarks_${widget.fileName}';
    await prefs.setStringList(
      key,
      _bookmarks.map((e) => e.toString()).toList(),
    );
  }

  Future<void> _loadLastPage() async {
    final prefs = await SharedPreferences.getInstance();
    final lastPage = prefs.getInt('last_page_${widget.fileName}');
    if (lastPage != null && lastPage > 0) {
      _currentPage = lastPage;
    }
  }

  Future<void> _saveLastPage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_page_${widget.fileName}', _currentPage);
  }

  void _toggleBookmark(int page) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_bookmarks.contains(page)) {
        _bookmarks.remove(page);
      } else {
        _bookmarks.add(page);
      }
    });
    _saveBookmarks();
  }

  void _jumpToPage() {
    HapticFeedback.lightImpact();
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Jump to page'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Enter page number'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () {
              final page = int.tryParse(controller.text);
              if (page != null && page >= 1 && page <= _totalPages) {
                _pdfController?.setPage(page - 1);
                Navigator.pop(context);
              }
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }

  void _showBookmarks() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Bookmarks (${_bookmarks.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              if (_bookmarks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No bookmarks yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                ..._bookmarks.map(
                  (page) => ListTile(
                    leading: const Icon(Icons.bookmark, color: Colors.amber),
                    title: Text('Page $page'),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _toggleBookmark(page);
                        Navigator.pop(context);
                      },
                    ),
                    onTap: () {
                      _pdfController?.setPage(page - 1);
                      Navigator.pop(context);
                    },
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _saveLastPage();
    // Clean up temporary file
    if (_tempPath != null) {
      try {
        File(_tempPath!).deleteSync(recursive: true);
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            tooltip: 'Bookmarks',
            onPressed: _showBookmarks,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Jump to page',
            onPressed: _jumpToPage,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Still loading the file
    if (_loading) {
      return const DashboardShimmer();
    }

    // No file path provided or file not resolved
    if (_localFilePath == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.picture_as_pdf, size: 80, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                widget.fileName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'PDF could not be loaded.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.6),
              ),
            ],
          ),
        ),
      );
    }

    // PDF viewer
    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      child: Hero(
        tag: 'pdf-${widget.fileName}',
        child: Stack(
          children: [
            PDFView(
              filePath: _localFilePath!,
              enableSwipe: true,
              swipeHorizontal: false,
              autoSpacing: true,
              pageFling: true,
              defaultPage: _currentPage - 1,
              onRender: (total) {
                setState(() {
                  _totalPages = total ?? 0;
                  _pdfLoading = false;
                });
              },
              onViewCreated: (controller) {
                _pdfController = controller;
              },
              onPageChanged: (page, total) {
                setState(() {
                  _currentPage = (page ?? 0) + 1;
                });
              },
            ),
            // Floating bookmark button
            Positioned(
              right: 16,
              bottom: 100,
              child: FloatingActionButton(
                heroTag: 'bookmark',
                mini: true,
                backgroundColor: _bookmarks.contains(_currentPage)
                    ? Colors.amber
                    : Colors.grey[300],
                onPressed: () => _toggleBookmark(_currentPage),
                child: Icon(
                  _bookmarks.contains(_currentPage)
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  color: _bookmarks.contains(_currentPage)
                      ? Colors.white
                      : Colors.black54,
                ),
              ),
            ),
            if (_showControls) _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: const Offset(0, -2),
            ),
          ],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Page slider
              Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      '$_currentPage',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: _currentPage.toDouble(),
                      min: 1,
                      max: _totalPages.toDouble().clamp(1, double.infinity),
                      divisions: _totalPages > 1 ? _totalPages - 1 : 1,
                      activeColor: Colors.amber,
                      label: '$_currentPage',
                      onChanged: (v) {
                        _pdfController?.setPage(v.toInt() - 1);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '$_totalPages',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
              // Navigation only (no fake zoom)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _currentPage > 1
                        ? () {
                            HapticFeedback.lightImpact();
                            _pdfController?.setPage(_currentPage - 2);
                          }
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Page $_currentPage of $_totalPages',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage < _totalPages
                        ? () {
                            HapticFeedback.lightImpact();
                            _pdfController?.setPage(_currentPage);
                          }
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
