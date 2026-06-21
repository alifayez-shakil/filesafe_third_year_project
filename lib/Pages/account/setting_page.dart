import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../utils/widgets/shimmer_loading.dart';
import '../../providers/theme_provider.dart';
import 'download_history.dart';
import 'about_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _userName = '';
  String _userEmail = '';
  bool _notificationsEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final name = await AuthService.getUserName();
      final email = await AuthService.getUserEmail();
      final prefs = await SharedPreferences.getInstance();
      final notif = prefs.getBool('notifications') ?? true;

      if (mounted) {
        setState(() {
          _userName = name.isNotEmpty ? name : 'User';
          _userEmail = email;
          _notificationsEnabled = notif;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', value);
    setState(() => _notificationsEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: _isLoading
          ? const DashboardShimmer()
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Profile card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200, width: 1),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFFCD34D)],
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 32,
                              backgroundColor: const Color(0xFFFEF3C7),
                              child: Text(
                                _userName.isNotEmpty
                                    ? _userName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _userEmail,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Notifications
                _sectionTitle('Notifications'),
                _card(
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    secondary: _iconBox(Icons.notifications_outlined),
                    title: const Text(
                      'Push Notifications',
                      style: TextStyle(fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Receive alerts for shares and uploads',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _notificationsEnabled,
                    onChanged: _toggleNotifications,
                    activeThumbColor: Colors.amber,
                  ),
                ),

                const SizedBox(height: 16),

                // Appearance
                _sectionTitle('Appearance'),
                _card(
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    secondary: _iconBox(Icons.dark_mode),
                    title: const Text(
                      'Dark Mode',
                      style: TextStyle(fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Toggle dark theme',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: themeProvider.isDark,
                    onChanged: (_) => themeProvider.toggle(),
                    activeThumbColor: Colors.amber,
                  ),
                ),

                const SizedBox(height: 16),

                // Data & Actions
                _sectionTitle('Data & Actions'),
                _card(
                  child: ListTile(
                    leading: _iconBox(
                      Icons.download_done_rounded,
                      color: Colors.blue,
                    ),
                    title: const Text('Download History'),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DownloadHistoryPage(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _card(
                  child: ListTile(
                    leading: _iconBox(Icons.info_outline, color: Colors.teal),
                    title: const Text('About FileSafe'),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutPage()),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _iconBox(IconData icon, {Color? color}) {
    final bgColor = (color ?? Colors.grey).withOpacity(0.1);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: color ?? Colors.black54),
    );
  }

  Widget _card({required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      color: Colors.white,
      child: child,
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }
}
