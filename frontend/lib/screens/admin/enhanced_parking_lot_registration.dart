import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_button.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:http/http.dart' as http;

class EnhancedParkingLotRegistration extends StatefulWidget {
  const EnhancedParkingLotRegistration({super.key});

  @override
  State<EnhancedParkingLotRegistration> createState() => _EnhancedParkingLotRegistrationState();
}

class _EnhancedParkingLotRegistrationState extends State<EnhancedParkingLotRegistration> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  
  // Parking lot controllers
  final _parkingLotNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _totalSlotsController = TextEditingController();
  
  // Vehicle type and parking slots configuration
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
  String? _errorMessage;
  bool _passwordVisible = false;
  final _passwordController = TextEditingController();
  
  // Add price per hour controller
  final _pricePerHourController = TextEditingController(text: '0.0');
  bool _sendEmailNotification = true; // Default to true

  // Generate a secure password
  String _generateSecurePassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
    final random = Random.secure();
    return List.generate(12, (_) => chars[random.nextInt(chars.length)]).join();
  }

  @override
  void initState() {
    super.initState();
    // Set default password
    _passwordController.text = _generateSecurePassword();
  }

  @override
  void dispose() {
    _parkingLotNameController.dispose();
    _ownerNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _totalSlotsController.dispose();
    _passwordController.dispose();
    _pricePerHourController.dispose();
    super.dispose();
  }

  Future<void> _registerParkingLot() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Make sure at least one parking type is selected
    if (!_hasCycleParking && !_hasBikeParking && !_hasCarParking && !_hasVanParking) {
      setState(() {
        _errorMessage = 'Please select at least one vehicle type';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Calculate total slots
    final totalSlots = _cycleSlots + _bikeSlots + _carSlots + _vanSlots;
    if (totalSlots <= 0) {
      setState(() {
        _errorMessage = 'Please add at least one parking slot';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Store the current admin session before proceeding
      final adminSession = _supabase.auth.currentSession;
      
      // Check if a user with this email already exists
      String ownerId;
      try {
        final userLookup = await _supabase
            .from('profiles')
            .select('id')
            .eq('email', _emailController.text.trim())
            .single();
        
        // User already exists, use their ID
        ownerId = userLookup['id'];
        print('User already exists with ID: $ownerId');
      } catch (e) {
        // User doesn't exist, create a new one
        print('Creating new user account');
        final AuthResponse res = await _supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          data: {
            'name': _ownerNameController.text.trim(),
            'role': 'parking_owner',
            'phone_number': _phoneController.text.trim(),
          },
        );

        if (res.user == null) {
          throw Exception('Failed to create owner account');
        }

        ownerId = res.user!.id;
        
        // Create profile record for the owner
        await _supabase.from('profiles').upsert({
          'id': ownerId,
          'name': _ownerNameController.text.trim(),
          'phone_number': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'role': 'parking_owner'
        });
      }

      // Parse price per hour value
      double pricePerHour = double.tryParse(_pricePerHourController.text.trim()) ?? 0.0;
      
      // Create parking lot
      final parkingLotData = await _supabase
          .from('parking_lots')
          .insert({
            'name': _parkingLotNameController.text.trim(),
            'owner_id': ownerId,
            'address': _addressController.text.trim(),
            'latitude': double.tryParse(_latitudeController.text.trim()),
            'longitude': double.tryParse(_longitudeController.text.trim()),
            'total_slots': totalSlots,
            'price_per_hour': pricePerHour,
            'has_cycle_parking': _hasCycleParking,
            'has_bike_parking': _hasBikeParking,
            'has_car_parking': _hasCarParking,
            'has_van_parking': _hasVanParking,
            'cycle_slots_total': _cycleSlots,
            'bike_slots_total': _bikeSlots,
            'car_slots_total': _carSlots,
            'van_slots_total': _vanSlots,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      // Create slots for each vehicle type
      if (_hasCycleParking && _cycleSlots > 0) {
        await _createSlots(parkingLotData['id'], 'cycle', _cycleSlots, _cycleRate);
      }
      if (_hasBikeParking && _bikeSlots > 0) {
        await _createSlots(parkingLotData['id'], 'bike', _bikeSlots, _bikeRate);
      }
      if (_hasCarParking && _carSlots > 0) {
        await _createSlots(parkingLotData['id'], 'car', _carSlots, _carRate);
      }
      if (_hasVanParking && _vanSlots > 0) {
        await _createSlots(parkingLotData['id'], 'van', _vanSlots, _vanRate);
      }

      // Send email notification if enabled
      String emailStatus = '';
      if (_sendEmailNotification) {
        try {
          final emailResult = await _sendOwnerCredentialsEmail(
            _emailController.text.trim(),
            _passwordController.text,
            _ownerNameController.text.trim(),
            _parkingLotNameController.text.trim()
          );
          emailStatus = emailResult ? 'Email sent successfully' : 'Failed to send email';
        } catch (e) {
          emailStatus = 'Error sending email: ${e.toString()}';
          print('Email sending error: $e');
        }
      }
      
      // Ensure the admin is logged back in after all operations
      if (adminSession != null) {
        await _supabase.auth.setSession(adminSession.accessToken);
      }

      // Show success dialog with credentials
      if (mounted) {
        await _showSuccessDialog(
          _emailController.text.trim(),
          _passwordController.text,
          emailStatus: emailStatus,
        );
        Navigator.pushReplacementNamed(context, '/admin/dashboard');
      }
    } catch (e) {
      print('Error registering parking lot: $e');
      setState(() {
        _errorMessage = e.toString();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${_errorMessage!}'),
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
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    await _supabase.from('parking_slots').insert(slots);
  }

  Future<bool> _sendOwnerCredentialsEmail(
    String email, String password, String ownerName, String parkingLotName) async {
    try {
      // Call Supabase edge function to send email
      final response = await _supabase.functions.invoke(
        'send-owner-credentials',
        body: {
          'email': email,
          'password': password,
          'ownerName': ownerName,
          'parkingLotName': parkingLotName,
        },
      );
      
      if (response.status != 200) {
        print('Error sending email: ${response.data}');
        return false;
      }
      
      return true;
    } catch (e) {
      print('Exception sending email: $e');
      return false;
    }
  }

  Future<void> _showSuccessDialog(String email, String password, {String emailStatus = ''}) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Registration Successful'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Parking lot "${_parkingLotNameController.text}" has been registered successfully!'),
              const SizedBox(height: 16),
              const Text(
                'Owner Login Credentials:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildCredentialRow('Email:', email),
              _buildCredentialRow('Password:', password),
              const SizedBox(height: 16),
              if (emailStatus.isNotEmpty) ...[
                Text(
                  'Email notification: $emailStatus',
                  style: TextStyle(
                    color: emailStatus.contains('successfully') ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                'Important: Please save these credentials or share them with the parking lot owner. They will need them to log in.',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Copy credentials to clipboard
              Clipboard.setData(ClipboardData(
                text: 'Email: $email\nPassword: $password',
              ));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Credentials copied to clipboard'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('COPY CREDENTIALS'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Parking Lot'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSection(
                      title: 'Parking Lot Information',
                      children: [
                        TextFormField(
                          controller: _parkingLotNameController,
                          decoration: const InputDecoration(
                            labelText: 'Parking Lot Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.local_parking),
                          ),
                          validator: (value) =>
                              value?.isEmpty ?? true ? 'Please enter parking lot name' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: 'Address',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.location_on),
                          ),
                          validator: (value) =>
                              value?.isEmpty ?? true ? 'Please enter address' : null,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _latitudeController,
                                decoration: const InputDecoration(
                                  labelText: 'Latitude',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.my_location),
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (value) {
                                  if (value?.isEmpty ?? true) return 'Please enter latitude';
                                  if (double.tryParse(value!) == null) {
                                    return 'Invalid latitude format';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _longitudeController,
                                decoration: const InputDecoration(
                                  labelText: 'Longitude',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.my_location),
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (value) {
                                  if (value?.isEmpty ?? true) return 'Please enter longitude';
                                  if (double.tryParse(value!) == null) {
                                    return 'Invalid longitude format';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _getCurrentLocation,
                            icon: const Icon(Icons.my_location),
                            label: const Text('Get Current Location'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _pricePerHourController,
                          decoration: const InputDecoration(
                            labelText: 'Global Rate per Hour (₹)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.monetization_on),
                            prefixText: '₹ ',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Please enter price per hour';
                            if (double.tryParse(value!) == null) {
                              return 'Invalid price format';
                            }
                            if (double.parse(value) < 0) {
                              return 'Price cannot be negative';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                    
                    _buildSection(
                      title: 'Owner Information',
                      children: [
                        TextFormField(
                          controller: _ownerNameController,
                          decoration: const InputDecoration(
                            labelText: 'Owner Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (value) =>
                              value?.isEmpty ?? true ? 'Please enter owner name' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email),
                          ),
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Please enter email';
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                .hasMatch(value!)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Please enter phone number';
                            if (value!.length < 10) return 'Please enter a valid phone number';
                            return null;
                          },
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password (for owner login)',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _passwordVisible ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _passwordVisible = !_passwordVisible;
                                });
                              },
                            ),
                          ),
                          obscureText: !_passwordVisible,
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Please enter password';
                            if (value!.length < 8) return 'Password must be at least 8 characters';
                            return null;
                          },
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _passwordController.text = _generateSecurePassword();
                                _passwordVisible = true;
                              });
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Generate Password'),
                          ),
                        ),
                        // Add email notification checkbox
                        SwitchListTile(
                          title: const Text('Send login credentials via email'),
                          subtitle: const Text('Owner will receive their login details by email'),
                          value: _sendEmailNotification,
                          onChanged: (value) {
                            setState(() {
                              _sendEmailNotification = value;
                            });
                          },
                          secondary: const Icon(Icons.email),
                        ),
                      ],
                    ),
                    
                    _buildSection(
                      title: 'Available Vehicle Types',
                      children: [
                        CheckboxListTile(
                          title: const Text('Cycle Parking'),
                          value: _hasCycleParking,
                          onChanged: (value) {
                            setState(() => _hasCycleParking = value ?? false);
                          },
                          secondary: const Icon(Icons.pedal_bike),
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
                          secondary: const Icon(Icons.motorcycle),
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
                          secondary: const Icon(Icons.directions_car),
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
                          secondary: const Icon(Icons.airport_shuttle),
                        ),
                        if (_hasVanParking) ...[
                          _buildSlotInput('Number of Van Slots', (value) {
                            setState(() => _vanSlots = int.tryParse(value) ?? 0);
                          }),
                          _buildRateInput('Van Rate per Hour', (value) {
                            setState(() => _vanRate = double.tryParse(value) ?? 0);
                          }),
                        ],
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    CustomButton(
                      text: 'Register Parking Lot',
                      onPressed: _isLoading ? null : _registerParkingLot,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  void _getCurrentLocation() {
    // In a real app, you would implement actual geolocation here
    // For now, we'll just set some example values
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Getting current location...'),
        duration: Duration(seconds: 1),
      ),
    );
    
    // Example coordinates (New Delhi location)
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _latitudeController.text = '28.6139';
        _longitudeController.text = '77.2090';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location updated!'),
          backgroundColor: Colors.green,
        ),
      );
    });
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
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
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
} 