import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import '../../services/file_service.dart';
import '../../utils/widgets/shimmer_loading.dart';

class AudioTrack {
  final String title;
  final String artist;
  final String filePath;
  final bool isFileId;

  const AudioTrack({
    required this.title,
    required this.artist,
    required this.filePath,
    this.isFileId = false,
  });
}

// ─── Main Widget ────────────────────────────────────
class MediaPlayerPage extends StatefulWidget {
  final List<AudioTrack> tracks;
  final int initialIndex;

  const MediaPlayerPage({
    super.key,
    required this.tracks,
    this.initialIndex = 0,
  });

  @override
  State<MediaPlayerPage> createState() => _MediaPlayerPageState();
}

// ─── State ──────────────────────────────────────────
class _MediaPlayerPageState extends State<MediaPlayerPage> {
  late AudioPlayer _player;
  late int _current;
  bool _isLoading = true;
  String? _error;
  String? _tempPath;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex.clamp(0, widget.tracks.length - 1);
    _player = AudioPlayer();
    _loadCurrentTrack();
  }

  Future<void> _loadCurrentTrack() async {
    if (widget.tracks.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final track = widget.tracks[_current];
      String localPath;

      if (track.isFileId) {
        // Download the file to a temporary directory
        localPath = await FileService.downloadToTempFile(
          track.filePath,
          fileName: track.title,
        );
        _tempPath = localPath;
      } else {
        localPath = track.filePath;
      }

      await _player.setFilePath(localPath);
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    // ── Safe cleanup ──
    if (_tempPath != null) {
      try {
        File(_tempPath!).deleteSync(recursive: true);
      } catch (_) {
        // File may still be locked – ignore, OS will clean up eventually
      }
    }
    super.dispose();
  }

  void _playPause() {
    HapticFeedback.lightImpact();
    if (_player.playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void _next() {
    HapticFeedback.lightImpact();
    if (_current < widget.tracks.length - 1) {
      setState(() => _current++);
      _loadCurrentTrack();
    }
  }

  void _previous() {
    HapticFeedback.lightImpact();
    if (_current > 0) {
      setState(() => _current--);
      _loadCurrentTrack();
    }
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  void _showQueueBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _buildQueueSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tracks.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(color: Colors.white),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.library_music_outlined,
                size: 72,
                color: Colors.grey.shade700,
              ),
              const SizedBox(height: 16),
              const Text(
                'No audio tracks loaded',
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    final track = widget.tracks[_current];

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white70,
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'NOW PLAYING',
          style: TextStyle(
            color: Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.queue_music_rounded, color: Colors.white70),
            onPressed: _showQueueBottomSheet,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1E3A8A), Color(0xFF0B0F19)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 12,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Hero(
                    tag: 'audio-${track.title}',
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.75,
                      height: MediaQuery.of(context).size.width * 0.75,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isLoading
                            ? const DashboardShimmer()
                            : _error != null
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    size: 56,
                                    color: Colors.redAccent,
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton.icon(
                                    icon: const Icon(
                                      Icons.refresh,
                                      color: Colors.amber,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Retry',
                                      style: TextStyle(color: Colors.amber),
                                    ),
                                    onPressed: _loadCurrentTrack,
                                  ),
                                ],
                              )
                            : Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.music_note_rounded,
                                  size: 56,
                                  color: Color.fromARGB(255, 214, 171, 171),
                                ),
                              ),
                      ),
                    ),
                  ),

                  Column(
                    children: [
                      Text(
                        track.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        track.artist,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),

                  if (!_isLoading && _error == null)
                    StreamBuilder<Duration>(
                      stream: _player.positionStream,
                      builder: (_, snap) {
                        final pos = snap.data ?? Duration.zero;
                        final dur = _player.duration ?? Duration.zero;
                        final progress = dur.inMilliseconds > 0
                            ? pos.inMilliseconds / dur.inMilliseconds
                            : 0.0;

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3.5,
                                activeTrackColor: Colors.amber.shade400,
                                inactiveTrackColor: Colors.white10,
                                thumbColor: Colors.white,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 14,
                                ),
                                trackShape: const RoundedRectSliderTrackShape(),
                              ),
                              child: Slider(
                                value: progress.clamp(0.0, 1.0),
                                onChanged: (v) => _player.seek(
                                  Duration(
                                    milliseconds: (v * dur.inMilliseconds)
                                        .round(),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _fmt(pos),
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  Text(
                                    _fmt(dur),
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.skip_previous_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                        onPressed: _current > 0 ? _previous : null,
                        disabledColor: Colors.white12,
                      ),
                      const SizedBox(width: 24),
                      StreamBuilder<PlayerState>(
                        stream: _player.playerStateStream,
                        builder: (_, snap) {
                          final playing = snap.data?.playing ?? false;
                          return InkWell(
                            onTap: _playPause,
                            customBorder: const CircleBorder(),
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.black,
                                size: 40,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        icon: const Icon(
                          Icons.skip_next_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                        onPressed: _current < widget.tracks.length - 1
                            ? _next
                            : null,
                        disabledColor: Colors.white12,
                      ),
                    ],
                  ),

                  GestureDetector(
                    onTap: _showQueueBottomSheet,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: Colors.white38,
                        ),
                        Text(
                          'SWIPE UP FOR QUEUE',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.40,
      maxChildSize: 0.90,
      builder: (context, controller) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              color: const Color(0xFF0F172A).withOpacity(0.75),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 36,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Up Next',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      itemCount: widget.tracks.length,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemBuilder: (context, i) {
                        final t = widget.tracks[i];
                        final active = i == _current;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 2,
                          ),
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: active
                                  ? Colors.amber.withOpacity(0.12)
                                  : Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              active
                                  ? Icons.volume_up_rounded
                                  : Icons.music_note_rounded,
                              color: active
                                  ? Colors.amber.shade400
                                  : Colors.white38,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            t.title,
                            style: TextStyle(
                              color: active
                                  ? Colors.amber.shade400
                                  : Colors.white,
                              fontWeight: active
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            t.artist,
                            style: TextStyle(
                              color: active
                                  ? Colors.amber.shade200.withOpacity(0.6)
                                  : Colors.grey.shade400,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            if (i != _current) {
                              Navigator.pop(context);
                              setState(() => _current = i);
                              _loadCurrentTrack();
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
