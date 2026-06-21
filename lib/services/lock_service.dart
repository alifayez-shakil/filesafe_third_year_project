import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LockService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // ── Helper: hash a PIN → hex string (64 chars) ──────────────
  static String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString(); // hex string, 64 chars
  }

  // ── File locking ────────────────────────────────────────────
  static Future<void> lockFile(String fileId, String pin) async {
    final hashed = _hashPin(pin);
    await _supabase
        .from('files')
        .update({'is_locked': true, 'lock_pin': hashed})
        .eq('id', fileId);
  }

  static Future<bool> unlockFile(String fileId, String enteredPin) async {
    final hashedPin = _hashPin(enteredPin);
    final data = await _supabase
        .from('files')
        .select('lock_pin')
        .eq('id', fileId)
        .maybeSingle();

    if (data == null) return false;
    final storedHash = (data as Map<String, dynamic>)['lock_pin'] as String?;
    if (storedHash == hashedPin) {
      await _supabase
          .from('files')
          .update({'is_locked': false, 'lock_pin': null})
          .eq('id', fileId);
      return true;
    }
    return false;
  }

  static Future<bool> isFileLocked(String fileId) async {
    final data = await _supabase
        .from('files')
        .select('is_locked')
        .eq('id', fileId)
        .maybeSingle();
    return (data as Map<String, dynamic>?)?['is_locked'] as bool? ?? false;
  }

  // ── Folder locking ──────────────────────────────────────────
  static Future<void> lockFolder(String folderId, String pin) async {
    final hashed = _hashPin(pin);
    await _supabase
        .from('folders')
        .update({'is_locked': true, 'lock_pin': hashed})
        .eq('id', folderId);
  }

  static Future<bool> unlockFolder(String folderId, String enteredPin) async {
    final hashedPin = _hashPin(enteredPin);
    final data = await _supabase
        .from('folders')
        .select('lock_pin')
        .eq('id', folderId)
        .maybeSingle();

    if (data == null) return false;
    final storedHash = (data as Map<String, dynamic>)['lock_pin'] as String?;
    if (storedHash == hashedPin) {
      await _supabase
          .from('folders')
          .update({'is_locked': false, 'lock_pin': null})
          .eq('id', folderId);
      return true;
    }
    return false;
  }

  static Future<bool> isFolderLocked(String folderId) async {
    final data = await _supabase
        .from('folders')
        .select('is_locked')
        .eq('id', folderId)
        .maybeSingle();
    return (data as Map<String, dynamic>?)?['is_locked'] as bool? ?? false;
  }

  // ── Get all locked files for the current user ──────────────
  static Future<List<Map<String, dynamic>>> getLockedFiles() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    final data = await _supabase
        .from('files')
        .select()
        .eq('user_id', userId)
        .eq('is_locked', true)
        .order('updated_at', ascending: false);

    return (data as List<dynamic>).cast<Map<String, dynamic>>();
  }
}
