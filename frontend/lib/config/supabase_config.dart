import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = 'https://ubqrfmyvutvstgxeubvr.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVicXJmbXl2dXR2c3RneGV1YnZyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzkyNzc1MDgsImV4cCI6MjA1NDg1MzUwOH0.3wU-ZJFNSJZIoL2DdrlJjbmb1799ElBtt_IXNwXf-ek';
  
  // Deep link URL for both mobile and email confirmations
  static const String redirectUrl = 'smartpark://login-callback';
  
  static bool isValid() {
    return url.isNotEmpty && anonKey.isNotEmpty;
  }

  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
        debug: true,
      );
    } catch (e) {
      print('Error initializing Supabase: $e');
      rethrow;
    }
  }
} 