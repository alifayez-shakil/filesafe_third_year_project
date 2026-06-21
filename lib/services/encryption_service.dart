import 'dart:typed_data';
import 'dart:convert';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cryptography/cryptography.dart';

class EncryptionService {
  static final _sb = Supabase.instance.client;
  static const _prefKey = 'raw_key';
  static final _secureStorage = FlutterSecureStorage();

  // PBKDF2 configuration
  static const int _iterations = 100000;
  static const int _keyLength = 32; // 256 bits

  // ─── Migration status cache ────────────────────────────────────────
  static bool _migrated = false; // ← prevents repeated migration checks

  // ── Derive a key from password + salt using PBKDF2 ──
  static Future<SecretKey> _deriveKey(
    String password,
    String saltBase64,
  ) async {
    final salt = base64.decode(saltBase64);
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _iterations,
      bits: _keyLength * 8,
    );
    return await pbkdf2.deriveKeyFromPassword(password: password, nonce: salt);
  }

  // ── Helper to convert SecretKey to Uint8List ──────────────────────
  static Future<Uint8List> _secretKeyToBytes(SecretKey secretKey) async {
    return Uint8List.fromList(await secretKey.extractBytes());
  }

  // ── Generate a random salt (16 bytes) ─────────────────────────────
  static String _generateSalt() {
    final iv = enc.IV.fromSecureRandom(16);
    return iv.base64;
  }

  // ── Migrate old users (those without a salt) ───────────────────────
  static Future<void> _migrateOldUser(String password) async {
    final user = _sb.auth.currentUser;
    if (user == null) return;

    final metadata = user.userMetadata;
    final oldBundle = metadata?['enc_key_bundle'] as String?;
    final hasSalt = metadata?['key_salt'] != null;

    if (oldBundle != null && !hasSalt) {
      // 1. Derive the old weak key from password (legacy method)
      final oldWrapKey = enc.Key.fromUtf8(
        password.padRight(32).substring(0, 32),
      );

      // 2. Decrypt the old bundle to get the real rawKey
      final parts = oldBundle.split(':');
      if (parts.length == 2) {
        final wrapIV = enc.IV.fromBase64(parts[0]);
        final wrappingEncrypter = enc.Encrypter(enc.AES(oldWrapKey));
        final rawKeyBytes = wrappingEncrypter.decryptBytes(
          enc.Encrypted.fromBase64(parts[1]),
          iv: wrapIV,
        );
        final rawKey = enc.Key(Uint8List.fromList(rawKeyBytes));

        // 3. Generate a new salt, derive a new wrapping key
        final salt = _generateSalt();
        final wrappingSecretKey = await _deriveKey(password, salt);
        final wrapKeyBytes = await _secretKeyToBytes(wrappingSecretKey);
        final derivedWrapKey = enc.Key(wrapKeyBytes);
        final newWrapIV = enc.IV.fromSecureRandom(16);
        final wrappingEncrypter2 = enc.Encrypter(enc.AES(derivedWrapKey));
        final newWrappedKey = wrappingEncrypter2.encryptBytes(
          rawKey.bytes,
          iv: newWrapIV,
        );
        final newBundle = '${newWrapIV.base64}:${newWrappedKey.base64}';

        // 4. Update user metadata with new bundle and salt
        await _sb.auth.updateUser(
          UserAttributes(data: {'enc_key_bundle': newBundle, 'key_salt': salt}),
        );

        // 5. Cache the raw key securely (unchanged)
        await _secureStorage.write(key: _prefKey, value: rawKey.base64);
      }
    }
  }

  // ── Generate and store key (first login after migration / new user) ──
  static Future<void> generateAndStoreKey(String password) async {
    final user = _sb.auth.currentUser;
    if (user == null) throw Exception('No active session — cannot store key.');

    // 1. Generate true random 256-bit key (the actual file encryption key)
    final rawKey = enc.Key.fromSecureRandom(32);

    // 2. Generate salt and derive a wrapping key from password
    final salt = _generateSalt();
    final wrappingSecretKey = await _deriveKey(password, salt);
    final wrapKeyBytes = await _secretKeyToBytes(wrappingSecretKey);
    final derivedWrapKey = enc.Key(wrapKeyBytes);
    final wrapIV = enc.IV.fromSecureRandom(16);
    final wrappingEncrypter = enc.Encrypter(enc.AES(derivedWrapKey));
    final wrappedKey = wrappingEncrypter.encryptBytes(rawKey.bytes, iv: wrapIV);

    // 3. Bundle format: base64(wrapIV) + ":" + base64(wrappedKey)
    final bundle = '${wrapIV.base64}:${wrappedKey.base64}';

    // 4. Store bundle and salt in Supabase user metadata
    await _sb.auth.updateUser(
      UserAttributes(data: {'enc_key_bundle': bundle, 'key_salt': salt}),
    );

    // 5. Cache plaintext key securely
    await _secureStorage.write(key: _prefKey, value: rawKey.base64);
  }

  // ── Restore key from metadata (every subsequent login) ─────────────
  static Future<void> restoreKey(String password) async {
    final user = _sb.auth.currentUser;
    if (user == null) throw Exception('No active session.');

    // ── Migrate old users only once per session ──
    if (!_migrated) {
      await _migrateOldUser(password);
      _migrated = true;
    }

    // Now get fresh metadata after possible migration
    final refreshedUser = _sb.auth.currentUser;
    final bundle = refreshedUser?.userMetadata?['enc_key_bundle'] as String?;
    final salt = refreshedUser?.userMetadata?['key_salt'] as String?;

    if (bundle == null || salt == null) {
      // No key bundle yet – generate new one (first login after feature)
      await generateAndStoreKey(password);
      return;
    }

    final parts = bundle.split(':');
    if (parts.length != 2) throw Exception('Malformed key bundle in metadata.');

    try {
      final wrapIV = enc.IV.fromBase64(parts[0]);
      final wrappingSecretKey = await _deriveKey(password, salt);
      final wrapKeyBytes = await _secretKeyToBytes(wrappingSecretKey);
      final derivedWrapKey = enc.Key(wrapKeyBytes);
      final wrappingEncrypter = enc.Encrypter(enc.AES(derivedWrapKey));

      final rawKeyBytes = wrappingEncrypter.decryptBytes(
        enc.Encrypted.fromBase64(parts[1]),
        iv: wrapIV,
      );

      // Store the restored key securely
      await _secureStorage.write(
        key: _prefKey,
        value: enc.Key(Uint8List.fromList(rawKeyBytes)).base64,
      );
    } catch (e) {
      throw Exception(
        'Could not restore encryption key — wrong password? ($e)',
      );
    }
  }

  // ── Get raw 32-byte key (from secure storage) ──────────────────────
  static Future<Uint8List> getRawKey() async {
    String? b64 = await _secureStorage.read(key: _prefKey);

    // Fallback: try SharedPreferences (old installations) – migrate if found
    if (b64 == null) {
      final prefs = await SharedPreferences.getInstance();
      b64 = prefs.getString(_prefKey);
      if (b64 != null) {
        // Write to secure storage first, then remove the old one
        await _secureStorage.write(key: _prefKey, value: b64);
        await prefs.remove(_prefKey);
      }
    }

    if (b64 == null) {
      throw Exception(
        'Encryption key not found locally.\n'
        'Please log out and log back in to restore your key.',
      );
    }
    return enc.Key.fromBase64(b64).bytes;
  }

  // ── Encrypt (AES-CBC + prepended IV) ──────────────────────────────
  static Uint8List encryptBytes(List<int> data, Uint8List keyBytes) {
    final key = enc.Key(keyBytes);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(Uint8List.fromList(data), iv: iv);

    final out = Uint8List(16 + encrypted.bytes.length);
    out.setRange(0, 16, iv.bytes);
    out.setRange(16, out.length, encrypted.bytes);
    return out;
  }

  // ── Decrypt ────────────────────────────────────────────────────────
  static Uint8List decryptBytes(List<int> data, Uint8List keyBytes) {
    if (data.length < 17) {
      throw Exception('Ciphertext too short — file may be corrupted.');
    }

    final iv = enc.IV(Uint8List.fromList(data.sublist(0, 16)));
    final cipher = Uint8List.fromList(data.sublist(16));
    final key = enc.Key(keyBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final decrypted = encrypter.decryptBytes(enc.Encrypted(cipher), iv: iv);
    return Uint8List.fromList(decrypted);
  }

  // ── Decrypt with fallback to old key ──────────────────────────
  static Uint8List decryptBytesWithFallback(
    List<int> data,
    Uint8List newKeyBytes,
    String password,
  ) {
    try {
      // First attempt: use the new key
      return decryptBytes(data, newKeyBytes);
    } catch (e) {
      // If decryption fails, try the old weak key as fallback
      try {
        final oldWrapKey = enc.Key.fromUtf8(
          password.padRight(32).substring(0, 32),
        );
        return decryptBytes(data, oldWrapKey.bytes);
      } catch (_) {
        // If both fail, rethrow the original error
        throw Exception('Decryption failed: $e');
      }
    }
  }
}
