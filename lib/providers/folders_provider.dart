import 'package:flutter/material.dart';
import '../services/folder_service.dart';
import '../utils/models/file_item.dart';
import '../utils/models/folder_item.dart';

class FoldersProvider extends ChangeNotifier {
  List<FolderItem> _folders = [];
  bool _isLoading = true;

  List<FolderItem> get folders => _folders;
  bool get isLoading => _isLoading;

  Future<void> loadFolders() async {
    _isLoading = true;
    notifyListeners();
    try {
      _folders = await FolderService.getFolders();
    } catch (e) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> createFolder(String name) async {
    await FolderService.createFolder(name);
    await loadFolders();
  }

  Future<void> deleteFolder(String id) async {
    await FolderService.deleteFolder(id);
    _folders.removeWhere((f) => f.id == id);
    notifyListeners();
  }
}
