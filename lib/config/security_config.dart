class SecurityConfig {
  // ── Authentication limits ────────────────────────────────
  static const int maxLoginAttempts = 5;
  static const int lockoutDurationMinutes = 30;
  static const int sessionTimeoutMinutes = 60;
  static const int tokenRefreshBufferSeconds = 300;

  // ── Encryption ───────────────────────────────────────────
  static const int aesKeyLength = 32;
  static const int aesIvLength = 16;

  // ── Feature flags ────────────────────────────────────────
  static const bool requireEncryption = true;
  static const bool requireBiometric = false;

  // ── File validation ─────────────────────────────────────
  static const int maxFileSizeBytes = 100 * 1024 * 1024;

  static const List<String> allowedMimeTypes = [
    // Images
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'image/bmp',
    // Documents
    'application/pdf',
    // Videos
    'video/mp4',
    'video/quicktime',
    // Audio
    'audio/mpeg',
    'audio/wav',
    'audio/aac',
    'audio/mp4',
    // Text & Data
    'text/plain',
    'text/csv',
    'application/json',
    'application/xml',
    // Archives
    'application/zip',
    'application/vnd.rar',
    'application/x-7z-compressed',
    // Office
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    // Code
    'text/x-dart',
    'text/x-python',
    'text/javascript',
    'text/typescript',
    'text/html',
    'text/css',
  ];

  // ── Helpers ─────────────────────────────────────────────
  static bool isMimeAllowed(String mime) =>
      allowedMimeTypes.contains(mime.toLowerCase());

  static bool isFileTooLarge(int bytes) => bytes > maxFileSizeBytes;

  // ─── Validate file ────────────────────────────────────────────
  static String? validateFile({
    required String fileName,
    required String mimeType,
    required int sizeBytes,
  }) {
    if (sizeBytes > maxFileSizeBytes) {
      return 'File exceeds maximum size of 100 MB.';
    }

    if (!allowedMimeTypes.contains(mimeType)) {
      return 'File type "$mimeType" is not allowed.';
    }
    return null; // valid
  }
}
