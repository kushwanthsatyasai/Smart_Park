import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../widgets/app_drawer.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class BookingConfirmationScreen extends StatelessWidget {
  final Map<String, dynamic> bookingDetails;
  final Map<String, dynamic> parkingLot;
  final Map<String, dynamic> assignedSlot;

  const BookingConfirmationScreen({
    super.key,
    required this.bookingDetails,
    required this.parkingLot,
    required this.assignedSlot,
  });

  @override
  Widget build(BuildContext context) {
    // Create QR data
    final qrData = jsonEncode({
      'booking_id': bookingDetails['id'],
      'verification_code': bookingDetails['verification_code'],
      'slot_number': assignedSlot['slot_number'],
      'parking_lot_id': parkingLot['id'],
    });

    final bool isEntry = bookingDetails['entry_time'] == null;
    final bool isExit = bookingDetails['entry_time'] != null && bookingDetails['exit_time'] == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEntry ? 'Show QR at Entry' : (isExit ? 'Show QR at Exit' : 'Booking Completed')),
        automaticallyImplyLeading: false,
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
            Text(
              isEntry 
                ? 'Please show this QR code at the entry gate'
                : (isExit 
                    ? 'Please show this QR code at the exit gate'
                    : 'Booking Completed'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // QR Code Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Verification Code: ${bookingDetails['verification_code']}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Booking Details Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Booking ID', bookingDetails['id']),
                    _buildDetailRow('Parking Lot', parkingLot['name']),
                    _buildDetailRow('Slot Number', assignedSlot['slot_number'].toString()),
                    _buildDetailRow('Rate', '₹${assignedSlot['rate_per_hour']}/hour'),
                    if (bookingDetails['entry_time'] != null)
                      _buildDetailRow('Entry Time', 
                        DateTime.parse(bookingDetails['entry_time']).toLocal().toString()),
                    if (bookingDetails['exit_time'] != null) ...[
                      _buildDetailRow('Exit Time', 
                        DateTime.parse(bookingDetails['exit_time']).toLocal().toString()),
                      _buildDetailRow('Total Fee', '₹${bookingDetails['total_fee']}'),
                    ],
                    _buildDetailRow('Status', bookingDetails['status'].toUpperCase()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Action Buttons
            Row(
              children: [
                if (!isEntry && !isExit)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                      icon: const Icon(Icons.home),
                      label: const Text('Go to Home'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
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
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(value),
        ],
      ),
    );
  }
}
