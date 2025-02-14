import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth/login_screen.dart';
import 'booking/booking_screen.dart';  // Ensure this is correctly imported
import '../widgets/custom_button.dart';


class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Parking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await supabase.auth.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/');
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Welcome to Smart Parking',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Button to Navigate to Booking Screen
              CustomButton(
                text: 'Book a Parking Spot',
                onPressed: () {
                  print("Navigating to Booking Screen...");
                  Navigator.pushNamed(context, '/booking');
                },
              ),
              const SizedBox(height: 20),

              // Button to Navigate to Map Screen
              CustomButton(
                text: 'View Parking Map',
                onPressed: () {
                  print("Navigating to Map Screen...");
                  Navigator.pushNamed(context, '/map');
                },
              ),
              const SizedBox(height: 20),

              // Button to Generate QR Code
              CustomButton(
                text: 'Generate QR Code',
                onPressed: () {
                  print("Navigating to QR Code Screen...");
                  Navigator.pushNamed(context, '/qr_code');
                },
              ),
              const SizedBox(height: 20),

              // Button to Open QR Scanner
              CustomButton(
                text: 'Scan QR Code',
                onPressed: () {
                  print("Navigating to Scanner Screen...");
                  Navigator.pushNamed(context, '/scanner');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
