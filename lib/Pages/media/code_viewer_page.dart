import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/widgets/shimmer_loading.dart';
import 'text_editor_page.dart';

String _languageFromExtension(String extension) {
  switch (extension.toLowerCase()) {
    case 'dart':
      return 'dart';
    case 'java':
      return 'java';
    case 'py':
      return 'python';
    case 'js':
      return 'javascript';
    case 'ts':
      return 'typescript';
    case 'html':
      return 'html';
    case 'css':
      return 'css';
    case 'c':
      return 'c';
    case 'cpp':
    case 'cc':
    case 'cxx':
      return 'cpp';
    case 'cs':
      return 'csharp';
    case 'swift':
      return 'swift';
    case 'kt':
      return 'kotlin';
    case 'sql':
      return 'sql';
    case 'json':
      return 'json';
    case 'xml':
      return 'xml';
    case 'yaml':
    case 'yml':
      return 'yaml';
    case 'sh':
    case 'bash':
      return 'bash';
    case 'md':
      return 'markdown';
    default:
      return 'plaintext';
  }
}

class CodeViewerPage extends StatefulWidget {
  final String fileName;
  final String filePath;
  final String? fileId;

  const CodeViewerPage({
    super.key,
    required this.fileName,
    required this.filePath,
    this.fileId,
  });

  @override
  State<CodeViewerPage> createState() => _CodeViewerPageState();
}

class _CodeViewerPageState extends State<CodeViewerPage> {
  late TextEditingController _controller;
  bool _isLoading = true;
  String? _error;

  final Map<String, TextStyle> _monokaiDarkTheme = const {
    'root': TextStyle(
      backgroundColor: Color(0xFF1E1E1E),
      color: Color(0xFFD4D4D4),
    ),
    'keyword': TextStyle(color: Color(0xFF569CD6)),
    'string': TextStyle(color: Color(0xFFCE9178)),
    'comment': TextStyle(color: Color(0xFF6A9955)),
    'number': TextStyle(color: Color(0xFFB5CEA8)),
    'class-name': TextStyle(color: Color(0xFF4EC9B0)),
    'function': TextStyle(color: Color(0xFFDCDCAA)),
    'title': TextStyle(color: Color(0xFF569CD6)),
  };

  String get _extension =>
      widget.fileName.contains('.') ? widget.fileName.split('.').last : '';
  String get _language => _languageFromExtension(_extension);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadFile();
  }

  Future<void> _loadFile() async {
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) throw Exception('File not found');
      final content = await file.readAsString();
      if (!mounted) return;
      setState(() {
        _controller.text = content;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Navigate to the full text editor, passing current content, file ID, and storage path.
  void _openInEditor() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final storedName = userId != null ? '$userId/${widget.fileName}' : null;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TextEditorPage(
          fileName: widget.fileName,
          initialContent: _controller.text,
          fileId: widget.fileId,
          storedName: storedName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF171E30),
          foregroundColor: Colors.white,
          title: Text(widget.fileName, overflow: TextOverflow.ellipsis),
        ),
        body: const DashboardShimmer(),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF171E30),
          foregroundColor: Colors.white,
          title: Text(widget.fileName, overflow: TextOverflow.ellipsis),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Error: $_error',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171E30),
        foregroundColor: Colors.white,
        title: Text(widget.fileName, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit in full editor',
            onPressed: _openInEditor,
          ),
        ],
      ),
      body: Hero(
        tag: 'code-${widget.fileName}',
        child: SafeArea(child: _buildHighlighted()),
      ),
    );
  }

  Widget _buildHighlighted() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: HighlightView(
          _controller.text,
          language: _language,
          theme: _monokaiDarkTheme,
          padding: const EdgeInsets.all(16),
          textStyle: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
