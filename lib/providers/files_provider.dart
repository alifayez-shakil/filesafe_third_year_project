import 'package:flutter/material.dart';
import '../services/file_service.dart';
import '../utils/models/file_item.dart';

class FilesProvider extends ChangeNotifier {
  List<FileItem> _files = [];
  bool _isLoading = true;

  List<FileItem> get files => _files;
  bool get isLoading => _isLoading;

  Future<void> loadFiles() async {
    _isLoading = true;
    notifyListeners();
    try {
      _files = await FileService.getFiles();
    } catch (e) {
      // handle error
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteFile(String fileId) async {
    await FileService.deleteFile(fileId);
    _files.removeWhere((f) => f.id == fileId);
    notifyListeners();
  }

  Future<void> toggleStar(String fileId) async {
    await FileService.toggleStar(fileId);
    final file = _files.firstWhere((f) => f.id == fileId);
    file.isStarred = !file.isStarred;
    notifyListeners();
  }

// Additional helper methods (search, getStarred, etc.) can be added here.
}