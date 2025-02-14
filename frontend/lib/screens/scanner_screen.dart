import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:firebase_database/firebase_database.dart';

class ScannerScreen extends StatefulWidget {
  @override
  _ScannerScreenState createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  String qrResult = "Scan a QR Code";

  Future<void> scanQRCode() async {
    String scanResult = await FlutterBarcodeScanner.scanBarcode(
      "#ff6666", "Cancel", true, ScanMode.QR);

    if (scanResult != "-1") {
      setState(() => qrResult = scanResult);
      validateQRCode(scanResult);
    }
  }

  void validateQRCode(String qrData) {
    DatabaseReference dbRef = FirebaseDatabase.instance.ref("bookings");
    dbRef.child(qrData.split("_")[0]).onValue.listen((DatabaseEvent event) {
      if (event.snapshot.exists) {
        final dynamic data = event.snapshot.value;
        if (data != null) {
          print("Valid QR Code: Entry/Exit Allowed");
        } else {
          print("Invalid QR Code!");
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("QR Scanner")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(qrResult, style: TextStyle(fontSize: 18)),
            ElevatedButton(
              onPressed: scanQRCode,
              child: Text("Scan QR Code"),
            ),
          ],
        ),
      ),
    );
  }
}
