import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/models/user_profile.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  UserProfile? _profile;

  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  UserProfile? get profile => _profile;

  Future<void> checkLoginStatus() async {
    _isLoggedIn = await AuthService.isLoggedIn();
    if (_isLoggedIn) {
      _profile = await AuthService.getProfile();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    final error = await AuthService.login(email: email, password: password);
    if (error == null) {
      _isLoggedIn = true;
      _profile = await AuthService.getProfile();
    }
    _isLoading = false;
    notifyListeners();
    if (error != null) throw Exception(error);
  }

  Future<void> logout() async {
    await AuthService.logout();
    _isLoggedIn = false;
    _profile = null;
    notifyListeners();
  }

  Future<void> register(String name, String email, String password) async {
    _isLoading = true;
    notifyListeners();
    final error = await AuthService.register(
      name: name,
      email: email,
      password: password,
    );
    if (error == null) {
      // After registration, check if a session exists (auto‑confirm)
      final hasSession = await AuthService.isLoggedIn();
      if (hasSession) {
        _isLoggedIn = true;
        _profile = await AuthService.getProfile();
      } else {
        // Fallback: still registered but not logged in (should not happen with auto‑confirm)
        // You can still show a success message and let user go to login screen.
      }
    }
    _isLoading = false;
    notifyListeners();
    if (error != null) throw Exception(error);
  }
}
