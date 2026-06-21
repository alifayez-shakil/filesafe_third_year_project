import 'dart:typed_data';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/models/file_item.dart';

class OfflineFileService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<String> downloadFile(FileItem file) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    final storagePath = '$userId/${file.name}';
    final signedUrl = await _supabase.storage
        .from('files')
        .createSignedUrl(storagePath, 60);

    final response = await http.get(Uri.parse(signedUrl));
    if (response.statusCode == 200) {
      final dir = await getApplicationDocumentsDirectory();
      final savedFile = File('${dir.path}/${file.name}');
      await savedFile.writeAsBytes(response.bodyBytes);
      return savedFile.path;
    } else {
      throw Exception('Download failed: ${response.statusCode}');
    }
  }

  static Future<void> makeAvailableOffline(FileItem file) async {
    final localPath = await downloadFile(file);
    file.isDownloaded = true;
    file.localPath = localPath;
  }

  static Future<void> removeOfflineCopy(FileItem file) async {
    if (file.localPath != null) {
      final f = File(file.localPath!);
      if (await f.exists()) await f.delete();
    }
    file.isDownloaded = false;
    file.localPath = null;
  }
}
