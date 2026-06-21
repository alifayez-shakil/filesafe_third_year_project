import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../../utils/models/file_item.dart';
import '../../services/file_service.dart';

class ImageGalleryPage extends StatefulWidget {
  final List<FileItem> imageFiles;
  const ImageGalleryPage({super.key, required this.imageFiles});

  @override
  State<ImageGalleryPage> createState() => _ImageGalleryPageState();
}

class _ImageGalleryPageState extends State<ImageGalleryPage>
    with TickerProviderStateMixin {
  int _columns = 3;
  bool _selectMode = false;
  final Set<String> _selected = {};
  String _sortBy = 'date';

  // ─── Thumbnail cache ──────────────────────────────────────────
  final Map<String, Uint8List> _thumbnailCache = {};

  late AnimationController _selectAnimCtrl;
  late Animation<double> _selectScale;

  @override
  void initState() {
    super.initState();
    _selectAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _selectScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _selectAnimCtrl,
        curve: const Cubic(0.25, 1.0, 0.5, 1.0),
      ),
    );
  }

  @override
  void dispose() {
    _selectAnimCtrl.dispose();
    super.dispose();
  }

  List<FileItem> get _images =>
      widget.imageFiles.where((f) => f.type == FileType.image).toList();

  List<FileItem> get _sorted {
    final list = List.of(_images);
    switch (_sortBy) {
      case 'name':
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'size':
        list.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
        break;
      default:
        list.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    }
    return list;
  }

  Map<String, List<FileItem>> get _grouped {
    final map = <String, List<FileItem>>{};
    final now = DateTime.now();
    for (final f in _sorted) {
      final diff = now.difference(f.uploadedAt);
      String bucket;
      if (diff.inHours < 24) {
        bucket = 'Today';
      } else if (diff.inDays < 7) {
        bucket = 'Recent Days';
      } else {
        bucket = '${_monthName(f.uploadedAt.month)} ${f.uploadedAt.year}';
      }
      map.putIfAbsent(bucket, () => []).add(f);
    }
    return map;
  }

  String _monthName(int m) => const [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][m];

  void _toggleSelect(String id) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
      if (_selected.isEmpty) {
        _selectMode = false;
        _selectAnimCtrl.reverse();
      }
    });
  }

  void _enterSelectMode(String id) {
    HapticFeedback.heavyImpact();
    setState(() {
      _selectMode = true;
      _selected.add(id);
      _selectAnimCtrl.forward();
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selected.clear();
      _selectAnimCtrl.reverse();
    });
  }

  // ─── Bulk actions (persist to Supabase) ──────────────────────
  void _bulkStar() async {
    final toStar = _images.where((f) => _selected.contains(f.id));
    for (final f in toStar) {
      f.isStarred = true;
      await FileService.toggleStar(f.id);
    }
    _exitSelectMode();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Starred selected images'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _bulkDelete() async {
    final toDelete = _images.where((f) => _selected.contains(f.id));
    for (final f in toDelete) {
      f.isDeleted = true;
      f.deletedAt = DateTime.now();
      await FileService.deleteFile(f.id);
    }
    _exitSelectMode();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Moved to bin'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = _images;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Stack(
        children: [
          images.isEmpty
              ? _emptyState()
              : GestureDetector(
                  onScaleUpdate: (details) {
                    if (details.scale < 0.8 && _columns < 5) {
                      setState(() => _columns++);
                      HapticFeedback.selectionClick();
                    } else if (details.scale > 1.25 && _columns > 2) {
                      setState(() => _columns--);
                      HapticFeedback.selectionClick();
                    }
                  },
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      SliverAppBar.large(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        scrolledUnderElevation: 0,
                        // ── Back button ──
                        leading: IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        title: Text(
                          'Library',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black,
                            letterSpacing: -0.5,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: _selectMode
                                ? _exitSelectMode
                                : () => setState(() {
                                    _selectMode = true;
                                    _selectAnimCtrl.forward();
                                  }),
                            child: Text(
                              _selectMode ? 'Cancel' : 'Select',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          if (!_selectMode) _buildMenuButton(isDark),
                        ],
                      ),
                      ..._grouped.entries.expand(
                        (entry) => [
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _iOSHeaderDelegate(
                              title: entry.key,
                              count: entry.value.length,
                              isDark: isDark,
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2.0,
                            ),
                            sliver: SliverGrid(
                              delegate: SliverChildBuilderDelegate(
                                (_, i) => AnimatedBuilder(
                                  animation: _selectScale,
                                  builder: (_, child) => Transform.scale(
                                    scale:
                                        _selectMode &&
                                            !_selected.contains(
                                              entry.value[i].id,
                                            )
                                        ? _selectScale.value
                                        : 1.0,
                                    child: child,
                                  ),
                                  child: _ImageTile(
                                    file: entry.value[i],
                                    isSelected: _selected.contains(
                                      entry.value[i].id,
                                    ),
                                    selectMode: _selectMode,
                                    thumbnailCache: _thumbnailCache,
                                    onTap: () {
                                      if (_selectMode) {
                                        _toggleSelect(entry.value[i].id);
                                      } else {
                                        _openViewer(entry.value, i);
                                      }
                                    },
                                    onLongPress: () =>
                                        _enterSelectMode(entry.value[i].id),
                                  ),
                                ),
                                childCount: entry.value.length,
                              ),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: _columns,
                                    crossAxisSpacing: 2,
                                    mainAxisSpacing: 2,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 140)),
                    ],
                  ),
                ),
          if (_selectMode) _buildBottomActionBar(isDark),
        ],
      ),
    );
  }

  Widget _buildMenuButton(bool isDark) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz_rounded, color: Colors.blue, size: 26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (v) => setState(() => _sortBy = v),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'date',
          child: _buildMenuItem('Date Added', _sortBy == 'date'),
        ),
        PopupMenuItem(
          value: 'name',
          child: _buildMenuItem('File Name', _sortBy == 'name'),
        ),
        PopupMenuItem(
          value: 'size',
          child: _buildMenuItem('File Size', _sortBy == 'size'),
        ),
      ],
    );
  }

  Widget _buildMenuItem(String label, bool active) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        if (active) const Icon(Icons.check, color: Colors.blue, size: 18),
      ],
    );
  }

  Widget _buildBottomActionBar(bool isDark) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: isDark
                ? Colors.black.withValues(alpha: 0.65)
                : Colors.white.withValues(alpha: 0.75),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 12,
              top: 12,
              left: 24,
              right: 24,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                    size: 26,
                  ),
                  onPressed: _selected.isEmpty ? null : _bulkDelete,
                ),
                Text(
                  _selected.isEmpty
                      ? 'Select Items'
                      : '${_selected.length} Selected',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.favorite_border_rounded,
                    color: Colors.blue,
                    size: 26,
                  ),
                  onPressed: _selected.isEmpty ? null : _bulkStar,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() => const Center(
    child: Text(
      'No Photos or Videos',
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.grey,
      ),
    ),
  );

  void _openViewer(List<FileItem> images, int index) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            _FullScreenViewer(images: images, initialIndex: index),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}

