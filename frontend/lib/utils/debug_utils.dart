import 'package:flutter/foundation.dart';

class DebugUtils {
  static void printDebugInfo(String message) {
    if (kDebugMode) {
      print('🔧 DEBUG: $message');
    }
  }

  static void logStateChange(String screen, String action) {
    if (kDebugMode) {
      print('📱 SCREEN: $screen | ACTION: $action');
    }
  }
}
