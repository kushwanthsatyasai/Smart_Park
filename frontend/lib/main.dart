import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/booking/map_screen.dart';
import 'screens/booking/booking_details_screen.dart';
import 'screens/booking/booking_confirmation_screen.dart';
import 'screens/qr_code_screen.dart';
import 'screens/scanner_screen.dart';
import 'screens/booking/qr_scanner_screen.dart';
import 'screens/profile/complete_profile_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/generate_qr_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'utils/map_utils.dart';
import 'screens/admin/parking_lot_registration.dart';
import 'screens/admin/parking_qr_generator.dart';
import 'screens/booking/booking_screen.dart';
import 'screens/booking/booking_history_screen.dart';
import 'utils/app_state.dart';
import 'screens/payment/payment_screen.dart';
import 'package:app_links/app_links.dart';
import 'package:provider/provider.dart';
import 'providers/vehicle_provider.dart';
import 'services/slot_management_service.dart';
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_services.dart';
import 'config/supabase_config.dart';
import 'screens/parking_owner/parking_owner_dashboard.dart';

// Global instance for easy access
SlotManagementService? slotManagementService;

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Load environment variables
    await dotenv.load(fileName: ".env");

    // Initialize Supabase with proper configuration
    await SupabaseConfig.initialize();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => VehicleProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e) {
    print('Initialization error: $e');
    runApp(ErrorApp(error: e.toString()));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Smart Park',
          theme: themeProvider.isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<Map<String, dynamic>> _getUserRole(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();
      
      final isAdmin = await AdminServices().checkAdminAccess();
      final role = response['role'] as String? ?? 'customer';
      
      return {
        'isAdmin': isAdmin,
        'role': role,
      };
    } catch (e) {
      print('Error checking user role: $e');
      return {
        'isAdmin': false,
        'role': 'customer',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final session = snapshot.data!.session;
          if (session != null) {
            return FutureBuilder<Map<String, dynamic>>(
              future: _getUserRole(session.user.id),
              builder: (context, roleSnapshot) {
                if (roleSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (roleSnapshot.hasError) {
                  return Scaffold(
                    body: Center(
                      child: Text('Error: ${roleSnapshot.error}'),
                    ),
                  );
                }

                final userData = roleSnapshot.data!;
                final isAdmin = userData['isAdmin'] ?? false;
                final role = userData['role'] ?? 'customer';
                
                if (isAdmin) {
                  return const AdminDashboard();
                } else if (role == 'parking_owner') {
                  return const ParkingOwnerDashboard();
                } else {
                  return const HomeScreen();
                }
              },
            );
          }
        }
        return const LoginScreen();
      },
    );
  }
}

class LoadingApp extends StatelessWidget {
  const LoadingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Error initializing app',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
      
      // Handle deep link if app was opened by the link
      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
  
      // Listen for deep links while app is running
      appLinks.uriLinkStream.listen((Uri? uri) {
        if (uri != null) {
          _handleDeepLink(uri);
        }
      });
    } catch (e) {
      print('Deep link initialization error: $e');
    }
  }

  void _handleDeepLink(Uri uri) async {
    try {
      print('Handling deep link: ${uri.toString()}'); // Debug log
      if (uri.host == 'login-callback') {
        // Handle email confirmation
        final fragment = uri.fragment;
        print('URL fragment: $fragment'); // Debug log

        if (fragment.isNotEmpty) {
          // Parse the fragment
          final params = Uri.parse('?$fragment').queryParameters;
          print('URL parameters: $params'); // Debug log

          // Check for confirmation type
          final type = params['type'];
          if (type == 'signup' || type == 'recovery' || type == 'invite') {
            // Get tokens
            final accessToken = params['access_token'];
            final refreshToken = params['refresh_token'];

            print('Access token: $accessToken'); // Debug log
            print('Refresh token: $refreshToken'); // Debug log

            if (accessToken != null) {
              // Set the session
              await Supabase.instance.client.auth.setSession(accessToken);
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Email confirmed successfully! Please login.'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 4),
                  ),
                );
                
                // Sign out and redirect to login
                await Supabase.instance.client.auth.signOut();
                Navigator.of(context).pushReplacementNamed('/login');
              }
            } else {
              throw 'No access token found in confirmation link';
            }
          }
        }
      }
    } catch (e) {
      print('Error handling deep link: $e'); // Debug log
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error confirming email: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
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

// Add this widget to your AppBar actions in every screen
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return IconButton(
          icon: Icon(
            themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            color: themeProvider.isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: () {
            themeProvider.toggleTheme();
          },
          tooltip: themeProvider.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
        );
      },
    );
  }
}
