/// Date/time and relative-time formatting utilities.
class DateHelper {
  DateHelper._();

  static const List<String> _months = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December'
  ];

  /// Formats a [DateTime] as "January 2025".
  static String formatMonthYear(DateTime dt) =>
      '${_months[dt.month - 1]} ${dt.year}';

  /// Formats a [DateTime] as a friendly date/time string
  /// (e.g., "15 Mar 2025, 14:30").
  static String formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = _months[dt.month - 1].substring(0, 3);
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day $month ${dt.year}, $hour:$minute';
  }

  /// Returns a short relative time string (e.g., "3m ago").
  static String timeAgo(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Returns a more descriptive relative time string
  /// (e.g., "just now", "5 minutes ago", "2 days ago").
  static String timeAgoLong(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
    return formatDateTime(dateTime);
  }

  /// Formats an expiry date as a string (e.g., "7d", "12h", "Expired", "Never").
  static String formatExpiry(DateTime? expiresAt) {
    if (expiresAt == null) return 'Never';
    final diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
