import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart' show compute;
import '../../services/file_service.dart';
import '../../utils/widgets/shimmer_loading.dart';

// ─── Isolate‑compatible CSV parser ─────────────────────────────
List<List<String>> _parseCsv(String csvString) {
  final rawData = const CsvToListConverter().convert(csvString);
  return rawData
      .map((row) => row.map((cell) => cell.toString()).toList())
      .toList();
}

class SpreadsheetViewerPage extends StatefulWidget {
  final String? filePath;
  final String fileName;
  final bool isFileId;

  const SpreadsheetViewerPage({
    super.key,
    this.filePath,
    required this.fileName,
    this.isFileId = false,
  });

  @override
  State<SpreadsheetViewerPage> createState() => _SpreadsheetViewerPageState();
}

class _SpreadsheetViewerPageState extends State<SpreadsheetViewerPage> {
  List<List<String>> _rows = [];
  List<String> _columns = [];
  bool _loading = true;
  String? _error;
  String? _tempPath;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void dispose() {
    if (_tempPath != null) {
      try {
        File(_tempPath!).deleteSync(recursive: true);
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _loadFile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      String? localPath;

      // 1. Resolve the file path
      if (widget.filePath == null) {
        setState(() {
          _error = 'No file provided.';
          _loading = false;
        });
        return;
      }

      if (widget.isFileId) {
        localPath = await FileService.downloadToTempFile(
          widget.filePath!,
          fileName: widget.fileName,
        );
        _tempPath = localPath;
      } else {
        localPath = widget.filePath!;
        final file = File(localPath);
        if (!await file.exists()) {
          setState(() {
            _error = 'File not found on device.';
            _loading = false;
          });
          return;
        }
      }

      // 2. Read file bytes
      final file = File(localPath!);
      final bytes = await file.readAsBytes();
      final ext = widget.fileName.toLowerCase().split('.').last;
      List<List<String>> data = [];

      // 3. Parse based on extension
      if (ext == 'csv') {
        String csvString;
        try {
          csvString = utf8.decode(bytes);
        } catch (_) {
          // Fallback to Latin-1 for non-UTF-8 CSV files
          csvString = latin1.decode(bytes);
        }

        try {
          // Parse in a separate isolate to avoid UI jank
          data = await compute(_parseCsv, csvString);
        } catch (e) {
          setState(() {
            _error = 'Failed to parse CSV: $e';
            _loading = false;
          });
          return;
        }
      } else if (ext == 'xlsx' || ext == 'xls') {
        setState(() {
          _error = 'Excel (.xlsx / .xls) preview is coming soon.';
          _loading = false;
        });
        return;
      } else {
        setState(() {
          _error = 'Unsupported spreadsheet format: .$ext';
          _loading = false;
        });
        return;
      }

      // 4. Process data
      if (data.isEmpty) {
        setState(() {
          _rows = [];
          _columns = [];
          _loading = false;
        });
        return;
      }

      setState(() {
        _columns = data.first;
        _rows = data.length > 1 ? data.sublist(1) : [];
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load spreadsheet: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: theme.colorScheme.surface,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.fileName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            if (!_loading && _error == null && _rows.isNotEmpty)
              Text(
                '${_rows.length} rows × ${_columns.length} columns',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const KeyedSubtree(
        key: ValueKey('loading'),
        child: DashboardShimmer(),
      );
    }

    if (_error != null) {
      return Center(
        key: const ValueKey('error'),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.table_rows_rounded,
                  size: 40,
                  color: Colors.red.shade400,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadFile,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_rows.isEmpty && _columns.isEmpty) {
      return Center(
        key: const ValueKey('empty'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.grid_on_rounded,
              size: 48,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: 12),
            const Text(
              'Empty sheet data structure',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const ValueKey('content'),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Hero(
          tag: 'spreadsheet-${widget.fileName}',
          child: Scrollbar(
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              physics: const BouncingScrollPhysics(),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: DataTable(
                  columnSpacing: 24,
                  horizontalMargin: 16,
                  headingRowHeight: 44,
                  dataRowMinHeight: 40,
                  dataRowMaxHeight: 48,
                  headingRowColor: WidgetStateProperty.all(
                    Colors.amber.withValues(alpha: 0.12),
                  ),
                  border: TableBorder(
                    horizontalInside: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.3,
                      ),
                      width: 0.8,
                    ),
                    verticalInside: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.2,
                      ),
                      width: 0.8,
                    ),
                  ),
                  columns: _columns
                      .map(
                        (col) => DataColumn(
                          label: Text(
                            col,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  rows: List<DataRow>.generate(_rows.length, (index) {
                    final row = _rows[index];
                    final isEven = index % 2 == 0;
                    return DataRow(
                      color: WidgetStateProperty.all(
                        isEven
                            ? Colors.transparent
                            : theme.colorScheme.surfaceContainerLowest
                                  .withValues(alpha: 0.5),
                      ),
                      cells: row
                          .map(
                            (cell) => DataCell(
                              Text(
                                cell,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.85,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
