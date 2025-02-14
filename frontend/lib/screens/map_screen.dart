import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:ui' as ui;  // ✅ Import this to fix PictureRecorder & ImageByteFormat


class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  final databaseRef = FirebaseDatabase.instance.ref("parking_slots");
  Set<Marker> markers = {};

  Future<BitmapDescriptor> _createCustomMarkerBitmap(bool isAvailable) async {
    final Color markerColor = isAvailable ? Colors.green : Colors.red;
    
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();  // ✅ Use 'ui.' before PictureRecorder
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = markerColor;
    final Paint shadowPaint = Paint()
      ..color = markerColor.withOpacity(0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8);

    // Draw shadow
    canvas.drawRect(
      Rect.fromLTWH(4, 4, 40, 40),
      shadowPaint,
    );
    
    // Draw square
    canvas.drawRect(
      Rect.fromLTWH(8, 8, 32, 32),
      paint,
    );

    final img = await pictureRecorder.endRecording().toImage(48, 48);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  @override
  void initState() {
    super.initState();
    databaseRef.onValue.listen((event) async {
      final newMarkers = <Marker>{};
      Map<dynamic, dynamic> slots = event.snapshot.value as Map<dynamic, dynamic>;
      
      for (var entry in slots.entries) {
        final key = entry.key;
        final value = entry.value;
        final isAvailable = value["status"] == "Available";
        
        final customIcon = await _createCustomMarkerBitmap(isAvailable);
        
        newMarkers.add(
          Marker(
            markerId: MarkerId(key),
            position: LatLng(value["latitude"], value["longitude"]),
            infoWindow: InfoWindow(title: key, snippet: "Status: ${value['status']}"),
            icon: customIcon,
          ),
        );
      }
      
      setState(() {
        markers = newMarkers;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Parking Map")),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: LatLng(12.9716, 77.5946), zoom: 15),
        markers: markers,
        onMapCreated: (controller) {
          _controller = controller;
        },
      ),
    );
  }
}
