import 'package:flutter_dotenv/flutter_dotenv.dart';

class Secrets {
  static String get GOOGLE_MAPS_API_KEY => 
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  
  static String get FIREBASE_DB_URL => 
      dotenv.env['FIREBASE_DB_URL'] ?? '';
  
  static bool isValid() {
    return GOOGLE_MAPS_API_KEY.isNotEmpty && 
           FIREBASE_DB_URL.isNotEmpty;
  }
} 