import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/models/folder_item.dart';

class FolderService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static String get _userId {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    return user.id;
  }

  // ── Get all folders for the current user ──────────────────────────
  static Future<List<FolderItem>> getFolders() async {
    // ✅ Issue 13 fixed: include file count
    final data = await _supabase
        .from('folders')
        .select('''
          id, 
          name, 
          created_at, 
          is_locked,
          files!folder_id(count)
        ''')
        .eq('user_id', _userId)
        .order('created_at', ascending: false);

    final List<dynamic> list = data as List<dynamic>;
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      // Extract file count from the nested `files` aggregate
      int fileCount = 0;
      final files = m['files'] as List?;
      if (files != null && files.isNotEmpty) {
        final countMap = files.first as Map<String, dynamic>?;
        fileCount = (countMap?['count'] as int?) ?? 0;
      }

      return FolderItem(
        id: m['id'] as String,
        name: m['name'] as String? ?? '',
        createdAt: DateTime.parse(m['created_at'] as String),
        fileCount: fileCount,
        isLocked: m['is_locked'] as bool? ?? false,
      );
    }).toList();
  }

  // ── Create a new folder ────────────────────────────────────────────
  static Future<FolderItem> createFolder(String name) async {
    // ✅ Issue 14 fixed: let DB handle timestamps
    final response = await _supabase
        .from('folders')
        .insert({'user_id': _userId, 'name': name})
        .select()
        .single();

    final m = response as Map<String, dynamic>;
    return FolderItem(
      id: m['id'] as String,
      name: m['name'] as String? ?? '',
      createdAt: DateTime.parse(m['created_at'] as String),
      fileCount: 0,
      isLocked: m['is_locked'] as bool? ?? false,
    );
  }

  // ── Delete a folder ─────────────────────────────────────────────────
  static Future<void> deleteFolder(String folderId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    // Orphan files first
    await _supabase
        .from('files')
        .update({'folder_id': null})
        .eq('folder_id', folderId)
        .eq('user_id', userId);

    final result = await _supabase
        .from('folders')
        .delete()
        .eq('id', folderId)
        .eq('user_id', userId)
        .select('id')
        .maybeSingle();

    if (result == null) {
      throw Exception('Folder not found or permission denied');
    }
  }

  // ── Rename a folder ────────────────────────────────────────────────
  static Future<void> renameFolder(String folderId, String newName) async {
    await _supabase
        .from('folders')
        .update({'name': newName})
        .eq('id', folderId)
        .eq('user_id', _userId);
  }

  // ── Move a file to a folder ────────────────────────────────────────
  static Future<void> moveFile(String fileId, String? folderId) async {
    await _supabase
        .from('files')
        .update({'folder_id': folderId})
        .eq('id', fileId);
  }
}
