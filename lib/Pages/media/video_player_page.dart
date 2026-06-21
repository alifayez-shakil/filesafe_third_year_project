import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../services/file_service.dart';

class VideoItem {
  final String title;
  final String filePath;
  final String resolution;
  final String duration;
  final bool isFileId;

  const VideoItem({
    required this.title,
    required this.filePath,
    this.resolution = '',
    this.duration = '',
    this.isFileId = false,
  });
}

class VideoPlayerPage extends StatefulWidget {
  final List<VideoItem> videos;
  final int initialIndex;

  const VideoPlayerPage({
    super.key,
    required this.videos,
    this.initialIndex = 0,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  VideoPlayerController? _controller;
  int _currentIndex = 0;
  bool _isInitialized = false;
  bool _isPlaying = true;
  bool _isLoading = false;
  String? _tempPath; // track temporary file for cleanup

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.videos.length - 1);
    _loadVideo(widget.videos[_currentIndex]);
  }

  Future<void> _loadVideo(VideoItem item) async {
    setState(() {
      _isLoading = true;
      _isInitialized = false;
    });

    try {
      String localPath;

      if (item.isFileId) {
        // Download file to temporary directory
        localPath = await FileService.downloadToTempFile(
          item.filePath,
          fileName: item.title,
        );
        _tempPath = localPath;
      } else {
        // Already a local path – verify it exists
        localPath = item.filePath;
        final file = File(localPath);
        if (!await file.exists()) {
          throw Exception('File not found: $localPath');
        }
      }

      if (!mounted) return;

      _controller?.dispose();
      _controller = VideoPlayerController.file(File(localPath))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _isInitialized = true;
              _isLoading = false;
            });
            _controller!.play();
            _controller!.addListener(_videoListener);
          }
        });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _videoListener() {
    if (mounted && _controller != null) {
      setState(() {
        _isPlaying = _controller!.value.isPlaying;
      });
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    // Clean up temporary file
    if (_tempPath != null) {
      try {
        File(_tempPath!).deleteSync(recursive: true);
      } catch (_) {}
    }
    super.dispose();
  }

  void _playPause() {
    if (_controller == null || !_isInitialized) return;
    HapticFeedback.lightImpact();
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
    setState(() {});
  }

  void _seekTo(double value) {
    if (_controller == null || !_isInitialized) return;
    final duration = _controller!.value.duration;
    final position = Duration(
      milliseconds: (value * duration.inMilliseconds).round(),
    );
    _controller!.seekTo(position);
  }

  void _next() {
    if (_currentIndex < widget.videos.length - 1) {
      HapticFeedback.mediumImpact();
      setState(() {
        _currentIndex++;
        _loadVideo(widget.videos[_currentIndex]);
      });
    }
  }

  void _previous() {
    if (_currentIndex > 0) {
      HapticFeedback.mediumImpact();
      setState(() {
        _currentIndex--;
        _loadVideo(widget.videos[_currentIndex]);
      });
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videos.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Video Player'),
        ),
        body: const Center(
          child: Text(
            'No videos found',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final current = widget.videos[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F14),
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              current.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              current.resolution,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Video viewport
          Container(
            height: 230,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.amber),
                  )
                : _isInitialized && _controller != null
                ? Center(
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                  )
                : const Center(
                    child: Text(
                      'Failed to load video',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
          ),

          // Controls dashboard (unchanged)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                if (_isInitialized && _controller != null) ...[
                  Row(
                    children: [
                      Text(
                        _formatDuration(_controller!.value.position),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4.0,
                            activeTrackColor: Colors.amber,
                            inactiveTrackColor: Colors.white10,
                            thumbColor: Colors.amber,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6.0,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 14.0,
                            ),
                          ),
                          child: Slider(
                            value:
                                (_controller!.value.duration.inMilliseconds > 0)
                                ? (_controller!.value.position.inMilliseconds /
                                      _controller!
                                          .value
                                          .duration
                                          .inMilliseconds)
                                : 0.0,
                            onChanged: _seekTo,
                          ),
                        ),
                      ),
                      Text(
                        _formatDuration(_controller!.value.duration),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),

                // Playback buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.skip_previous_rounded,
                        color: _currentIndex > 0
                            ? Colors.white
                            : Colors.white24,
                        size: 28,
                      ),
                      onPressed: _currentIndex > 0 ? _previous : null,
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: _playPause,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.black,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: Icon(
                        Icons.skip_next_rounded,
                        color: _currentIndex < widget.videos.length - 1
                            ? Colors.white
                            : Colors.white24,
                        size: 28,
                      ),
                      onPressed: _currentIndex < widget.videos.length - 1
                          ? _next
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Playlist header (unchanged)
          Padding(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Queue / Playlist',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.1,
                  ),
                ),
                Text(
                  '${_currentIndex + 1}/${widget.videos.length}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Playlist (unchanged)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: widget.videos.length,
              itemBuilder: (_, i) {
                final v = widget.videos[i];
                final active = i == _currentIndex;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF1E1E26)
                        : const Color(0xFF15151B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active
                          ? Colors.amber.withValues(alpha: 0.3)
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.amber.withValues(alpha: 0.1)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          active
                              ? Icons.play_arrow_rounded
                              : Icons.movie_outlined,
                          color: active ? Colors.amber : Colors.grey,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        v.title,
                        style: TextStyle(
                          color: active
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: active
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          children: [
                            Text(
                              v.duration,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: const BoxDecoration(
                                color: Colors.white24,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              v.resolution,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: active
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'NOW PLAYING',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.reorder_rounded,
                              color: Colors.white24,
                              size: 16,
                            ),
                      onTap: () {
                        if (active) return;
                        setState(() {
                          _currentIndex = i;
                          _loadVideo(v);
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
