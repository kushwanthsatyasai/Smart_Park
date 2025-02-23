import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/booking/map_screen.dart';
import 'screens/booking/booking_details_screen.dart';
import 'screens/booking/booking_confirmation_screen.dart';
import 'screens/qr_code_screen.dart';
import 'screens/scanner_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'utils/map_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Maps
  await MapUtils.initializeMap();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize Supabase with environment variables
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    authCallbackUrlHostname: 'login-callback',
    debug: true
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Parking App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.robotoTextTheme(
          Theme.of(context).textTheme,
        ).copyWith(
          bodyLarge: GoogleFonts.roboto(
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
          bodyMedium: GoogleFonts.roboto(
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
          titleLarge: GoogleFonts.roboto(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/booking': (context) => const MapScreen(),
        '/booking-details': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return BookingDetailsScreen(arguments: args);
        },
        '/booking-confirmation': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return BookingConfirmationScreen(booking: args);
        },
        '/map': (context) => const MapScreen(),
        '/qr_code': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return QRCodeScreen(bookingData: args);
        },
        '/scanner': (context) => const ScannerScreen(),
      },
    );
  }
}
