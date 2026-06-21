import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'encryption_service.dart';
import '../utils/models/user_profile.dart';

class AuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static const _nameKey = 'user_name';
  static const _emailKey = 'user_email';

  // ── Session helpers ──────────────────────────────────────────
  static Future<bool> isLoggedIn() async =>
      _supabase.auth.currentSession != null;

  static Future<String> getUserName() async {
    final user = _supabase.auth.currentUser;
    final metaName = user?.userMetadata?['full_name'] as String?;
    if (metaName != null && metaName.isNotEmpty) return metaName;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nameKey) ?? user?.email?.split('@').first ?? 'User';
  }

  static Future<String> getUserEmail() async {
    final user = _supabase.auth.currentUser;
    if (user?.email != null) return user!.email!;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey) ?? '';
  }

  static Future<String?> getToken() async =>
      _supabase.auth.currentSession?.accessToken;

  static Future<bool> refreshToken() async {
    try {
      final res = await _supabase.auth.refreshSession();
      return res.session != null;
    } catch (_) {
      return false;
    }
  }

  // ── Logout ───────────────────────────────────────────────────
  static Future<void> logout() async {
    await _supabase.auth.signOut();
    final p = await SharedPreferences.getInstance();
    await p.remove(_nameKey);
    await p.remove(_emailKey);
    await p.remove('raw_key'); // force restoreKey() on next login
  }

  // ── Register ─────────────────────────────────────────────────
  static Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name},
      );
      if (res.user == null) return 'Registration failed.';

      final p = await SharedPreferences.getInstance();
      await p.setString(_nameKey, name);
      await p.setString(_emailKey, email);

      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Cannot reach server. Check your internet connection.';
    }
  }

  // ── Login ────────────────────────────────────────────────────
  static Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (res.session == null) return 'Login failed.';

      // Cache display name
      final name =
          res.user?.userMetadata?['full_name'] as String? ??
          email.split('@').first;
      final p = await SharedPreferences.getInstance();
      await p.setString(_nameKey, name);
      await p.setString(_emailKey, email);

      // 🔐 Key management — now that we have a confirmed session:
      await _initEncryption(password);

      return null; // success
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      if (e.toString().contains('encryption key')) return e.toString();
      return 'Cannot reach server. Check your internet connection.';
    }
  }

  // ── Profile ──────────────────────────────────────────────────
  static Future<UserProfile?> getProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (data == null) return null;
      return UserProfile.fromMap(data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // ── Private: key initialisation ──────────────────────────────
  static Future<void> _initEncryption(String password) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final hasBundle =
          (user.userMetadata?['enc_key_bundle'] as String?) != null;
      if (hasBundle) {
        await EncryptionService.restoreKey(password);
      } else {
        await EncryptionService.generateAndStoreKey(password);
      }
    } catch (e) {
      throw Exception('Could not restore encryption key: $e');
    }
  }

  static String? _userPassword;

  static void setUserPassword(String password) {
    _userPassword = password;
  }

  static String? getUserPassword() => _userPassword;
}
