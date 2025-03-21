import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class ParkingQRGenerator extends StatefulWidget {
  const ParkingQRGenerator({super.key});

  @override
  State<ParkingQRGenerator> createState() => _ParkingQRGeneratorState();
}

class _ParkingQRGeneratorState extends State<ParkingQRGenerator> {
  final _formKey = GlobalKey<FormState>();
  final _parkingNameController = TextEditingController();
  final _slotNumberController = TextEditingController();
  final _rateController = TextEditingController();
  String? _generatedQR;
  bool _isLoading = false;

  Future<void> _generateQR() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      
      // Create parking lot entry in database
      final parkingLotData = await supabase
          .from('parking_lots')
          .insert({
            'name': _parkingNameController.text.trim(),
            'rate_per_hour': double.parse(_rateController.text),
            'owner_id': supabase.auth.currentUser?.id,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      // Create parking slot entry
      final slotData = await supabase
          .from('parking_slots')
          .insert({
            'parking_lot_id': parkingLotData['id'],
            'slot_number': _slotNumberController.text.trim(),
            'is_available': true,
          })
          .select()
          .single();

      // Generate QR data
      final qrData = jsonEncode({
        'parking_lot_id': parkingLotData['id'],
        'slot_id': slotData['id'],
        'name': parkingLotData['name'],
        'slot_number': slotData['slot_number'],
        'rate_per_hour': parkingLotData['rate_per_hour'],
      });

      setState(() => _generatedQR = qrData);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating QR: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Parking QR'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _parkingNameController,
                decoration: const InputDecoration(
                  labelText: 'Parking Lot Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter parking lot name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _slotNumberController,
                decoration: const InputDecoration(
                  labelText: 'Slot Number',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter slot number' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rateController,
                decoration: const InputDecoration(
                  labelText: 'Rate per Hour (₹)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter rate';
                  if (double.tryParse(value!) == null) return 'Please enter valid rate';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _generateQR,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Generate QR Code'),
              ),
              if (_generatedQR != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _parkingNameController.text,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'Slot: ${_slotNumberController.text}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      QrImageView(
                        data: _generatedQR!,
                        version: QrVersions.auto,
                        size: 200.0,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '₹${_rateController.text}/hour',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _parkingNameController.dispose();
    _slotNumberController.dispose();
    _rateController.dispose();
    super.dispose();
  }
} 