import 'package:flutter/material.dart';
import '../../utils/models/file_item.dart';
import '../../utils/widgets/file_icon.dart';

typedef SemanticQueryCallback = Future<List<FileItem>> Function(String query);

class FileSearchDelegate extends SearchDelegate<String> {
  final List<FileItem> files;
  final void Function(FileItem) onOpen;
  final SemanticQueryCallback? onSemanticQuery;

  FileSearchDelegate(this.files, this.onOpen, {this.onSemanticQuery});

  @override
  String get searchFieldLabel => 'Search assets...';

  // ── Modern AppBar theme override ──────────────────────
  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
      ),
    );
  }

  // ── Actions (clear button) ───────────────────────────
  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: IconButton(
          icon: const Icon(Icons.clear_rounded, size: 20, color: Colors.grey),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
      ),
  ];

  // ── Leading back button ──────────────────────────────
  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(
      Icons.arrow_back_ios_new_rounded,
      size: 18,
      color: Colors.black87,
    ),
    onPressed: () => close(context, ''),
  );

  // ── Results & Suggestions both point to the same builder ──
  @override
  Widget buildResults(BuildContext context) => _buildSearchResults(context);
  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults(context);

  // ── Core search logic with optional semantic fallback ──
  Widget _buildSearchResults(BuildContext context) {
    final cleanQuery = query.trim();

    // 1. If semantic engine is available and query is long enough, use it
    if (onSemanticQuery != null && cleanQuery.length > 1) {
      return FutureBuilder<List<FileItem>>(
        future: onSemanticQuery!(cleanQuery),
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            );
          }
          // Error state
          if (snapshot.hasError) {
            return _buildEmptyState('Something went wrong. Try again.');
          }
          // Empty results from AI
          final results = snapshot.data ?? [];
          if (results.isEmpty) {
            return _buildEmptyState('No results for "$query".');
          }
          return _buildResultsList(results);
        },
      );
    }

    // 2. Fallback to local filtering
    final List<FileItem> filtered = cleanQuery.isEmpty
        ? files
        : files
              .where(
                (f) => f.name.toLowerCase().contains(cleanQuery.toLowerCase()),
              )
              .toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(
        cleanQuery.isEmpty
            ? 'Start typing to search.'
            : 'No results for "$query".',
      );
    }

    return _buildResultsList(filtered);
  }

  // ── Empty state widget ──────────────────────────────
  Widget _buildEmptyState(String message) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 54,
              color: Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Build the actual results list ───────────────────
  Widget _buildResultsList(List<FileItem> items) {
    return Container(
      color: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: items.length,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final item = items[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade100, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: FileIcon(type: item.type),
                ),
                title: _HighlightText(fullText: item.name, searchQuery: query),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.data_usage_rounded,
                        size: 12,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.sizeFormatted,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: Colors.grey,
                ),
                onTap: () {
                  close(context, '');
                  onOpen(item);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
//  SMART TEXT HIGHLIGHT ENGINE (unchanged, just polished)
// ──────────────────────────────────────────────────────────
class _HighlightText extends StatelessWidget {
  final String fullText;
  final String searchQuery;

  const _HighlightText({required this.fullText, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    if (searchQuery.trim().isEmpty) {
      return Text(
        fullText,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      );
    }

    final String cleanQuery = searchQuery.trim().toLowerCase();
    final String lowercaseText = fullText.toLowerCase();

    final List<TextSpan> spans = [];
    int start = 0;
    int indexOfMatch;

    while ((indexOfMatch = lowercaseText.indexOf(cleanQuery, start)) != -1) {
      if (indexOfMatch > start) {
        spans.add(
          TextSpan(
            text: fullText.substring(start, indexOfMatch),
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: fullText.substring(
            indexOfMatch,
            indexOfMatch + cleanQuery.length,
          ),
          style: const TextStyle(
            color: Colors.amber,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.transparent,
          ),
        ),
      );

      start = indexOfMatch + cleanQuery.length;
    }

    if (start < fullText.length) {
      spans.add(
        TextSpan(
          text: fullText.substring(start),
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(style: const TextStyle(fontSize: 15), children: spans),
    );
  }
}
