import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../Pages/auth/login_page.dart';
import '../../Pages/auth/register_page.dart';
import '../../Pages/home/home_page.dart';
import '../../Pages/account/profile_page.dart';
import '../../Pages/account/download_history.dart';
import '../../Pages/account/about_page.dart';
import '../../Pages/media/media_player_page.dart';
import '../../Pages/media/video_player_page.dart';
import '../../Pages/media/pdf_reader_page.dart';
import '../../Pages/media/text_editor_page.dart';
import '../../Pages/media/image_viewer_page.dart';
import '../../Pages/smart/categorization_page.dart';
import '../../Pages/smart/duplicate_detection_page.dart';
import '../../Pages/media/timeline_page.dart';
import '../../Pages/smart/storage_analyzer_page.dart';
import '../../Pages/smart/recycle_bin_page.dart';
import '../../Pages/account/setting_page.dart';
import '../../Pages/media/code_viewer_page.dart';
import '../../Pages/media/spreadsheet_viewer_page.dart';
import '../../Pages/sharing/shared_by_me.dart';
import '../../Pages/sharing/shared_with_me.dart';
import '../../Pages/sharing/share_page.dart';
import '../../services/auth_service.dart';
import '../../utils/models/file_item.dart';

// ─── Helper extension for type-safe extra extraction ──────────
extension RouterExtra on Map<String, dynamic> {
  List<FileItem> getFiles(String key) {
    final list = this[key] as List<dynamic>?;
    return list?.cast<FileItem>() ?? [];
  }

  T? getCallback<T>(String key) {
    final callback = this[key];
    if (callback is T) return callback;
    return null;
  }
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) async {
    final loggedIn = await AuthService.isLoggedIn();
    final loc = state.matchedLocation;
    final goingToAuth = loc == '/login' || loc == '/register';
    if (loggedIn && goingToAuth) return '/home';
    if (!loggedIn && !goingToAuth) return '/login';
    return null;
  },
  routes: [
    // ── Auth ───────────────────────────────────
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
    GoRoute(path: '/about', builder: (_, __) => const AboutPage()),

    // ── Main ────────────────────────────────────
    GoRoute(path: '/home', builder: (_, __) => const HomePage()),

    // ── Account ─────────────────────────────────
    GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
    GoRoute(
      path: '/download-history',
      builder: (_, __) => const DownloadHistoryPage(),
    ),

    // ── Media viewers ───────────────────────────
    GoRoute(
      path: '/media-player',
      builder: (_, state) {
        final tracks =
            (state.extra as List<dynamic>?)?.cast<AudioTrack>() ?? [];
        return MediaPlayerPage(tracks: tracks);
      },
    ),
    GoRoute(
      path: '/video-player',
      builder: (_, state) {
        final videos = (state.extra as List<dynamic>?)?.cast<VideoItem>() ?? [];
        return VideoPlayerPage(videos: videos);
      },
    ),
    GoRoute(
      path: '/pdf-reader/:fileName',
      builder: (_, state) {
        final fileName = state.pathParameters['fileName']!;
        final extra = state.extra as Map<String, dynamic>?;
        return PdfReaderPage(
          fileName: fileName,
          filePath: extra?['filePath'] as String?,
        );
      },
    ),
    GoRoute(
      path: '/text-editor/:fileName',
      builder: (_, state) {
        final fileName = state.pathParameters['fileName']!;
        final initialContent = state.extra as String? ?? '';
        return TextEditorPage(
          fileName: fileName,
          initialContent: initialContent,
        );
      },
    ),
    GoRoute(
      path: '/code-viewer/:fileName',
      builder: (_, state) {
        final fileName = state.pathParameters['fileName']!;
        final extra = state.extra as Map<String, dynamic>?;
        final filePath = extra?['filePath'] as String?;
        return CodeViewerPage(fileName: fileName, filePath: filePath ?? '');
      },
    ),
    GoRoute(
      path: '/spreadsheet-viewer/:fileName',
      builder: (_, state) {
        final fileName = state.pathParameters['fileName']!;
        final extra = state.extra as Map<String, dynamic>?;
        return SpreadsheetViewerPage(
          fileName: fileName,
          filePath: extra?['filePath'] as String?,
        );
      },
    ),
    GoRoute(
      path: '/image-viewer/:fileName',
      builder: (_, state) {
        final fileName = state.pathParameters['fileName']!;
        final extra = state.extra as Map<String, dynamic>?;
        return ImageViewerPage(
          fileName: fileName,
          imageBytes: extra?['imageBytes'] as Uint8List?,
          localPath: extra?['localPath'] as String?,
        );
      },
    ),

    // ── Smart tools ─────────────────────────────
    GoRoute(
      path: '/smart-sort',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final files = extra.getFiles('files');
        final onOpen = extra.getCallback<void Function(FileItem)>('onOpen');
        return CategorizationPage(files: files, onOpen: onOpen ?? (f) {});
      },
    ),
    GoRoute(
      path: '/duplicate-detection',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final files = extra.getFiles('files');
        final onDelete = extra.getCallback<void Function(FileItem)>('onDelete');
        return DuplicateDetectionPage(
          files: files,
          onDelete: onDelete ?? (f) {},
        );
      },
    ),
    GoRoute(
      path: '/storage-analyzer',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final files = extra.getFiles('files');
        final onOpen = extra.getCallback<void Function(FileItem)>('onOpen');
        return StorageAnalyzerPage(files: files, onOpen: onOpen);
      },
    ),
    GoRoute(
      path: '/recycle-bin',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final files = extra.getFiles('files');
        final onRestore = extra.getCallback<void Function(FileItem)>(
          'onRestore',
        );
        final onPermanentDelete = extra.getCallback<void Function(FileItem)>(
          'onPermanentDelete',
        );
        return RecycleBinPage(
          files: files,
          onRestore: onRestore ?? (f) {},
          onPermanentDelete: onPermanentDelete ?? (f) {},
        );
      },
    ),
    GoRoute(
      path: '/timeline',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final files = extra.getFiles('files');
        final onOpen = extra.getCallback<void Function(FileItem)>('onOpen');
        return TimelinePage(files: files, onOpen: onOpen ?? (f) {});
      },
    ),

    // ── Sharing ──────────────────────────────────
    GoRoute(path: '/shared-by-me', builder: (_, __) => const SharedByMePage()),

    GoRoute(
      path: '/share',
      builder: (_, state) {
        final file = state.extra as FileItem?;
        if (file == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(child: Text('No file provided to share.')),
          );
        }
        return SharePage(file: file);
      },
    ),

    GoRoute(
      path: '/open-shared-link',
      builder: (_, __) => const SharedWithMePage(),
    ),
  ],
);
