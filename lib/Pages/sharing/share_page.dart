import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/models/file_item.dart';
import '../../services/share_service.dart';
import '../../utils/helpers/date_helper.dart';
import '../../utils/widgets/file_icon.dart';

class SharePage extends StatefulWidget {
  final FileItem file;
  const SharePage({super.key, required this.file});

  @override
  State<SharePage> createState() => _SharePageState();
}

class _SharePageState extends State<SharePage> {
  final _passwordCtrl = TextEditingController();
  String _permission = 'VIEW';
  String _expiry = '7 days';
  bool _generating = false;
  bool _copied = false;
  Map<String, dynamic>? _activeLink;
  List<Map<String, dynamic>> _previousLinks = [];
  bool _loadingPrev = true;

  static const _permissions = ['VIEW', 'DOWNLOAD', 'EDIT'];
  static const _expiries = ['1 day', '3 days', '7 days', '30 days', 'Never'];

  static const _permColors = {
    'VIEW': Color(0xFF3B82F6),
    'DOWNLOAD': Color(0xFF10B981),
    'EDIT': Color(0xFFF59E0B),
  };

  @override
  void initState() {
    super.initState();
    _loadPreviousLinks();
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPreviousLinks() async {
    try {
      final links = await ShareService.getShareLinksForFile(widget.file.id);
      if (mounted) {
        setState(() {
          _previousLinks = links;
          _loadingPrev = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPrev = false);
    }
  }

  Future<void> _generateLink() async {
    final password = _passwordCtrl.text.trim();
    if (password.length < 4) {
      _showSnackBar('Password must be at least 4 characters', isError: true);
      return;
    }

    setState(() => _generating = true);
    try {
      final expires = ShareService.expiryStringToDate(_expiry);
      final link = await ShareService.createShareLink(
        fileId: widget.file.id,
        permission: _permission,
        password: password,
        expiresAt: expires,
      );

      setState(() {
        _activeLink = link;
        _previousLinks.insert(0, link);
        _passwordCtrl.clear();
      });
      _showSnackBar('Link created successfully!', isError: false);
    } catch (e) {
      _showSnackBar('Failed to create link: $e', isError: true);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _copyLink(String token) async {
    final url = ShareService.getShareUrl(token);
    await Clipboard.setData(ClipboardData(text: url));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  Future<void> _revokeLink(String linkId) async {
    try {
      await ShareService.revokeShareLink(linkId);
      await _loadPreviousLinks();
      if (_activeLink?['id'] == linkId) {
        setState(() => _activeLink = null);
      }
      _showSnackBar('Link revoked');
    } catch (e) {
      _showSnackBar('Revoke failed: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Colors.red
            : (message.contains('created') ? Colors.green : null),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Share Link',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFileInfo(),
          const SizedBox(height: 24),

          _buildSectionTitle('Permission'),
          const SizedBox(height: 8),
          _buildPermissionSelector(),

          const SizedBox(height: 20),
          _buildSectionTitle('Expiry'),
          const SizedBox(height: 8),
          _buildExpirySelector(),

          const SizedBox(height: 20),
          _buildSectionTitle('Password'),
          const SizedBox(height: 8),
          _buildPasswordInput(),

          const SizedBox(height: 32),
          _buildGenerateButton(),

          if (_activeLink != null) ...[
            const SizedBox(height: 32),
            _buildActiveLinkSection(),
          ],

          const SizedBox(height: 32),
          _buildPreviousLinksSection(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    );
  }

  Widget _buildFileInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          FileIcon(type: widget.file.type, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.file.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.file.sizeFormatted,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionSelector() {
    return Row(
      children: _permissions.map((p) {
        final isSelected = _permission == p;
        final color = _permColors[p]!;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: p != 'EDIT' ? 8 : 0),
            child: InkWell(
              onTap: () => setState(() => _permission = p),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? color : Colors.grey.withOpacity(0.3),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _getPermissionIcon(p),
                      color: isSelected ? color : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      p,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? color : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _getPermissionIcon(String p) {
    return switch (p) {
      'VIEW' => Icons.visibility_outlined,
      'DOWNLOAD' => Icons.download_outlined,
      'EDIT' => Icons.edit_outlined,
      _ => Icons.help_outline,
    };
  }

  Widget _buildExpirySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _expiries.map((e) {
        final isSelected = _expiry == e;
        return ChoiceChip(
          label: Text(e),
          selected: isSelected,
          onSelected: (val) => setState(() => _expiry = e),
          selectedColor: Colors.amber.withOpacity(0.2),
          labelStyle: TextStyle(
            color: isSelected ? Colors.amber[900] : null,
            fontWeight: isSelected ? FontWeight.bold : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPasswordInput() {
    return TextField(
      controller: _passwordCtrl,
      obscureText: true,
      decoration: InputDecoration(
        hintText: 'Set a password (min 4 chars)',
        prefixIcon: const Icon(Icons.lock_outline),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Theme.of(context).cardColor,
      ),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        onPressed: _generating ? null : _generateLink,
        icon: _generating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : const Icon(Icons.link),
        label: Text(
          _generating ? 'Generating...' : 'Generate Share Link',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildActiveLinkSection() {
    final token = _activeLink!['token'] as String;
    final url = ShareService.getShareUrl(token);
    final perm = _activeLink!['permission'] as String;
    final expiresAt = _activeLink!['expires_at'] != null
        ? DateTime.tryParse(_activeLink!['expires_at'] as String)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 16),
        _buildSectionTitle('Active Link'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      url,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        _copied ? Icons.check : Icons.copy,
                        key: ValueKey(_copied),
                        size: 20,
                        color: _copied ? Colors.green : Colors.blue,
                      ),
                    ),
                    onPressed: () => _copyLink(token),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _metaChip(Icons.lock_outline, perm, _permColors[perm]!),
                  const SizedBox(width: 8),
                  _metaChip(
                    Icons.access_time,
                    DateHelper.formatExpiry(expiresAt),
                    Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  _metaChip(
                    Icons.visibility,
                    '${_activeLink!['view_count'] ?? 0}',
                    Colors.grey,
                  ),
                ],
              ),
              // ✅ FIXED: Revoke button now calls _revokeLink
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _revokeLink(_activeLink!['id'] as String),
                  child: const Text(
                    'Revoke Link',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviousLinksSection() {
    if (_loadingPrev) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_previousLinks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 16),
        _buildSectionTitle('Previous Links'),
        const SizedBox(height: 12),
        ..._previousLinks.map((link) => _buildLinkTile(link)),
      ],
    );
  }

  Widget _buildLinkTile(Map<String, dynamic> link) {
    final token = link['token'] as String;
    final revoked = link['is_revoked'] as bool? ?? false;
    final expiresAt = link['expires_at'] != null
        ? DateTime.tryParse(link['expires_at'] as String)
        : null;
    final expiryStr = DateHelper.formatExpiry(expiresAt);
    final isExpired = expiryStr == 'Expired';
    final isDisabled = revoked || isExpired;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  token,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    decoration: isDisabled ? TextDecoration.lineThrough : null,
                    color: isDisabled ? Colors.grey : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isDisabled
                      ? (revoked ? 'Revoked' : 'Expired')
                      : 'Active • $expiryStr',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDisabled ? Colors.red.shade300 : Colors.green,
                  ),
                ),
              ],
            ),
          ),
          if (!isDisabled) ...[
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () => _copyLink(token),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.link_off, size: 18, color: Colors.red),
              onPressed: () => _revokeLink(link['id'] as String),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
