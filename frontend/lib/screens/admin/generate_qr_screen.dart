import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../widgets/custom_button.dart';
import 'parking_qr_generator.dart';

class GenerateQRScreen extends StatelessWidget {
  const GenerateQRScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate QR Codes'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'QR Code Generator',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Generate QR codes for parking lots and slots to enable easy booking for customers.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            _buildFeatureCard(
              context,
              title: 'Parking Lot QR Codes',
              description: 'Generate QR codes to place at the entrance of parking lots. When scanned, customers will be directed to book a slot in that specific lot.',
              icon: Icons.qr_code,
              color: Colors.blue,
              onTap: () => _navigateToParkingQRGenerator(context),
            ),
            const SizedBox(height: 16),
            _buildFeatureCard(
              context,
              title: 'Parking Slot QR Codes',
              description: 'Generate QR codes for individual parking slots. When scanned, customers will be directed to book that specific slot.',
              icon: Icons.local_parking,
              color: Colors.green,
              onTap: () => _navigateToParkingQRGenerator(context, tabIndex: 1),
            ),
            const SizedBox(height: 16),
            _buildInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 36,
                    color: color,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'How it works',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '1. Generate QR codes for your parking lots and slots\n'
              '2. Print and place them at the entrance and individual slots\n'
              '3. Customers scan the QR code with the Smart Park app\n'
              '4. They are directed to the booking page for that specific lot or slot',
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToParkingQRGenerator(BuildContext context, {int tabIndex = 0}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ParkingQRGenerator(),
      ),
    );
  }
} 