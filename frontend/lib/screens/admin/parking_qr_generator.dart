import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ParkingQRGenerator extends StatefulWidget {
  const ParkingQRGenerator({Key? key}) : super(key: key);

  @override
  State<ParkingQRGenerator> createState() => _ParkingQRGeneratorState();
}

class _ParkingQRGeneratorState extends State<ParkingQRGenerator> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _parkingLots = [];
  List<Map<String, dynamic>> _parkingSlots = [];
  
  Map<String, dynamic>? _selectedParkingLot;
  Map<String, dynamic>? _selectedParkingSlot;
  
  String? _lotQrData;
  String? _slotQrData;
  String _appUrl = "smartpark://";
  String _webUrl = "https://smartpark.app/";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadParkingLots();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadParkingLots() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final response = await _supabase
          .from('parking_lots')
          .select('id, name, location, total_slots, current_occupancy, owner_id')
          .eq('owner_id', _supabase.auth.currentUser!.id);
      
      setState(() {
        _parkingLots = List<Map<String, dynamic>>.from(response);
        if (_parkingLots.isNotEmpty) {
          _selectedParkingLot = _parkingLots.first;
          _generateParkingLotQR();
          _loadParkingSlots(_selectedParkingLot!['id']);
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Error loading parking lots: $e');
    }
  }

  Future<void> _loadParkingSlots(String parkingLotId) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final response = await _supabase
          .from('parking_slots')
          .select('id, slot_number, is_occupied, parking_lot_id, slot_type')
          .eq('parking_lot_id', parkingLotId);
      
      setState(() {
        _parkingSlots = List<Map<String, dynamic>>.from(response);
        if (_parkingSlots.isNotEmpty) {
          _selectedParkingSlot = _parkingSlots.first;
          _generateParkingSlotQR();
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Error loading parking slots: $e');
    }
  }

  void _generateParkingLotQR() {
    if (_selectedParkingLot == null) return;
    
    // Generate a deep link URL that includes the parking lot ID
    final baseUrl = kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux
        ? _webUrl
        : _appUrl;
    
    final qrUrl = '$baseUrl'
        'booking?parking_lot_id=${_selectedParkingLot!['id']}'
        '&parking_lot_name=${Uri.encodeComponent(_selectedParkingLot!['name'])}'
        '&source=qr';
    
    setState(() {
      _lotQrData = qrUrl;
    });
  }

  void _generateParkingSlotQR() {
    if (_selectedParkingLot == null || _selectedParkingSlot == null) return;
    
    // Generate a deep link URL that includes both parking lot and slot IDs
    final baseUrl = kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux
        ? _webUrl
        : _appUrl;
    
    final qrUrl = '$baseUrl'
        'booking?parking_lot_id=${_selectedParkingLot!['id']}'
        '&parking_lot_name=${Uri.encodeComponent(_selectedParkingLot!['name'])}'
        '&slot_id=${_selectedParkingSlot!['id']}'
        '&slot_number=${_selectedParkingSlot!['slot_number']}'
        '&source=qr';
    
    setState(() {
      _slotQrData = qrUrl;
    });
  }
  
  Future<void> _shareQRCode(String qrData, String description) async {
    try {
      // For Windows, show a dialog
      if (kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('QR Code Generated'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'QR code has been generated. On mobile devices, you would be able to share this directly.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  qrData,
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        return;
      }
      
      // For mobile
      final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'smartpark_qr_$now.png';
      
      // Generate QR code image
      final qrPainter = QrPainter(
        data: qrData,
        version: QrVersions.auto,
        gapless: true,
        color: Colors.black,
        emptyColor: Colors.white,
      );
      
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/$fileName';
      final file = File(path);
      
      final qrImage = await qrPainter.toImageData(320);
      if (qrImage != null) {
        await file.writeAsBytes(qrImage.buffer.asUint8List());
        
        // Share the QR code image
        await Share.shareXFiles(
          [XFile(path)],
          text: 'Smart Park QR Code - $description',
          subject: 'Smart Park QR Code',
        );
      }
    } catch (e) {
      _showError('Error sharing QR code: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parking QR Generator'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Parking Lot QR'),
            Tab(text: 'Parking Slot QR'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildParkingLotQRTab(),
                _buildParkingSlotQRTab(),
              ],
            ),
    );
  }

  Widget _buildParkingLotQRTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
        padding: const EdgeInsets.all(16.0),
          child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                  const Text(
                    'Select Parking Lot',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _parkingLots.isEmpty
                      ? const Text('No parking lots available')
                      : DropdownButtonFormField<Map<String, dynamic>>(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          value: _selectedParkingLot,
                          items: _parkingLots.map((lot) {
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: lot,
                              child: Text('${lot['name']} (${lot['location']})'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedParkingLot = value;
                                _lotQrData = null;
                              });
                              _generateParkingLotQR();
                              _loadParkingSlots(value['id']);
                            }
                          },
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Parking Lot QR Code',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Customers will be directed to book a slot at this specific parking lot when they scan this QR code.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          if (_lotQrData != null) ...[
            Center(
              child: Container(
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
                      data: _lotQrData!,
                      version: QrVersions.auto,
                      size: 250.0,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _selectedParkingLot!['name'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_selectedParkingLot!['location']),
                    const SizedBox(height: 4),
                    Text('Total Slots: ${_selectedParkingLot!['total_slots']}'),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Place this QR at the parking lot entrance',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Download & Share QR Code'),
                onPressed: () => _shareQRCode(_lotQrData!, _selectedParkingLot!['name']),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParkingSlotQRTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Parking Lot',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
                  _parkingLots.isEmpty
                      ? const Text('No parking lots available')
                      : DropdownButtonFormField<Map<String, dynamic>>(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          value: _selectedParkingLot,
                          items: _parkingLots.map((lot) {
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: lot,
                              child: Text('${lot['name']} (${lot['location']})'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedParkingLot = value;
                                _slotQrData = null;
                              });
                              _loadParkingSlots(value['id']);
                            }
                          },
                        ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Parking Slot',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
                  _parkingSlots.isEmpty
                      ? const Text('No slots available for this parking lot')
                      : DropdownButtonFormField<Map<String, dynamic>>(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          value: _selectedParkingSlot,
                          items: _parkingSlots.map((slot) {
                            final status = slot['is_occupied'] ? ' (Occupied)' : ' (Available)';
                            final slotType = slot['slot_type'] != null ? ' - ${slot['slot_type']}' : '';
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: slot,
                              child: Text('Slot ${slot['slot_number']}$slotType$status'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedParkingSlot = value;
                                _slotQrData = null;
                              });
                              _generateParkingSlotQR();
                            }
                          },
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Parking Slot QR Code',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Customers will be directed to book this specific slot when they scan this QR code.',
            style: TextStyle(color: Colors.grey),
          ),
                const SizedBox(height: 24),
          if (_slotQrData != null && _selectedParkingSlot != null) ...[
            Center(
              child: Container(
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
                      data: _slotQrData!,
                      version: QrVersions.auto,
                      size: 250.0,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 16),
                      Text(
                      'Slot ${_selectedParkingSlot!['slot_number']}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_selectedParkingLot!['name']),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _selectedParkingSlot!['is_occupied'] ? Colors.red.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _selectedParkingSlot!['is_occupied'] ? 'Occupied' : 'Available',
                        style: TextStyle(
                          color: _selectedParkingSlot!['is_occupied'] ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ),
                      const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Place this QR at the individual parking slot',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Download & Share QR Code'),
                onPressed: () => _shareQRCode(
                  _slotQrData!,
                  'Slot ${_selectedParkingSlot!['slot_number']} - ${_selectedParkingLot!['name']}',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                  ),
                ),
              ],
            ],
      ),
    );
  }
} 