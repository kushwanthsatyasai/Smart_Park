import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_button.dart';

class ParkingLotRegistration extends StatefulWidget {
  const ParkingLotRegistration({super.key});

  @override
  State<ParkingLotRegistration> createState() => _ParkingLotRegistrationState();
}

class _ParkingLotRegistrationState extends State<ParkingLotRegistration> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _hasCycleParking = false;
  bool _hasBikeParking = false;
  bool _hasCarParking = false;
  bool _hasVanParking = false;
  int _cycleSlots = 0;
  int _bikeSlots = 0;
  int _carSlots = 0;
  int _vanSlots = 0;
  double _cycleRate = 0;
  double _bikeRate = 0;
  double _carRate = 0;
  double _vanRate = 0;
  bool _isLoading = false;

  Future<void> _registerParkingLot() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_hasCycleParking && !_hasBikeParking && !_hasCarParking && !_hasVanParking) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one vehicle type'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      
      // Create parking lot
      final parkingLotData = await supabase
          .from('parking_lots')
          .insert({
            'name': _nameController.text.trim(),
            'owner_id': supabase.auth.currentUser?.id,
            'has_cycle_parking': _hasCycleParking,
            'has_bike_parking': _hasBikeParking,
            'has_car_parking': _hasCarParking,
            'has_van_parking': _hasVanParking,
            'cycle_slots_total': _cycleSlots,
            'bike_slots_total': _bikeSlots,
            'car_slots_total': _carSlots,
            'van_slots_total': _vanSlots,
          })
          .select()
          .single();

      // Create slots for each vehicle type
      if (_hasCycleParking) {
        await _createSlots(parkingLotData['id'], 'cycle', _cycleSlots, _cycleRate);
      }
      if (_hasBikeParking) {
        await _createSlots(parkingLotData['id'], 'bike', _bikeSlots, _bikeRate);
      }
      if (_hasCarParking) {
        await _createSlots(parkingLotData['id'], 'car', _carSlots, _carRate);
      }
      if (_hasVanParking) {
        await _createSlots(parkingLotData['id'], 'van', _vanSlots, _vanRate);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parking lot registered successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacementNamed(context, '/admin/generate-qr');
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createSlots(String parkingLotId, String vehicleType, int count, double rate) async {
    final slots = List.generate(count, (index) => {
      'parking_lot_id': parkingLotId,
      'slot_number': '$vehicleType-${index + 1}',
      'vehicle_type': vehicleType,
      'rate_per_hour': rate,
      'is_available': true,
    });

    await Supabase.instance.client
        .from('parking_slots')
        .insert(slots);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Parking Lot'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Parking Lot Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter parking lot name' : null,
              ),
              const SizedBox(height: 24),
              const Text(
                'Available Vehicle Types',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              CheckboxListTile(
                title: const Text('Cycle Parking'),
                value: _hasCycleParking,
                onChanged: (value) {
                  setState(() => _hasCycleParking = value ?? false);
                },
              ),
              if (_hasCycleParking) ...[
                _buildSlotInput('Number of Cycle Slots', (value) {
                  setState(() => _cycleSlots = int.tryParse(value) ?? 0);
                }),
                _buildRateInput('Cycle Rate per Hour', (value) {
                  setState(() => _cycleRate = double.tryParse(value) ?? 0);
                }),
              ],
              CheckboxListTile(
                title: const Text('Bike Parking'),
                value: _hasBikeParking,
                onChanged: (value) {
                  setState(() => _hasBikeParking = value ?? false);
                },
              ),
              if (_hasBikeParking) ...[
                _buildSlotInput('Number of Bike Slots', (value) {
                  setState(() => _bikeSlots = int.tryParse(value) ?? 0);
                }),
                _buildRateInput('Bike Rate per Hour', (value) {
                  setState(() => _bikeRate = double.tryParse(value) ?? 0);
                }),
              ],
              CheckboxListTile(
                title: const Text('Car Parking'),
                value: _hasCarParking,
                onChanged: (value) {
                  setState(() => _hasCarParking = value ?? false);
                },
              ),
              if (_hasCarParking) ...[
                _buildSlotInput('Number of Car Slots', (value) {
                  setState(() => _carSlots = int.tryParse(value) ?? 0);
                }),
                _buildRateInput('Car Rate per Hour', (value) {
                  setState(() => _carRate = double.tryParse(value) ?? 0);
                }),
              ],
              CheckboxListTile(
                title: const Text('Van Parking'),
                value: _hasVanParking,
                onChanged: (value) {
                  setState(() => _hasVanParking = value ?? false);
                },
              ),
              if (_hasVanParking) ...[
                _buildSlotInput('Number of Van Slots', (value) {
                  setState(() => _vanSlots = int.tryParse(value) ?? 0);
                }),
                _buildRateInput('Van Rate per Hour', (value) {
                  setState(() => _vanRate = double.tryParse(value) ?? 0);
                }),
              ],
              const SizedBox(height: 24),
              CustomButton(
                text: 'Register Parking Lot',
                onPressed: _isLoading ? null : _registerParkingLot,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlotInput(String label, void Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        validator: (value) {
          if (value?.isEmpty ?? true) return 'Please enter number of slots';
          if (int.tryParse(value!) == null) return 'Please enter a valid number';
          if (int.parse(value) <= 0) return 'Number of slots must be greater than 0';
          return null;
        },
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildRateInput(String label, void Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixText: '₹ ',
        ),
        keyboardType: TextInputType.number,
        validator: (value) {
          if (value?.isEmpty ?? true) return 'Please enter rate';
          if (double.tryParse(value!) == null) return 'Please enter a valid rate';
          if (double.parse(value) <= 0) return 'Rate must be greater than 0';
          return null;
        },
        onChanged: onChanged,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
} 