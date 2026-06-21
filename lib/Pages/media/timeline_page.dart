import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/models/file_item.dart';
import '../../utils/widgets/file_icon.dart';

class TimelinePage extends StatefulWidget {
  final List<FileItem> files;
  final void Function(FileItem) onOpen; // ← new

  const TimelinePage({super.key, required this.files, required this.onOpen});

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage>
    with SingleTickerProviderStateMixin {
  bool _showCalendar = false;
  int _currentMonthIndex = 0;

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  Map<String, List<FileItem>> _groupByTimeline() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final groups = <String, List<FileItem>>{
      'Today': [],
      'Yesterday': [],
      'Last 7 Days': [],
      'Older': [],
    };

    for (final file in widget.files) {
      final fileDate = DateTime(
        file.uploadedAt.year,
        file.uploadedAt.month,
        file.uploadedAt.day,
      );

      if (fileDate == today) {
        groups['Today']!.add(file);
      } else if (fileDate == yesterday) {
        groups['Yesterday']!.add(file);
      } else if (fileDate.isAfter(weekAgo) && fileDate.isBefore(today)) {
        groups['Last 7 Days']!.add(file);
      } else {
        groups['Older']!.add(file);
      }
    }

    groups.removeWhere((key, value) => value.isEmpty);
    return groups;
  }

  void _openFile(FileItem f) {
    HapticFeedback.lightImpact();
    widget.onOpen(f); // ← delegate to parent
  }

  Map<DateTime, List<FileItem>> _groupByDate() {
    final map = <DateTime, List<FileItem>>{};
    for (final file in widget.files) {
      final date = DateTime(
        file.uploadedAt.year,
        file.uploadedAt.month,
        file.uploadedAt.day,
      );
      map.putIfAbsent(date, () => []).add(file);
    }
    return map;
  }

  List<DateTime> _daysInMonth(int monthOffset) {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month + monthOffset, 1);
    final lastDay = DateTime(firstDay.year, firstDay.month + 1, 0);
    return List.generate(
      lastDay.day,
      (i) => DateTime(firstDay.year, firstDay.month, i + 1),
    );
  }

  String _heroTag(FileItem file) {
    return 'timeline-hero-${file.type.name}-${file.name}';
  }

  IconData _getTimelineIcon(String title) {
    switch (title) {
      case 'Today':
        return Icons.bolt_rounded;
      case 'Yesterday':
        return Icons.history_toggle_off_rounded;
      case 'Last 7 Days':
        return Icons.date_range_rounded;
      default:
        return Icons.archive_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timelineGroups = _groupByTimeline();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: theme.colorScheme.surface,
        title: const Text(
          'File Timeline',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                _showCalendar
                    ? Icons.grid_view_rounded
                    : Icons.calendar_today_rounded,
                key: ValueKey(_showCalendar),
                size: 20,
              ),
            ),
            tooltip: _showCalendar
                ? 'Switch to List View'
                : 'Switch to Calendar View',
            onPressed: () {
              HapticFeedback.mediumImpact();
              setState(() => _showCalendar = !_showCalendar);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _showCalendar
            ? _buildCalendarView(theme)
            : _buildTimelineView(timelineGroups, theme),
      ),
    );
  }

  Widget _buildTimelineView(
    Map<String, List<FileItem>> groups,
    ThemeData theme,
  ) {
    if (groups.isEmpty) {
      return const Center(
        key: ValueKey('timeline-empty'),
        child: Text(
          'No recent file activity',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    final itemsList = <dynamic>[];
    groups.forEach((header, files) {
      itemsList.add(header);
      itemsList.addAll(files);
    });

    return ListView.builder(
      key: const ValueKey('timeline-list'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      physics: const BouncingScrollPhysics(),
      itemCount: itemsList.length,
      itemBuilder: (context, index) {
        final item = itemsList[index];

        if (item is String) {
          return Padding(
            padding: EdgeInsets.only(
              top: index == 0 ? 0 : 24,
              bottom: 12,
              left: 4,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getTimelineIcon(item),
                    color: Colors.amber.shade700,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  item,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          );
        }

        final file = item as FileItem;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 4,
            ),
            leading: Hero(
              tag: _heroTag(file),
              child: FileIcon(type: file.type, size: 34),
            ),
            title: Text(
              file.name,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13.5,
                color: Color(0xFF374151),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                file.sizeFormatted,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11.5,
                ),
              ),
            ),
            trailing: file.isStarred
                ? const Icon(Icons.star_rounded, color: Colors.amber, size: 18)
                : Icon(
                    Icons.chevron_right_rounded,
                    color: theme.dividerColor,
                    size: 18,
                  ),
            onTap: () => _openFile(file),
          ),
        );
      },
    );
  }

  Widget _buildCalendarView(ThemeData theme) {
    final filesByDate = _groupByDate();
    final days = _daysInMonth(_currentMonthIndex);
    final targetDate = DateTime(
      DateTime.now().year,
      DateTime.now().month + _currentMonthIndex,
      1,
    );
    final monthName = _months[targetDate.month - 1];
    final yearString = targetDate.year.toString();

    return Column(
      key: const ValueKey('calendar-root'),
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 14,
                  color: theme.iconTheme.color,
                ),
                onPressed: () => setState(() => _currentMonthIndex--),
              ),
              Text(
                '$monthName $yearString',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                  letterSpacing: -0.2,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: theme.iconTheme.color,
                ),
                onPressed: () => setState(() => _currentMonthIndex++),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map(
                  (d) => SizedBox(
                    width: 40,
                    child: Text(
                      d,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount:
                days.length +
                DateTime(days.first.year, days.first.month, 1).weekday -
                1,
            itemBuilder: (_, index) {
              final offset =
                  DateTime(days.first.year, days.first.month, 1).weekday - 1;
              if (index < offset) return const SizedBox.shrink();

              final day = days[index - offset];
              final hasFiles = filesByDate.containsKey(day);
              final count = filesByDate[day]?.length ?? 0;
              final isToday =
                  day.year == DateTime.now().year &&
                  day.month == DateTime.now().month &&
                  day.day == DateTime.now().day;

              return GestureDetector(
                onTap: () {
                  if (hasFiles) {
                    _showFileBottomSheet(day, filesByDate[day]!, count);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isToday
                        ? Colors.amber.shade500
                        : (hasFiles ? theme.cardColor : Colors.transparent),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isToday
                          ? Colors.amber.shade500
                          : (hasFiles
                                ? theme.dividerColor
                                : Colors.transparent),
                      width: 1,
                    ),
                    boxShadow: hasFiles && !isToday
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontWeight: hasFiles || isToday
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13,
                          color: isToday
                              ? Colors.white
                              : (hasFiles
                                    ? const Color(0xFF1F2937)
                                    : const Color(0xFF9CA3AF)),
                        ),
                      ),
                      if (hasFiles && !isToday)
                        Positioned(
                          bottom: 6,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showFileBottomSheet(DateTime day, List<FileItem> items, int count) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      elevation: 4,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${day.day} ${_months[day.month - 1]}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count files',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.amber.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                itemBuilder: (context, idx) {
                  final file = items[idx];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: Hero(
                      tag: _heroTag(file),
                      child: FileIcon(type: file.type, size: 30),
                    ),
                    title: Text(
                      file.name,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      file.sizeFormatted,
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _openFile(file);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
