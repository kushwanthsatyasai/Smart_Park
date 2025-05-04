import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/booking_monitor_service.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final _supabase = Supabase.instance.client;
  final _bookingMonitor = BookingMonitorService();
  bool _isProcessing = false;

  Future<void> _processQRCode(String code) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      // Parse the QR code data
      final bookingData = await _supabase
          .from('parking_bookings')
          .select('*, parking_slots(*)')
          .eq('verification_code', code)
          .single();

      if (bookingData == null) {
        throw 'Invalid QR code';
      }

      final bookingStatus = bookingData['status'];
      final entryTime = bookingData['entry_time'];
      final exitTime = bookingData['exit_time'];
      final bookingId = bookingData['id'];
      final slotId = bookingData['slot_id'];

      if (bookingStatus == 'expired') {
        throw 'This booking has expired';
      }

      if (bookingStatus == 'completed') {
        throw 'This booking is already completed';
        }
        
      // Handle entry
      if (entryTime == null) {
        await _supabase
            .from('parking_bookings')
            .update({
              'status': 'active',
              'entry_time': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', bookingId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Entry recorded successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      // Handle exit
      else if (exitTime == null) {
        await _supabase
            .from('parking_bookings')
            .update({
              'status': 'completed',
              'exit_time': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', bookingId);

        // Handle completed booking
        await _bookingMonitor.handleCompletedBooking(bookingId, slotId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Exit recorded successfully. Booking completed.'),
              backgroundColor: Colors.green,
            ),
          );
      }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _processQRCode(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
} 