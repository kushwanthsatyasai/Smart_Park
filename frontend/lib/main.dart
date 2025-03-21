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
import 'package:google_fonts/google_fonts.dart';
import 'utils/map_utils.dart';
import 'screens/admin/parking_lot_registration.dart';
import 'screens/admin/parking_qr_generator.dart';
import 'screens/booking/booking_screen.dart';
import 'screens/booking/booking_history_screen.dart';
import 'utils/app_state.dart';
import 'screens/payment/payment_screen.dart';

void main() {
  runApp(const LoadingApp());
  _initializeApp();
}

Future<void> _initializeApp() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Load environment variables
    await dotenv.load(fileName: ".env");

    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
      authFlowType: AuthFlowType.pkce,
    );

    print('Supabase initialized successfully');
    print('URL: ${Supabase.instance.client.supabaseUrl}');

    runApp(const MyApp());
  } catch (e) {
    print('Initialization error: $e');
    runApp(ErrorApp(error: e.toString()));
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Parking App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/': (context) => const LoginScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/map': (context) => const MapScreen(),
        '/scanner': (context) => const ScannerScreen(),
        '/booking-history': (context) => const BookingHistoryScreen(),
        '/admin/dashboard': (context) => const AdminDashboard(),
        '/admin/register-parking': (context) => const ParkingLotRegistration(),
        '/admin/generate-qr': (context) => const ParkingQRGenerator(),
        '/qr-verification': (context) => const QRScannerScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/booking') {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args == null) {
            return MaterialPageRoute(
              builder: (context) => const HomeScreen(),
            );
          }
          return MaterialPageRoute(
            builder: (context) => BookingScreen(
              parkingData: args['parking_lot'],
            ),
          );
        }
        
        if (settings.name == '/booking-confirmation') {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args == null) {
            return MaterialPageRoute(
              builder: (context) => const HomeScreen(),
            );
          }
          return MaterialPageRoute(
            builder: (context) => BookingConfirmationScreen(
              bookingDetails: args['bookingDetails'],
              parkingLot: args['parkingLot'],
              assignedSlot: args['assignedSlot'],
            ),
          );
        }

        if (settings.name == '/payment') {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args == null) {
            return MaterialPageRoute(
              builder: (context) => const HomeScreen(),
            );
          }
          return MaterialPageRoute(
            builder: (context) => PaymentScreen(
              bookingId: args['bookingId'] as String,
              amount: args['amount'] as double,
            ),
          );
        }

        return MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        );
      },
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
