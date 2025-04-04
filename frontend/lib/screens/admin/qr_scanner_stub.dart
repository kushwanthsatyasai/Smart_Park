// This is a stub implementation for platforms where QR scanner is not supported
import 'package:flutter/material.dart';

// Stub class for QRView
class QRView extends StatelessWidget {
  final GlobalKey key;
  final Function(QRViewController) onQRViewCreated;

  const QRView({
    required this.key,
    required this.onQRViewCreated,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'QR Scanner not available on this platform',
        textAlign: TextAlign.center,
      ),
    );
  }
}

// Stub class for QRViewController
class QRViewController {
  Stream<Barcode> get scannedDataStream => Stream.empty();
  
  void dispose() {}
  
  void pauseCamera() {}
  
  void resumeCamera() {}
}

// Stub class for Barcode
class Barcode {
  final String? code;
  final int? format;
  
  Barcode({this.code, this.format});
} 