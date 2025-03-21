import 'package:shared_preferences/shared_preferences.dart';

class AppState {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    if (_prefs != null)
      return; // Add this check to prevent multiple initializations
    _prefs = await SharedPreferences.getInstance();
  }

  // Save state methods
  Future<void> saveLastScreen(String screenName) async {
    await _prefs?.setString('last_screen', screenName);
  }

  // Get state methods
  String? getLastScreen() {
    return _prefs?.getString('last_screen');
  }
}
