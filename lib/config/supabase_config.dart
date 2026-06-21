import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = 'https://gvwgrljucaprcdluqrgn.supabase.co';
  static const String publishableKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2d2dybGp1Y2FwcmNkbHVxcmduIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMTM5MzYsImV4cCI6MjA5NjU4OTkzNn0.TeUU-WNgk-YMo-rlIg-WhV83GoCgSBs51FC0bmOPq-0';

  static bool _initialized = false;

  static SupabaseClient get client {
    if (!_initialized) {
      throw Exception(
        'Supabase not initialized. Call SupabaseConfig.initialize() first.',
      );
    }
    return Supabase.instance.client;
  }

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Supabase.initialize(url: url, publishableKey: publishableKey);
      _initialized = true;
    } catch (e) {
      throw Exception('Failed to initialize Supabase: $e');
    }
  }

  static bool get isInitialized => _initialized;
}
