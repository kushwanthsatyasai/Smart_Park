import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';

class QRScannerScreen extends StatefulWidget {
  final bool isEntry; // true for entry, false for exit

  const QRScannerScreen({
    Key? key,
    required this.isEntry,
  }) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final _supabase = Supabase.instance.client;
  bool _isProcessing = false;
  MobileScannerController cameraController = MobileScannerController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEntry ? 'Scan Entry QR' : 'Scan Exit QR'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController.torchState,
              builder: (context, state, child) {
                switch (state) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off);
                  case TorchState.on:
                    return const Icon(Icons.flash_on);
                }
              },
            ),
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController.cameraFacingState,
              builder: (context, state, child) {
                switch (state) {
                  case CameraFacing.front:
                    return const Icon(Icons.camera_front);
                  case CameraFacing.back:
                    return const Icon(Icons.camera_rear);
                }
              },
            ),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: cameraController,
              onDetect: _onDetect,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black87,
            child: Text(
              widget.isEntry
                  ? 'Scan customer\'s entry QR code'
                  : 'Scan customer\'s exit QR code',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    _isProcessing = true;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) {
      _isProcessing = false;
      return;
    }

    final String qrData = barcodes.first.rawValue ?? '';
    if (qrData.isEmpty) {
      _isProcessing = false;
      return;
    }

    try {
      // Verify QR code with Supabase
      final response = await _supabase
          .from('parking_sessions')
          .select()
          .eq('qr_code', qrData)
          .single();

      if (response == null) {
        _showError('Invalid QR code');
        return;
      }

      final bool isActive = response['is_active'] ?? false;
      final DateTime startTime = DateTime.parse(response['start_time']);
      final DateTime? endTime = response['end_time'] != null 
          ? DateTime.parse(response['end_time'])
          : null;

      if (widget.isEntry) {
        if (!isActive || endTime != null) {
          _showError('This QR code is no longer valid');
          return;
        }
        
        // Update entry time and status
        await _supabase
            .from('parking_sessions')
            .update({
              'entry_time': DateTime.now().toIso8601String(),
              'status': 'active'
            })
            .eq('qr_code', qrData);

        _showSuccess('Entry Verified');
      } else {
        if (!isActive || endTime != null) {
          _showError('Invalid exit attempt');
          return;
        }

        // Calculate parking duration and fee
        final duration = DateTime.now().difference(startTime);
        final fee = _calculateParkingFee(duration);

        // Update exit time and status
        await _supabase
            .from('parking_sessions')
            .update({
              'exit_time': DateTime.now().toIso8601String(),
              'status': 'completed',
              'fee': fee,
              'is_active': false
            })
            .eq('qr_code', qrData);

        _showSuccess('Exit Processed\nParking Fee: ₹$fee');
      }
    } catch (e) {
      _showError('Error processing QR code: $e');
    } finally {
      _isProcessing = false;
    }
  }

  double _calculateParkingFee(Duration duration) {
    // Basic fee calculation (customize as needed)
    final hours = duration.inHours + (duration.inMinutes % 60 > 0 ? 1 : 0);
    return hours * 50.0; // ₹50 per hour
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
} 