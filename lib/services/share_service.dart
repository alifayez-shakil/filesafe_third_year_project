import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:cryptography/cryptography.dart';
import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'file_service.dart';

class SharedFileResult {
  final Uint8List bytes;
  final String permission;
  final String fileName;
  const SharedFileResult({
    required this.bytes,
    required this.permission,
    required this.fileName,
  });
}

class ShareService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static String get _uid {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    return user.id;
  }

  // ─── Helpers ────────────────────────────────────────────────
  static String _generateToken() {
    final iv = enc.IV.fromSecureRandom(16);
    return iv.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
  }

  static String _generateSalt() => enc.IV.fromSecureRandom(16).base64;

  static Future<Uint8List> _deriveKeyFromPassword(
    String password,
    String saltBase64,
  ) async {
    final salt = base64.decode(saltBase64);
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );
    final secretKey = await pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    final bytes = await secretKey.extractBytes();
    return Uint8List.fromList(bytes);
  }

  // ══════════════════════════════════════════════════════════════
  //  DIRECT SHARE (shared_files table)
  // ══════════════════════════════════════════════════════════════
  // ✅ Re‑added – Issue 24

  static Future<Map<String, dynamic>> shareFile({
    required String fileId,
    required String sharedWithEmail,
    required String permission,
    String? message,
    DateTime? expiresAt,
  }) async {
    final row = await _supabase
        .from('shared_files')
        .insert({
          'file_id': fileId,
          'shared_by': _uid,
          'shared_with_email': sharedWithEmail,
          'permission': permission,
          'message': message,
          'expires_at': expiresAt?.toIso8601String(),
          'is_revoked': false,
        })
        .select('*, file:files!file_id(name, size, type)')
        .single();
    return row as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getSharedByMe() async {
    final data = await _supabase
        .from('shared_files')
        .select('*, file:files!file_id(name, size, type)')
        .eq('shared_by', _uid)
        .order('created_at', ascending: false);
    return (data as List).cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> getSharedWithMe() async {
    final email = _supabase.auth.currentUser?.email;
    if (email == null) throw Exception('Not logged in');
    final data = await _supabase
        .from('shared_files')
        .select(
          '*, '
          'file:files!file_id(name, size, type, stored_name), '
          'sender:profiles!shared_by(full_name)',
        )
        .eq('shared_with_email', email)
        .eq('is_revoked', false)
        .order('created_at', ascending: false);
    return (data as List).cast<Map<String, dynamic>>();
  }

  static Future<void> revokeShare(String shareId) async {
    await _supabase
        .from('shared_files')
        .delete()
        .eq('id', shareId)
        .eq('shared_by', _uid);
  }

  static Future<void> updatePermission({
    required String shareId,
    required String permission,
  }) async {
    await _supabase
        .from('shared_files')
        .update({'permission': permission})
        .eq('id', shareId)
        .eq('shared_by', _uid);
  }

  // ══════════════════════════════════════════════════════════════
  //  SHARE LINKS (share_links table)
  //  Password‑protected links
  // ══════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> createShareLink({
    required String fileId,
    required String permission,
    required String password,
    DateTime? expiresAt,
  }) async {
    // ✅ Issue 23 – validate password
    if (password.trim().length < 4) {
      throw Exception('Password must be at least 4 characters.');
    }

    final userId = _uid;

    // 1. Download decrypted file (owner's key)
    final plainBytes = await FileService.downloadFile(fileId);

    // 2. Generate random share key and IV
    final shareKey = enc.Key.fromSecureRandom(32);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(shareKey, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(plainBytes, iv: iv);

    // Prepend IV to the ciphertext
    final encryptedWithIv = Uint8List(16 + encrypted.bytes.length);
    encryptedWithIv.setRange(0, 16, iv.bytes);
    encryptedWithIv.setRange(16, encryptedWithIv.length, encrypted.bytes);

    // 3. Upload to 'shared' bucket
    //    ⚠️ Issue 20: Ensure the 'shared' bucket exists in Supabase Storage.
    //    If not, this will crash. Create it via Dashboard → Storage → New Bucket.
    final token = _generateToken();
    final storagePath = 'share_links/$token';
    await _supabase.storage
        .from('shared')
        .uploadBinary(
          storagePath,
          encryptedWithIv,
          fileOptions: const FileOptions(upsert: true),
        );

    // 4. Encrypt shareKey with user password
    final salt = _generateSalt();
    final derivedKey = await _deriveKeyFromPassword(password, salt);
    final keyEncrypter = enc.Encrypter(enc.AES(enc.Key(derivedKey)));

    final keyIv = enc.IV.fromSecureRandom(16);
    final keyEncrypted = keyEncrypter.encryptBytes(shareKey.bytes, iv: keyIv);
    final keyBundle = '${keyIv.base64}:${keyEncrypted.base64}';

    // 5. Insert into database
    final row = await _supabase
        .from('share_links')
        .insert({
          'file_id': fileId,
          'created_by': userId,
          'permission': permission,
          'expires_at': expiresAt?.toIso8601String(),
          'is_revoked': false,
          'view_count': 0,
          'shared_stored_name': storagePath,
          'key_encrypted': keyBundle,
          'key_salt': salt,
          'token': token,
        })
        .select()
        .single();

    return row as Map<String, dynamic>;
  }

  // ─── Open Shared Link ──────────────────────────────────────
  static Future<SharedFileResult> openSharedLink({
    required String token,
    required String password,
  }) async {
    // ✅ Issue 21 – send Accept header to force JSON
    final functionUrl = getShareUrl(token);
    final response = await http.get(
      Uri.parse(functionUrl),
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['error'] ?? 'Failed to open link';
      throw Exception(error);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final fileUrl = data['fileUrl'] as String;
    final keyBundle = data['keyEncrypted'] as String;
    final keySalt = data['keySalt'] as String;
    final permission = data['permission'] as String? ?? 'VIEW';
    final fileName = data['fileName'] as String? ?? 'shared_file';

    // 2. Decrypt the share key using password
    final parts = keyBundle.split(':');
    if (parts.length != 2) throw Exception('Invalid key bundle');
    final keyIv = enc.IV.fromBase64(parts[0]);
    final encryptedKey = enc.Encrypted.fromBase64(parts[1]);

    final derivedKey = await _deriveKeyFromPassword(password, keySalt);
    final keyEncrypter = enc.Encrypter(enc.AES(enc.Key(derivedKey)));
    final shareKeyBytes = keyEncrypter.decryptBytes(encryptedKey, iv: keyIv);
    final shareKey = enc.Key(Uint8List.fromList(shareKeyBytes));

    // 3. Download encrypted file (IV + ciphertext)
    final encryptedWithIv = await http
        .get(Uri.parse(fileUrl))
        .then((r) => r.bodyBytes);
    if (encryptedWithIv.length < 17) throw Exception('File corrupted');

    final iv = enc.IV(Uint8List.fromList(encryptedWithIv.sublist(0, 16)));
    final ciphertext = Uint8List.fromList(encryptedWithIv.sublist(16));

    // 4. Decrypt with shareKey
    final encrypter = enc.Encrypter(enc.AES(shareKey, mode: enc.AESMode.cbc));
    final plainBytes = encrypter.decryptBytes(
      enc.Encrypted(ciphertext),
      iv: iv,
    );
    return SharedFileResult(
      bytes: Uint8List.fromList(plainBytes),
      permission: permission,
      fileName: fileName,
    );
  }

  // ─── List & manage share links ─────────────────────────────
  static Future<List<Map<String, dynamic>>> getShareLinksForFile(
    String fileId,
  ) async {
    final data = await _supabase
        .from('share_links')
        .select()
        .eq('file_id', fileId)
        .eq('created_by', _uid)
        .order('created_at', ascending: false);
    return (data as List).cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> getAllShareLinks() async {
    final data = await _supabase
        .from('share_links')
        .select('*, file:files!file_id(name, type)')
        .eq('created_by', _uid)
        .order('created_at', ascending: false);
    return (data as List).cast<Map<String, dynamic>>();
  }

  static Future<void> revokeShareLink(String linkId) async {
    await _supabase
        .from('share_links')
        .update({'is_revoked': true})
        .eq('id', linkId)
        .eq('created_by', _uid);
  }

  static Future<void> incrementViewCount(String linkId) async {
    await _supabase.rpc('increment_view_count', params: {'link_id': linkId});
  }

  // ─── Utility ────────────────────────────────────────────────
  static DateTime? expiryStringToDate(String expiry) {
    switch (expiry) {
      case '1 day':
        return DateTime.now().add(const Duration(days: 1));
      case '3 days':
        return DateTime.now().add(const Duration(days: 3));
      case '7 days':
        return DateTime.now().add(const Duration(days: 7));
      case '30 days':
        return DateTime.now().add(const Duration(days: 30));
      default:
        return null;
    }
  }

  static String getShareUrl(String token) {
    const baseUrl = 'https://gvwgrljucaprcdluqrgn.supabase.co';
    return '$baseUrl/functions/v1/share/$token';
  }
}
