import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';

class QRDisplayScreen extends StatelessWidget {
  final Map<String, dynamic> booking;
  final String parkingLotName;
  final String slotNumber;
  final DateTime bookingTime;
  final int duration;
  final String totalFee;

  const QRDisplayScreen({
    super.key,
    required this.booking,
    required this.parkingLotName,
    required this.slotNumber,
    required this.bookingTime,
    required this.duration,
    required this.totalFee,
  });

  @override
  Widget build(BuildContext context) {
    final qrData = jsonEncode({
      'booking_id': booking['id'],
      'verification_code': booking['verification_code'],
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Confirmed'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
            const SizedBox(height: 24),
            Center(
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Verification Code', booking['verification_code']),
                    const Divider(),
                    _buildDetailRow('Parking Lot', parkingLotName),
                    _buildDetailRow('Slot Number', slotNumber),
                    _buildDetailRow('Duration', '$duration hours'),
                    _buildDetailRow('Total Fee', '₹$totalFee'),
                    const Divider(),
                    _buildDetailRow('Booking Time', bookingTime.toString()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('• Show this QR code at the parking entrance'),
                    Text('• Use verification code if QR scanning fails'),
                    Text('• Keep this ticket until you exit the parking'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
} 