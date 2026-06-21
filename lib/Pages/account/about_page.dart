import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'About FileSafe',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // ── App Logo ──
            Center(
              child: Hero(
                tag: 'app_logo',
                child: Container(
                  width: 80,
                  height: 80,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amber.shade700, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/FileSafe_logo.png',
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.shield_rounded,
                      color: Colors.amber,
                      size: 44,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── App Name & Tagline ──
            const Text(
              'FileSafe',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'End‑to‑end encrypted file sharing',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),

            // ── Version Card ──
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _infoRow(
                      context,
                      Icons.info_outline,
                      'Version',
                      '1.0.0 (Beta)',
                    ),
                    const Divider(height: 24, color: Colors.grey),
                    _infoRow(
                      context,
                      Icons.code,
                      'Framework',
                      'Flutter 3.44 • Dart 3.9',
                    ),
                    const Divider(height: 24, color: Colors.grey),
                    _infoRow(
                      context,
                      Icons.cloud_outlined,
                      'Backend',
                      'Supabase (Auth, Storage, Database)',
                    ),
                    const Divider(height: 24, color: Colors.grey),
                    _infoRow(
                      context,
                      Icons.lock_outline,
                      'Encryption',
                      'AES‑256 (client‑side)',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Development Team Card ──
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.people_outline,
                            color: Colors.amber,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Development Team',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Head of Team
                    _infoRow(
                      context,
                      Icons.person,
                      'Head of Team',
                      'MD Fayez Ali Shakil',
                    ),
                    const SizedBox(height: 4),
                    _infoRow(
                      context,
                      Icons.email_outlined,
                      'Email',
                      'itz.alifayez@gmail.com',
                    ),

                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Colors.grey),

                    // Team Member
                    const SizedBox(height: 12),
                    _infoRow(
                      context,
                      Icons.person,
                      'Team Member',
                      'Minhaj Farhan',
                    ),

                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Colors.grey),

                    // University & Year
                    const SizedBox(height: 12),
                    _infoRow(
                      context,
                      Icons.school,
                      'University',
                      'Leading University',
                    ),
                    const SizedBox(height: 8),
                    _infoRow(context, Icons.calendar_today, 'Year', '2025'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Open Source / Acknowledgments ──
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.favorite_border,
                            color: Colors.blue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Acknowledgments',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Built with Flutter and Supabase. Special thanks to the open‑source community for making rapid, secure development possible.',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Privacy & Terms (placeholder) ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Privacy Policy coming soon'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text(
                    'Privacy Policy',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                const Text('·', style: TextStyle(color: Colors.grey)),
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Terms of Service coming soon'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text(
                    'Terms of Service',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[500]),
        const SizedBox(width: 10),
        SizedBox(
          width: 110, // slightly widened for longer labels
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
