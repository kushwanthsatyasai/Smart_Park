import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'auth/login_screen.dart';
import 'home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    try {
      final appLinks = AppLinks();
      final initialUri = await appLinks.getInitialAppLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }

      appLinks.uriLinkStream.listen((Uri? uri) {
        if (uri != null) {
          _handleDeepLink(uri);
        }
      });
    } catch (e) {
      print('Deep link initialization error: $e');
    }
  }

  void _handleDeepLink(Uri uri) {
    if (uri.host == 'login-callback') {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  Future<void> _checkAuthAndNavigate() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;

      if (!mounted) return;

      if (session != null) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      print('Auth check error: $e');
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
} 