// ─── Header Delegate ──────────────────────────────────────────────
class _iOSHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final int count;
  final bool isDark;
  _iOSHeaderDelegate({
    required this.title,
    required this.count,
    required this.isDark,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          color: isDark
              ? Colors.black.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: isDark ? Colors.white : Colors.black,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 42;
  @override
  double get minExtent => 42;
  @override
  bool shouldRebuild(covariant _iOSHeaderDelegate oldDelegate) =>
      oldDelegate.title != title;
}

// ─── Image Tile with Thumbnail ──────────────────────────────────
class _ImageTile extends StatefulWidget {
  final FileItem file;
  final bool isSelected;
  final bool selectMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Map<String, Uint8List> thumbnailCache;

  const _ImageTile({
    required this.file,
    required this.isSelected,
    required this.selectMode,
    required this.onTap,
    required this.onLongPress,
    required this.thumbnailCache,
  });

  @override
  State<_ImageTile> createState() => _ImageTileState();
}

class _ImageTileState extends State<_ImageTile> {
  Uint8List? _bytes;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    if (widget.thumbnailCache.containsKey(widget.file.id)) {
      setState(() => _bytes = widget.thumbnailCache[widget.file.id]);
      return;
    }
    if (_loading) return;
    _loading = true;
    try {
      final bytes = await FileService.downloadFile(widget.file.id);
      if (mounted) {
        widget.thumbnailCache[widget.file.id] = bytes;
        setState(() => _bytes = bytes);
      }
    } catch (_) {
      // ignore
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Thumbnail or placeholder ──
          if (_bytes != null)
            Image.memory(_bytes!, fit: BoxFit.cover)
          else
            Container(
              color: Colors.grey.shade900,
              child: Center(
                child: _loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.amber,
                        ),
                      )
                    : Icon(
                        Icons.image_rounded,
                        size: 28,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
              ),
            ),

          // ── Selection overlay ──
          if (widget.selectMode && widget.isSelected)
            Container(color: Colors.black.withValues(alpha: 0.25)),

          // ── Star badge ──
          if (widget.file.isStarred)
            const Positioned(
              bottom: 6,
              right: 6,
              child: Icon(
                Icons.favorite_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),

          // ── Selection checkbox ──
          if (widget.selectMode)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: widget.isSelected ? Colors.blue : Colors.black12,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: widget.isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Full‑Screen Viewer (unchanged) ──────────────────────────────
class _FullScreenViewer extends StatefulWidget {
  final List<FileItem> images;
  final int initialIndex;
  const _FullScreenViewer({required this.images, required this.initialIndex});

  @override
  State<_FullScreenViewer> createState() => _FullScreenViewerState();
}

class _FullScreenViewerState extends State<_FullScreenViewer> {
  late PageController _pageCtrl;
  late int _current;
  bool _chromeVisible = true;
  double _dragOffset = 0.0;
  final Map<int, Uint8List?> _imageCache = {};

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
    _loadCurrentImage();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentImage() async {
    final file = widget.images[_current];
    if (_imageCache.containsKey(_current)) return;
    try {
      final bytes = await FileService.downloadFile(file.id);
      if (mounted) setState(() => _imageCache[_current] = bytes);
    } catch (_) {
      if (mounted) setState(() => _imageCache[_current] = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.images[_current];
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black.withValues(
        alpha: (1.0 - (_dragOffset / size.height)).clamp(0.0, 1.0),
      ),
      body: GestureDetector(
        onTap: () => setState(() => _chromeVisible = !_chromeVisible),
        onVerticalDragUpdate: (details) {
          setState(() => _dragOffset += details.primaryDelta!);
        },
        onVerticalDragEnd: (details) {
          if (_dragOffset.abs() > 140) {
            Navigator.pop(context);
          } else {
            setState(() => _dragOffset = 0.0);
          }
        },
        child: Stack(
          children: [
            Transform.translate(
              offset: Offset(0, _dragOffset),
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: widget.images.length,
                onPageChanged: (i) {
                  setState(() => _current = i);
                  _loadCurrentImage();
                },
                itemBuilder: (_, i) {
                  final cachedBytes = _imageCache[i];
                  return InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 3.0,
                    child: Center(
                      child: cachedBytes != null
                          ? Image.memory(cachedBytes, fit: BoxFit.contain)
                          : cachedBytes == null && _imageCache.containsKey(i)
                          ? const Icon(
                              Icons.broken_image,
                              color: Colors.white30,
                              size: 64,
                            )
                          : const Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(
                                color: Colors.amber,
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),
            if (_chromeVisible) _buildTopOverlay(file),
            if (_chromeVisible) _buildBottomViewerControls(file),
          ],
        ),
      ),
    );
  }

  Widget _buildTopOverlay(FileItem file) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 4,
          bottom: 12,
        ),
        color: Colors.black45,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.blue,
                size: 22,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            Column(
              children: [
                Text(
                  file.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${_current + 1} of ${widget.images.length}',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomViewerControls(FileItem file) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.black45,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 12,
          top: 12,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.blue),
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(
                file.isStarred
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: Colors.blue,
              ),
              onPressed: () {
                setState(() {
                  file.isStarred = !file.isStarred;
                  FileService.toggleStar(file.id);
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.info_outline_rounded, color: Colors.blue),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.blue,
              ),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
