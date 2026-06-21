import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';
import '../../utils/models/file_item.dart';
import '../../utils/widgets/file_icon.dart';

class ImageViewerPage extends StatefulWidget {
  final String fileName;
  final Uint8List? imageBytes;
  final String? localPath;

  const ImageViewerPage({
    super.key,
    required this.fileName,
    this.imageBytes,
    this.localPath,
  });

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  final TransformationController _transformController =
      TransformationController();
  bool _showOverlay = true;
  int _rotation = 0;

  @override
  void initState() {
    super.initState();
    // Default system padding treatment
    _updateSystemUi();
  }

  String get _fileSizeFormatted {
    if (widget.imageBytes != null) {
      return _formatBytes(widget.imageBytes!.length);
    }
    if (widget.localPath != null) {
      final file = File(widget.localPath!);
      if (file.existsSync()) {
        return _formatBytes(file.lengthSync());
      }
    }
    return 'Unknown size';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
      _updateSystemUi();
    });
  }

  void _updateSystemUi() {
    if (_showOverlay) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  void _rotateClockwise() {
    HapticFeedback.mediumImpact();
    setState(() => _rotation = (_rotation + 90) % 360);
  }

  @override
  void dispose() {
    // Restore generic system layout spaces on exit
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    Widget imageWidget;
    if (widget.imageBytes != null) {
      imageWidget = Image.memory(
        widget.imageBytes!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _placeholderImage(),
      );
    } else if (widget.localPath != null &&
        File(widget.localPath!).existsSync()) {
      imageWidget = Image.file(
        File(widget.localPath!),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _placeholderImage(),
      );
    } else {
      imageWidget = _placeholderImage();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleOverlay,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // ── Interactive Zoom Viewport Core ──
            Positioned.fill(
              child: Center(
                child: Hero(
                  tag: 'image-${widget.fileName}',
                  child: InteractiveViewer(
                    transformationController: _transformController,
                    minScale: 0.8,
                    maxScale: 4.0,
                    clipBehavior: Clip.none,
                    child: RotatedBox(
                      quarterTurns: _rotation ~/ 90,
                      child: SizedBox(
                        width: mediaQuery.size.width,
                        height: mediaQuery.size.height,
                        child: imageWidget,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Smooth Sliding Top Navigation Overlay ──
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              top: _showOverlay ? 0 : -110,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {}, // Prevent backdrop layer tap dispersion
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.4),
                      padding: EdgeInsets.only(top: mediaQuery.padding.top),
                      child: AppBar(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        scrolledUnderElevation: 0,
                        leading: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        title: Text(
                          widget.fileName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        actions: [
                          IconButton(
                            icon: const Icon(
                              Icons.rotate_90_degrees_cw_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: _rotateClockwise,
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.ios_share_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Share coming soon'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Smooth Sliding Bottom Panel Metadata Overlay ──
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              bottom: _showOverlay ? 0 : -100,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {},
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.4),
                      padding: EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 16,
                        bottom: mediaQuery.padding.bottom > 0
                            ? mediaQuery.padding.bottom
                            : 16,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: FileIcon(type: FileType.image, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.fileName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Image Format File',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _fileSizeFormatted,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderImage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_rounded,
            size: 48,
            color: Colors.grey.shade800,
          ),
          const SizedBox(height: 12),
          Text(
            'Unable to load preview asset',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
