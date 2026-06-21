import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/file_service.dart';

class TextEditorPage extends StatefulWidget {
  final String fileName;
  final String initialContent;
  final String? fileId;
  final String? storedName;
  final String? localPath;

  const TextEditorPage({
    super.key,
    this.fileName = '', // empty = new file, non-empty = existing file
    this.initialContent = '',
    this.fileId,
    this.storedName,
    this.localPath,
  });

  @override
  State<TextEditorPage> createState() => _TextEditorPageState();
}

class _TextEditorPageState extends State<TextEditorPage> {
  late TextEditingController _ctr;
  bool _modified = false, _saving = false, _preview = false;
  int _words = 0, _lines = 0;

  // Resolved name — empty until user sets it for a new file
  late String _resolvedName;
  bool get _isNewFile => widget.fileId == null;

  @override
  void initState() {
    super.initState();
    _resolvedName = widget.fileName;
    _ctr = TextEditingController(text: widget.initialContent);
    _updateCounts();
    _ctr.addListener(() {
      setState(() {
        _modified = true;
        _updateCounts();
      });
    });

    // If this is a brand new file, ask for a name right after build
    if (_isNewFile && _resolvedName.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _askFileName());
    }
  }

  @override
  void dispose() {
    _ctr.dispose();
    super.dispose();
  }

  void _updateCounts() {
    final text = _ctr.text;
    _words = text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;
    _lines = text.isEmpty ? 0 : text.split('\n').length;
  }

  // ── Ask for filename (new file) ──────────────────────────────────
  Future<void> _askFileName({bool isSaving = false}) async {
    final ctrl = TextEditingController(
      text: _resolvedName.isNotEmpty
          ? _resolvedName.replaceAll('.txt', '')
          : '',
    );

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: !isSaving, // can't dismiss mid-save
      builder: (_) => AlertDialog(
        title: Text(isSaving ? 'Save As' : 'New Text File'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isSaving)
              const Text(
                'Give your file a name to get started.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            if (!isSaving) const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'File name',
                hintText: 'e.g. meeting-notes',
                suffixText: '.txt',
                suffixStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) Navigator.pop(context, v.trim());
              },
            ),
          ],
        ),
        actions: [
          if (!isSaving)
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context, name);
            },
            child: Text(isSaving ? 'Save' : 'Create'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      // Ensure .txt extension
      final name = result.endsWith('.txt') ? result : '$result.txt';
      setState(() => _resolvedName = name);
      if (isSaving) await _performSave();
    } else if (!isSaving && _resolvedName.isEmpty) {
      // User cancelled name dialog on new file — go back
      if (mounted) Navigator.pop(context);
    }
  }

  // ── Save button tapped ───────────────────────────────────────────
  Future<void> _save() async {
    HapticFeedback.lightImpact();

    // New file with no name yet — ask first
    if (_isNewFile && _resolvedName.isEmpty) {
      await _askFileName(isSaving: true);
      return;
    }

    await _performSave();
  }

  // ── Save As — rename and save ────────────────────────────────────
  Future<void> _saveAs() async {
    await _askFileName(isSaving: true);
  }

  // ── Actual save logic ────────────────────────────────────────────
  Future<void> _performSave() async {
    if (_resolvedName.isEmpty) return;
    setState(() => _saving = true);

    try {
      // Use utf8 encoding — supports all characters properly
      final contentBytes = Uint8List.fromList(utf8.encode(_ctr.text));

      if (widget.fileId != null) {
        // Update existing file
        await FileService.updateFileContent(
          fileId: widget.fileId!,
          fileName: _resolvedName,
          bytes: contentBytes,
        );
      } else {
        // Create new file — different name each time = multiple .txt files
        await FileService.uploadFile(
          fileName: _resolvedName,
          bytes: contentBytes,
          mimeType: 'text/plain',
        );
      }

      setState(() {
        _saving = false;
        _modified = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved as $_resolvedName'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Back — warn if unsaved ───────────────────────────────────────
  Future<bool> _onWillPop() async {
    if (!_modified) return true;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text(
          'You have unsaved changes. What would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == 'save') {
      await _save();
      return true;
    }
    if (result == 'discard') return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _resolvedName.isNotEmpty ? _resolvedName : 'New File';

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Expanded(
                child: Text(displayName, overflow: TextOverflow.ellipsis),
              ),
              if (_modified)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Unsaved',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(
                _preview ? Icons.edit_outlined : Icons.visibility_outlined,
              ),
              tooltip: _preview ? 'Edit' : 'Preview',
              onPressed: () => setState(() => _preview = !_preview),
            ),
            // Save As option for existing or named files
            if (_resolvedName.isNotEmpty)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (v) {
                  if (v == 'saveas') _saveAs();
                  if (v == 'rename') _askFileName(isSaving: false);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'saveas',
                    child: Row(
                      children: [
                        Icon(Icons.save_as_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Save As'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.drive_file_rename_outline, size: 18),
                        SizedBox(width: 8),
                        Text('Rename'),
                      ],
                    ),
                  ),
                ],
              ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _saving
                  ? const Padding(
                      key: ValueKey('saving'),
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.amber,
                        ),
                      ),
                    )
                  : IconButton(
                      key: const ValueKey('idle'),
                      icon: Icon(
                        Icons.save_rounded,
                        color: _modified ? Colors.amber : Colors.grey[400],
                      ),
                      tooltip: 'Save',
                      onPressed: _modified ? _save : null,
                    ),
            ),
          ],
        ),
        body: _preview ? _buildPreview() : _buildEditor(),
        bottomNavigationBar: Container(
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_lines lines  ·  $_words words',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_modified)
                  TextButton.icon(
                    icon: const Icon(Icons.save_rounded, size: 16),
                    label: const Text('Save'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.amber.shade700,
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: _save,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Editor ───────────────────────────────────────────────────────
  Widget _buildEditor() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              _toolbarChip('B', Icons.format_bold, () => _wrap('**', '**')),
              _toolbarChip('I', Icons.format_italic, () => _wrap('*', '*')),
              _toolbarChip('H1', Icons.title, () => _prefix('# ')),
              _toolbarChip('H2', Icons.subtitles, () => _prefix('## ')),
              _toolbarChip(
                '•',
                Icons.format_list_bulleted,
                () => _prefix('- '),
              ),
              _toolbarChip(
                '1.',
                Icons.format_list_numbered,
                () => _prefix('1. '),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: TextField(
              controller: _ctr,
              maxLines: null,
              expands: true,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(fontSize: 15, height: 1.7),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Start writing...',
                hintStyle: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _toolbarChip(String label, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Markdown preview ─────────────────────────────────────────────
  Widget _buildPreview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _parseMarkdown(_ctr.text),
    );
  }

  Widget _parseMarkdown(String text) {
    final lines = text.split('\n');
    final List<TextSpan> spans = [];
    for (final line in lines) {
      final t = line.trim();
      if (t.startsWith('### ')) {
        spans.add(
          TextSpan(
            text: '${t.substring(4)}\n',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        );
      } else if (t.startsWith('## ')) {
        spans.add(
          TextSpan(
            text: '${t.substring(3)}\n',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        );
      } else if (t.startsWith('# ')) {
        spans.add(
          TextSpan(
            text: '${t.substring(2)}\n',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        );
      } else if (t.startsWith('- ')) {
        spans.add(
          TextSpan(
            text: '• ${t.substring(2)}\n',
            style: const TextStyle(fontSize: 16),
          ),
        );
      } else {
        spans.add(_formatInline(t));
        spans.add(const TextSpan(text: '\n'));
      }
    }
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
          fontSize: 16,
          height: 1.6,
        ),
        children: spans,
      ),
    );
  }

  TextSpan _formatInline(String text) {
    List<TextSpan> children = [];
    final regex = RegExp(r'(\*\*(.+?)\*\*)|(\*(.+?)\*)|(<u>(.+?)<\/u>)');
    int lastEnd = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        children.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      if (match.group(1) != null) {
        children.add(
          TextSpan(
            text: match.group(2),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      } else if (match.group(3) != null)
        children.add(
          TextSpan(
            text: match.group(4),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      else if (match.group(5) != null)
        children.add(
          TextSpan(
            text: match.group(6),
            style: const TextStyle(decoration: TextDecoration.underline),
          ),
        );
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      children.add(TextSpan(text: text.substring(lastEnd)));
    }
    return TextSpan(children: children);
  }

  // ── Text helpers ─────────────────────────────────────────────────
  void _wrap(String prefix, String suffix) {
    final sel = _ctr.selection;
    final text = _ctr.text;
    final selected = sel.textInside(text);
    final newText = text.replaceRange(
      sel.start,
      sel.end,
      '$prefix$selected$suffix',
    );
    _ctr.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: sel.start + prefix.length + selected.length + suffix.length,
      ),
    );
  }

  void _prefix(String prefix) {
    final pos = _ctr.selection.baseOffset;
    final text = _ctr.text;
    final lineStart = text.lastIndexOf('\n', pos - 1) + 1;
    final newText = text.replaceRange(lineStart, lineStart, prefix);
    _ctr.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + prefix.length),
    );
  }
}
