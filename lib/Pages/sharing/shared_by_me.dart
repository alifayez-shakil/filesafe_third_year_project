import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/share_service.dart';
import '../../utils/helpers/date_helper.dart';
import '../../utils/widgets/shimmer_loading.dart';

class SharedByMePage extends StatefulWidget {
  const SharedByMePage({super.key});

  @override
  State<SharedByMePage> createState() => _SharedByMePageState();
}

class _SharedByMePageState extends State<SharedByMePage> {
  List<Map<String, dynamic>> _links = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ShareService.getAllShareLinks();
      if (mounted) {
        setState(() {
          _links = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading links: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _revokeLink(String linkId) async {
    try {
      await ShareService.revokeShareLink(linkId);
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link revoked'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Revoke failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _copyLink(String token) async {
    final url = ShareService.getShareUrl(token);
    await Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Share Links'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _loading
          ? const DashboardShimmer()
          : _links.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _load,
              color: Colors.amber,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _links.length,
                itemBuilder: (_, i) {
                  final link = _links[i];
                  final token = link['token'] as String;
                  final file = link['file'] as Map<String, dynamic>?;
                  final fileName = file?['name'] ?? 'Unknown file';
                  final revoked = link['is_revoked'] as bool? ?? false;
                  final perm = link['permission'] as String? ?? 'VIEW';
                  final expiresAt = link['expires_at'] != null
                      ? DateTime.tryParse(link['expires_at'] as String)
                      : null;
                  final isExpired =
                      expiresAt != null && expiresAt.isBefore(DateTime.now());
                  final isDisabled = revoked || isExpired;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const Icon(Icons.link, color: Colors.blue),
                      title: Text(
                        fileName,
                        style: TextStyle(
                          fontWeight: isDisabled
                              ? FontWeight.normal
                              : FontWeight.bold,
                          decoration: isDisabled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Token: $token',
                            style: const TextStyle(fontSize: 11),
                          ),
                          Row(
                            children: [
                              _chip(perm, _permColor(perm)),
                              const SizedBox(width: 8),
                              _chip(
                                isExpired
                                    ? 'Expired'
                                    : (revoked ? 'Revoked' : 'Active'),
                                isExpired
                                    ? Colors.red
                                    : (revoked ? Colors.grey : Colors.green),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: isDisabled
                          ? null
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 18),
                                  onPressed: () => _copyLink(token),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.link_off,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  onPressed: () =>
                                      _revokeLink(link['id'] as String),
                                ),
                              ],
                            ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(label, style: TextStyle(fontSize: 10, color: color)),
  );

  Color _permColor(String perm) {
    switch (perm) {
      case 'DOWNLOAD':
        return Colors.teal;
      case 'EDIT':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.link_off, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No share links created yet'),
          const SizedBox(height: 8),
          Text(
            'Share a file with a password‑protected link to see it here.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
