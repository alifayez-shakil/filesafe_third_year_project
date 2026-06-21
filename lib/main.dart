import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/upload_manager.dart';
import 'utils/themes/app_theme.dart';
import 'utils/router/app_router.dart';
import 'config/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'providers/files_provider.dart';
import 'providers/folders_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/shared_count_provider.dart';
import 'providers/notification_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  final themeProvider = ThemeProvider();
  await themeProvider.loadFromPrefs();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FilesProvider()),
        ChangeNotifierProvider(create: (_) => FoldersProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => themeProvider),
        ChangeNotifierProvider(create: (_) => UploadManager()),
        ChangeNotifierProvider(create: (_) => SharedCountProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const FileSafeApp(),
    ),
  );
}

class FileSafeApp extends StatelessWidget {
  const FileSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'FileSafe',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.themeMode,
      routerConfig: appRouter,
    );
  }
}
