import 'package:supabase_flutter/supabase_flutter.dart';

class DownloadHistoryService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetches the download history for the current user.
  static Future<List<Map<String, dynamic>>> getHistory() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    final data = await _supabase
        .from('download_history')
        .select()
        .eq('user_id', userId)
        .order('downloaded_at', ascending: false);

    // Convert to list of maps (already is, but ensure correct type)
    return (data as List<dynamic>).cast<Map<String, dynamic>>();
  }

  /// Logs a new download entry (to be called when a file is downloaded).
  static Future<void> logDownload({
    required String? fileId,
    required String fileName,
    required int fileSizeBytes,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    await _supabase.from('download_history').insert({
      'user_id': userId,
      'file_id': fileId,
      'file_name': fileName,
      'file_size_bytes': fileSizeBytes, // ← keep only this
      'downloaded_at': DateTime.now().toIso8601String(),
    });
  }
}
