import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final _supabase = Supabase.instance.client;
  bool _isProcessing = false;
  String? _verificationResult;

  Future<void> _verifyQRCode(String qrData) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      // Parse QR data
      final data = jsonDecode(qrData);
      final bookingId = data['booking_id'];
      final verificationCode = data['verification_code'];

      // Get booking details
      final booking = await _supabase
          .from('parking_bookings')
          .select()
          .eq('id', bookingId)
          .eq('verification_code', verificationCode)
          .single();

      if (booking == null) {
        setState(() => _verificationResult = 'Invalid booking!');
        return;
      }

      final now = DateTime.now();
      String newStatus;
      Map<String, dynamic> updateData = {};

      // Check if this is entry or exit verification
      if (booking['entry_time'] == null) {
        // This is entry verification
        updateData = {
          'entry_time': now.toIso8601String(),
          'status': 'active',
          'is_verified': true
        };
        newStatus = 'Entry verified';
      } else if (booking['exit_time'] == null) {
        // This is exit verification
        // Calculate final fee based on actual duration
        final entryTime = DateTime.parse(booking['entry_time']);
        final duration = now.difference(entryTime).inHours + 1; // Round up to next hour
        final ratePerHour = booking['amount'];
        final totalFee = duration * ratePerHour;

        updateData = {
          'exit_time': now.toIso8601String(),
          'status': 'completed',
          'duration': duration,
          'total_fee': totalFee
        };
        newStatus = 'Exit verified\nTotal Fee: ₹$totalFee';

        // Make slot available again
        await _supabase
            .from('parking_slots')
            .update({'is_available': true})
            .eq('id', booking['assigned_slot_id']);
      } else {
        setState(() => _verificationResult = 'Booking already completed!');
        return;
      }

      // Update booking
      await _supabase
          .from('parking_bookings')
          .update(updateData)
          .eq('id', bookingId);

      setState(() => _verificationResult = 'Verification successful!\n$newStatus');
    } catch (e) {
      print('Verification error: $e');
      setState(() => _verificationResult = 'Error: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Booking'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _verifyQRCode(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
          if (_verificationResult != null)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _verificationResult!.contains('successful')
                            ? Icons.check_circle
                            : Icons.error,
                        color: _verificationResult!.contains('successful')
                            ? Colors.green
                            : Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _verificationResult!,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => _verificationResult = null);
                        },
                        child: const Text('Scan Another'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_isProcessing)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
} 