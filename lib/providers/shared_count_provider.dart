import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SharedCountProvider extends ChangeNotifier {
  int _unread = 0;
  int get unread => _unread;

  RealtimeChannel? _channel;

  void startListening(String userEmail) {
    final client = Supabase.instance.client;

    // Initial count – all shared files for this user (could also filter by read status)
    client
        .from('shared_files')
        .select('id')
        .eq('shared_with_email', userEmail)
        .count(CountOption.exact)
        .then((res) {
          _unread = res.count ?? 0;
          notifyListeners();
        });

    // Subscribe to inserts
    _channel = client
        .channel('public:shared_files')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'shared_files',
          callback: (payload) {
            final newRow = payload.newRecord as Map<String, dynamic>;
            if (newRow['shared_with_email'] == userEmail) {
              _unread++;
              notifyListeners();
            }
          },
        )
        .subscribe();
  }

  void reset() {
    _unread = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
