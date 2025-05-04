import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './admin_analytics_screen.dart';
import '../auth/login_screen.dart';
import './qr_scanner_screen.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
// Conditionally import QR scanner based on platform
import '../../utils/constants.dart';

// Import QR scanner only when not on web
import 'package:qr_code_scanner/qr_code_scanner.dart' if (dart.library.js) 'package:flutter/material.dart' as qr;
import '../../admin_services.dart';

// Import QR scanner conditionally to prevent errors on web/desktop
// Use a dummy implementation for unsupported platforms
import 'qr_scanner_stub.dart'
    if (dart.library.io) 'package:qr_code_scanner/qr_code_scanner.dart';

// Import the enhanced registration page
import './enhanced_parking_lot_registration.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  Map<String, dynamic> _stats = {};
  bool _isAdmin = false;
  late TabController _tabController;
  List<Map<String, dynamic>> _parkingLots = [];
  List<Map<String, dynamic>> _activeBookings = [];
  List<Map<String, dynamic>> _parkingHistory = [];
  Map<String, dynamic>? _scannedBooking;
  bool _isVerifying = false;
  Timer? _refreshTimer;
  
  // Connection to QR Server
  String qrServerUrl = "http://192.168.137.1:8000";
  bool _isServerConnected = false;
  String _serverStatus = "Checking...";
  final TextEditingController _serverUrlController = TextEditingController();
  
  // QR Scanner
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  dynamic result;
  dynamic controller;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _checkAdminAccess();
    _loadServerSettings();
    
    // Fetch initial data
    _fetchParkingLots();
    _fetchActiveBookings();
    _fetchParkingHistory();
    
    // Refresh data periodically
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _fetchActiveBookings();
      _fetchParkingHistory();
      _checkServerConnection();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    controller?.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAccess() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _redirectToLogin();
        return;
      }

      // Check if user is admin based on email
      final email = user.email?.toLowerCase() ?? '';
      final isAdmin = email.contains('admin') || email.contains('administrator');

      if (isAdmin) {
        setState(() => _isAdmin = true);
        _loadDashboardStats();
      } else {
        _redirectToLogin();
      }
    } catch (e) {
      print('Error checking admin access: $e');
      _redirectToLogin();
    }
  }

  void _redirectToLogin() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Future<void> _loadDashboardStats() async {
    setState(() => _isLoading = true);
    try {
      // Get total parking lots
      final lotsResponse = await _supabase
          .from('parking_lots')
          .select('id');

      // Get total bookings
      final bookingsResponse = await _supabase
          .from('parking_bookings')
          .select('id');

      // Get total users (excluding admins)
      final usersResponse = await _supabase
          .from('profiles')
          .select('id')
          .neq('role', 'admin');

      setState(() {
        _stats = {
          'totalLots': lotsResponse.length,
          'totalBookings': bookingsResponse.length,
          'totalUsers': usersResponse.length,
        };
      });
    } catch (e) {
      print('Error loading stats: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading stats: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadServerSettings() async {
    // For a real app, you would load this from SharedPreferences or another storage
    // For simplicity, we'll just initialize it here
    _serverUrlController.text = qrServerUrl;
    _checkServerConnection();
  }

  Future<void> _checkServerConnection() async {
    try {
      final response = await http.get(Uri.parse('$qrServerUrl/health'))
          .timeout(const Duration(seconds: 5));
      setState(() {
        _isServerConnected = response.statusCode == 200;
        _serverStatus = _isServerConnected ? "Connected" : "Disconnected";
      });
    } catch (e) {
      setState(() {
        _isServerConnected = false;
        _serverStatus = "Error: ${e.toString().substring(0, min(30, e.toString().length))}...";
      });
    }
  }

  Future<void> _fetchParkingLots() async {
    try {
      final response = await _supabase
          .from('parking_lots')
          .select('id, name, address, total_slots')
          .eq('owner_id', _supabase.auth.currentUser!.id);
      
      setState(() {
        _parkingLots = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading parking lots: $e')),
      );
    }
  }

  Future<void> _fetchActiveBookings() async {
    try {
      final response = await _supabase
          .from('parking_bookings')
          .select('''
            id, 
            booking_time, 
            status, 
            verification_code,
            entry_time,
            exit_time,
            assigned_slot_id,
            user_id,
            parking_id,
            slot_id,
            parking_lots!parking_bookings_parking_id_fkey(id, name),
            profiles!parking_bookings_user_id_fkey(id, name, phone_number),
            user_vehicles!inner(id, vehicle_number, vehicle_type, nickname)
          ''')
          .eq('status', 'active')
          .order('booking_time', ascending: false);
      
      // Get active bookings
      List<Map<String, dynamic>> bookings = List<Map<String, dynamic>>.from(response);
      
      // Debug data structure
      if (bookings.isNotEmpty) {
        print('First booking keys: ${bookings.first.keys.toList()}');
        print('Parking lots data: ${bookings.first['parking_lots']}');
      }
      
      // If there are bookings, fetch the user's vehicles separately
      if (bookings.isNotEmpty) {
        // Extract all user IDs from bookings
        List<String> userIds = bookings
            .where((booking) => booking['user_id'] != null)
            .map<String>((booking) => booking['user_id'].toString())
            .toList();

        if (userIds.isNotEmpty) {
          // Fetch vehicle details for each user
          for (var booking in bookings) {
            if (booking['user_id'] != null) {
              try {
                final vehicleResponse = await _supabase
                    .from('user_vehicles')
                    .select('id, vehicle_number, vehicle_type, nickname')
                    .eq('user_id', booking['user_id'])
                    .maybeSingle();
                    
                if (vehicleResponse != null) {
                  booking['user_vehicles'] = vehicleResponse;
                } else {
                  booking['user_vehicles'] = {
                    'vehicle_number': 'Not Registered',
                    'vehicle_type': 'Not Registered',
                    'nickname': 'Not Registered'
                  };
                }
              } catch (e) {
                print('Error fetching vehicle for user ${booking['user_id']}: $e');
                booking['user_vehicles'] = {
                  'vehicle_number': 'Not Registered',
                  'vehicle_type': 'Not Registered',
                  'nickname': 'Not Registered'
                };
              }
            }
          }
        }
      }
      
      setState(() {
        _activeBookings = bookings;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading active bookings: $e')),
      );
    }
  }

  Future<void> _fetchParkingHistory() async {
    try {
      final response = await _supabase
          .from('parking_bookings')
          .select('''
            id, 
            booking_time, 
            status, 
            entry_time,
            exit_time,
            assigned_slot_id,
            user_id,
            parking_id,
            slot_id,
            total_fee,
            parking_lots!parking_bookings_parking_id_fkey(id, name),
            profiles!parking_bookings_user_id_fkey(id, name, phone_number)
          ''')
          .or('status.eq.completed,status.eq.expired')
          .order('booking_time', ascending: false)
          .limit(20);
      
      List<Map<String, dynamic>> historyBookings = List<Map<String, dynamic>>.from(response);
      
      for (var booking in historyBookings) {
        // VEHICLE
        if (booking['user_id'] != null) {
          try {
            final vehicleResponse = await _supabase
                .from('user_vehicles')
                .select('id, vehicle_number, vehicle_type, nickname')
                .eq('user_id', booking['user_id'])
                .maybeSingle();
            booking['user_vehicles'] = vehicleResponse ??
                {
                  'vehicle_number': 'Not Registered',
                  'vehicle_type': 'Not Registered',
                  'nickname': 'Not Registered'
                };
          } catch (e) {
            booking['user_vehicles'] = {
              'vehicle_number': 'Not Registered',
              'vehicle_type': 'Not Registered',
              'nickname': 'Not Registered'
            };
          }
        }

        // USER PROFILE
        if (booking['profiles!parking_bookings_user_id_fkey'] == null && booking['user_id'] != null) {
          try {
            final userResponse = await _supabase
                .from('profiles')
                .select('name, phone_number')
                .eq('id', booking['user_id'])
                .maybeSingle();
            booking['profiles!parking_bookings_user_id_fkey'] = userResponse ?? {'name': 'Unknown', 'phone_number': ''};
          } catch (e) {
            booking['profiles!parking_bookings_user_id_fkey'] = {'name': 'Unknown', 'phone_number': ''};
          }
        }

        // PARKING LOT
        if (booking['parking_lots!parking_bookings_parking_id_fkey'] == null && booking['parking_id'] != null) {
          try {
            final parkingLotResponse = await _supabase
                .from('parking_lots')
                .select('name')
                .eq('id', booking['parking_id'])
                .maybeSingle();
            booking['parking_lots!parking_bookings_parking_id_fkey'] = parkingLotResponse ?? {'name': 'Unknown'};
          } catch (e) {
            booking['parking_lots!parking_bookings_parking_id_fkey'] = {'name': 'Unknown'};
          }
        }
      }
      
      setState(() {
        _parkingHistory = historyBookings;
      });
    } catch (e) {
      print('Error loading parking history: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading parking history: $e')),
      );
    }
  }

  Future<void> _verifyBookingAndOpenGate(String bookingId) async {
    setState(() {
      _isVerifying = true;
    });
    
    try {
      // First, mark entry time in database
      final now = DateTime.now().toUtc().toIso8601String();
      
      await _supabase
          .from('parking_bookings')
          .update({
            'entry_time': now,
            'status': 'active',
            'is_verified': true
          })
          .eq('id', bookingId);
      
      // Second, send command to ESP32 to open gate
      if (_scannedBooking != null) {
        final parkingLotId = _scannedBooking!['parking_id'];
        final assignedSlotId = _scannedBooking!['assigned_slot_id'];
        final verificationCode = _scannedBooking!['verification_code'];
        
        if (parkingLotId != null && assignedSlotId != null && verificationCode != null) {
          // Format data as ESP32 expects
          final qrData = {
            "booking_id": bookingId,
            "verification_code": verificationCode,
            "slot_number": assignedSlotId,
            "parking_lot_id": parkingLotId
          };
          
          // Show processing feedback
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sending command to server...'),
              duration: Duration(seconds: 1),
            ),
          );
          
          // Try multiple endpoints for backward compatibility
          bool success = false;
          String errorMsg = '';
          
          try {
            // Try the verify_booking endpoint first
            final response = await http.post(
              Uri.parse('$qrServerUrl/verify_booking'),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode(qrData),
            ).timeout(const Duration(seconds: 5));
            
            if (response.statusCode == 200) {
              final result = jsonDecode(response.body);
              success = result['open_gate'] == true;
              errorMsg = result['message'] ?? 'Unknown error';
            } else {
              errorMsg = 'Server returned status code ${response.statusCode}';
            }
          } catch (e) {
            print('First attempt failed: $e');
            errorMsg = 'Connection error: ${e.toString()}';
            
            // Fall back to the process_image endpoint if verify_booking fails
            try {
              // Simulating a basic QR code image verification using multipart
              final request = http.MultipartRequest('POST', Uri.parse('$qrServerUrl/process_image'));
              
              // Add JSON data as a dummy file
              request.files.add(
                http.MultipartFile.fromString(
                  'json_data',
                  jsonEncode(qrData),
                  filename: 'data.json',
                ),
              );
              
              final streamedResponse = await request.send().timeout(const Duration(seconds: 5));
              final response = await http.Response.fromStream(streamedResponse);
              
              if (response.statusCode == 200) {
                final result = jsonDecode(response.body);
                success = result['open_gate'] == true;
                errorMsg = result['message'] ?? 'Unknown error';
              } else {
                errorMsg = 'Server returned status code ${response.statusCode}';
              }
            } catch (e2) {
              print('Second attempt failed: $e2');
              errorMsg = 'All connection attempts failed. Server may be offline.';
            }
          }
          
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Gate opened successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            
            // Refresh the active bookings list
            _fetchActiveBookings();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $errorMsg'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification error: $e')),
      );
    } finally {
      setState(() {
        _isVerifying = false;
        _scannedBooking = null; // Reset after verification
      });
    }
  }

  Future<void> _markVehicleExit(String bookingId) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      
      await _supabase
          .from('parking_bookings')
          .update({
            'exit_time': now,
            'status': 'completed',
          })
          .eq('id', bookingId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vehicle exit marked successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Refresh the lists
      _fetchActiveBookings();
      _fetchParkingHistory();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking exit: $e')),
      );
    }
  }

  void _processScannedQR(String qrData) {
    try {
      // Parse the QR data
      final bookingData = jsonDecode(qrData);
      
      if (bookingData is Map<String, dynamic> && 
          bookingData.containsKey('booking_id') && 
          bookingData.containsKey('verification_code')) {
        
        // Look up the booking in our active bookings
        final matchedBooking = _activeBookings.firstWhere(
          (booking) => booking['id'] == bookingData['booking_id'],
          orElse: () => <String, dynamic>{},
        );
        
        if (matchedBooking.isNotEmpty) {
          setState(() {
            _scannedBooking = {
              ...matchedBooking,
              'verification_code': bookingData['verification_code'],
            };
          });
          
          // Show the verification dialog
          _showVerificationDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No active booking found for this QR code'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        throw FormatException('Invalid QR code format');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing QR code: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showVerificationDialog() {
    if (_scannedBooking == null) return;
    
    // Ensure we have vehicle data
    final vehicleData = _scannedBooking!['user_vehicles'] ?? {
      'vehicle_number': 'Not Registered',
      'vehicle_type': 'Not Registered',
      'nickname': 'Not Registered'
    };
    
    // Get parking lot name
    String parkingLotName = "Unknown";
    if (_scannedBooking!.containsKey('parking_lots!parking_bookings_parking_id_fkey')) {
      parkingLotName = _scannedBooking!['parking_lots!parking_bookings_parking_id_fkey']['name'] ?? "Unknown";
    } else if (_scannedBooking!.containsKey('parking_lots')) {
      parkingLotName = _scannedBooking!['parking_lots']['name'] ?? "Unknown";
    }
    
    // Get user name
    String userName = "Unknown";
    if (_scannedBooking!.containsKey('profiles!parking_bookings_user_id_fkey')) {
      userName = _scannedBooking!['profiles!parking_bookings_user_id_fkey']['name'] ?? "Unknown";
    } else if (_scannedBooking!.containsKey('profiles')) {
      userName = _scannedBooking!['profiles']['name'] ?? "Unknown";
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Booking'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer: $userName'),
              const SizedBox(height: 4),
              Text('Vehicle: ${vehicleData['vehicle_type']} ${vehicleData['nickname']}'),
              const SizedBox(height: 4),
              Text('License Plate: ${vehicleData['vehicle_number']}'),
              const SizedBox(height: 4),
              Text('Slot ID: ${_scannedBooking!['assigned_slot_id']}'),
              const SizedBox(height: 4),
              Text('Parking Lot: $parkingLotName'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isVerifying 
                ? null 
                : () {
                    Navigator.pop(context);
                    _verifyBookingAndOpenGate(_scannedBooking!['id']);
                  },
            child: _isVerifying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Verify & Open Gate'),
          ),
        ],
      ),
    );
  }

  void _showServerConfigDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Server Configuration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _serverUrlController,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'e.g., http://192.168.1.10:8000',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Common server addresses:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildServerOption('Local PC', 'http://localhost:8000'),
            _buildServerOption('Hotspot IP', 'http://192.168.137.1:8000'),
            _buildServerOption('Local Network', 'http://192.168.1.100:8000'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newUrl = _serverUrlController.text.trim();
              if (newUrl.isNotEmpty) {
                setState(() {
                  qrServerUrl = newUrl;
                });
                _checkServerConnection();
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildServerOption(String label, String url) {
    return InkWell(
      onTap: () {
        _serverUrlController.text = url;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(label),
            const Spacer(),
            Text(
              url,
              style: const TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _simulateGateOpen() async {
    if (_activeBookings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active bookings to test with'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final booking = _activeBookings.first;
    setState(() {
      _scannedBooking = booking;
    });
    _showVerificationDialog();
  }

  int min(int a, int b) {
    return a < b ? a : b;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.api),
            tooltip: 'Test API Directly',
            onPressed: _testDirectVerification,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardStats,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _supabase.auth.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Active Bookings'),
            Tab(text: 'History'),
            Tab(text: 'Slot Management'),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Admin Panel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Smart Parking System',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.add_location),
              title: const Text('Register Parking Lot'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EnhancedParkingLotRegistration(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code),
              title: const Text('Generate QR Codes'),
              onTap: () {
                Navigator.pop(context);
                _showQRGenerationOptions();
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Analytics & Slot Management'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminAnalyticsScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await _supabase.auth.signOut();
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildActiveBookingsTab(),
                _buildHistoryTab(),
                _buildSlotManagementTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQRScannerDialog(),
        child: const Icon(Icons.qr_code_scanner),
      ),
    );
  }

  Widget _buildOverviewTab() {
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                        'Server Status',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: _showServerConfigDialog,
                        tooltip: 'Configure Server',
                      ),
                    ],
                    ),
                    const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        _isServerConnected ? Icons.check_circle : Icons.error,
                        color: _isServerConnected ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_serverStatus)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Server URL: $qrServerUrl'),
                  const SizedBox(height: 16),
                  Row(
                      children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _checkServerConnection,
                          child: const Text('Refresh Connection'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isServerConnected ? _simulateGateOpen : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Test Gate Open'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your Parking Lots',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _parkingLots.isEmpty
              ? const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No parking lots registered yet.'),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _parkingLots.length,
                  itemBuilder: (context, index) {
                    final lot = _parkingLots[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      child: ListTile(
                        title: Text(lot['name']),
                        subtitle: Text(lot['address']),
                        trailing: Text('${lot['total_slots']} slots'),
                      ),
                    );
                  },
                ),
          const SizedBox(height: 16),
          const Text(
            'Current Status',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatusItem(
                    Icons.local_parking,
                    'Active Bookings',
                    _activeBookings.length.toString(),
                    Colors.blue,
                  ),
                  _buildStatusItem(
                    Icons.history,
                    'Recent Activity',
                    _parkingHistory.length.toString(),
                          Colors.orange,
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey[700]),
        ),
      ],
    );
  }

  Widget _buildActiveBookingsTab() {
    return _activeBookings.isEmpty
        ? const Center(child: Text('No active bookings found.'))
        : ListView.builder(
            itemCount: _activeBookings.length,
            itemBuilder: (context, index) {
              final booking = _activeBookings[index];
              final entryTime = booking['entry_time'] != null
                  ? DateFormat('MMM d, h:mm a').format(
                      DateTime.parse(booking['entry_time']).toLocal())
                  : 'Not entered yet';
              
              // Get vehicle data safely (already fetched)
              final vehicleData = booking['user_vehicles'] ?? {
                'vehicle_number': 'Not Registered',
                'vehicle_type': 'Not Registered',
                'nickname': 'Not Registered'
              };
              
              // Get parking lot data safely (already fetched)
              String parkingLotName = "Unknown";
              if (booking.containsKey('parking_lots!parking_bookings_parking_id_fkey') && booking['parking_lots!parking_bookings_parking_id_fkey'] != null) {
                parkingLotName = booking['parking_lots!parking_bookings_parking_id_fkey']['name'] ?? "Unknown";
              }
              
              // Get user name (already fetched)
              String userName = "Unknown";
              if (booking.containsKey('profiles!parking_bookings_user_id_fkey') && booking['profiles!parking_bookings_user_id_fkey'] != null) {
                userName = booking['profiles!parking_bookings_user_id_fkey']['name'] ?? "Unknown";
              }
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            vehicleData['vehicle_number'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: booking['entry_time'] != null
                                  ? Colors.green
                                  : Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              booking['entry_time'] != null ? 'Inside' : 'Expected',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${vehicleData['vehicle_type']} ${vehicleData['nickname']}',
                      ),
                      const SizedBox(height: 4),
                      Text('Customer: $userName'),
                      const SizedBox(height: 4),
                      Text('Slot ID: ${booking['assigned_slot_id']}'),
                      const SizedBox(height: 4),
                      Text('Parking: $parkingLotName'),
                      const SizedBox(height: 4),
                      Text('Entry Time: $entryTime'),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          booking['entry_time'] != null
                              ? ElevatedButton.icon(
                                  icon: const Icon(Icons.exit_to_app),
                                  label: const Text('Mark Exit'),
                                  onPressed: () => _markVehicleExit(booking['id']),
                                )
                              : ElevatedButton.icon(
                                  icon: const Icon(Icons.login),
                                  label: const Text('Verify Entry'),
                                  onPressed: () {
                                    setState(() {
                                      _scannedBooking = booking;
                                    });
                                    _showVerificationDialog();
                                  },
                                ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  Widget _buildHistoryTab() {
    final validHistory = _parkingHistory.where((booking) =>
      booking['user_vehicles'] != null &&
      booking['profiles!parking_bookings_user_id_fkey'] != null &&
      booking['parking_lots!parking_bookings_parking_id_fkey'] != null
    ).toList();

    return validHistory.isEmpty
        ? const Center(child: Text('No parking history found.'))
        : ListView.builder(
            itemCount: validHistory.length,
            itemBuilder: (context, index) {
              final booking = validHistory[index];
              final entryTime = booking['entry_time'] != null
                  ? DateFormat('MMM d, h:mm a').format(
                      DateTime.parse(booking['entry_time']).toLocal())
                  : 'N/A';
              final exitTime = booking['exit_time'] != null
                  ? DateFormat('MMM d, h:mm a').format(
                      DateTime.parse(booking['exit_time']).toLocal())
                  : 'N/A';
              final fee = booking['total_fee'] != null
                  ? '₹${booking['total_fee'].toStringAsFixed(2)}'
                  : 'N/A';
              
              // Get vehicle data safely (already fetched)
              final vehicleData = booking['user_vehicles'] ?? {
                'vehicle_number': 'No vehicle info',
                'vehicle_type': '',
                'nickname': ''
              };
              
              // Get parking lot data safely (already fetched)
              String parkingLotName = booking['parking_lots!parking_bookings_parking_id_fkey']?['name'] ?? 'Unknown';
              
              // Get user name (already fetched)
              String userName = booking['profiles!parking_bookings_user_id_fkey']?['name'] ?? 'Unknown';
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            vehicleData['vehicle_number'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: booking['status'] == 'completed'
                                  ? Colors.green
                                  : Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              booking['status'].toString().toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${vehicleData['vehicle_type']} ${vehicleData['nickname']}'),
                      const SizedBox(height: 4),
                      Text('Customer: $userName'),
                      const SizedBox(height: 4),
                      Text('Slot ID: ${booking['assigned_slot_id']}'),
                      const SizedBox(height: 4),
                      Text('Parking: $parkingLotName'),
                      const SizedBox(height: 4),
                      Text('Entry Time: $entryTime'),
                      const SizedBox(height: 4),
                      Text('Exit Time: $exitTime'),
                      const SizedBox(height: 4),
                      Text('Total Fee: $fee'),
                    ],
                  ),
                ),
              );
            },
          );
  }

  Widget _buildSlotManagementTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Slot Management',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          // Section for expiring inactive bookings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Expire Inactive Bookings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'This will find all pending bookings that are older than 5 minutes and mark them as expired, freeing up the slots.',
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _expireInactiveBookings,
                    icon: const Icon(Icons.timer_off),
                    label: const Text('Expire Inactive Bookings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Section for freeing up occupied slots
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Free Up Slots',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'This will reset all slots to available status. Use with caution!',
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _freeUpAllSlots,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset All Slots'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Section for viewing slot status by parking lot
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Slot Status by Parking Lot',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _fetchParkingLotsWithSlots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      }
                      
                      final parkingLots = snapshot.data ?? [];
                      
                      if (parkingLots.isEmpty) {
                        return const Text('No parking lots found');
                      }
                      
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: parkingLots.length,
                        itemBuilder: (context, index) {
                          final lot = parkingLots[index];
                          final slots = List<Map<String, dynamic>>.from(lot['slots'] ?? []);
                          
                          return ExpansionTile(
                            title: Text(lot['name'] ?? 'Unknown Lot'),
                            subtitle: Text('${slots.length} slots'),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: slots.map((slot) {
                                    final isAvailable = slot['is_available'] ?? false;
                                    return InkWell(
                                      onTap: () => _toggleSlotAvailability(slot['id']),
                                      child: Chip(
                                        label: Text('Slot ${slot['slot_number']}'),
                                        backgroundColor: isAvailable
                                            ? Colors.green.withOpacity(0.2)
                                            : Colors.red.withOpacity(0.2),
                                        labelStyle: TextStyle(
                                          color: isAvailable ? Colors.green : Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _expireInactiveBookings() async {
    try {
      setState(() => _isLoading = true);
      
      // Get current time
      final now = DateTime.now().toUtc();
      
      // Calculate cutoff time (5 minutes ago)
      final cutoffTime = now.subtract(const Duration(minutes: 5));
      final cutoffTimeStr = cutoffTime.toIso8601String();
      
      // Find pending bookings older than 5 minutes
      final expiredBookings = await _supabase
          .from('parking_bookings')
          .select('id, assigned_slot_id, slot_id')
          .eq('status', 'pending')
          .eq('is_verified', false)
          .lte('created_at', cutoffTimeStr);
      
      int expiredCount = 0;
      
      // Process each expired booking
      for (var booking in expiredBookings) {
        // Update booking status
        await _supabase
            .from('parking_bookings')
            .update({
              'status': 'expired',
              'updated_at': now.toIso8601String()
            })
            .eq('id', booking['id']);
        
        // Free up the assigned slot
        final slotId = booking['slot_id'] ?? booking['assigned_slot_id'];
        if (slotId != null) {
          await _supabase
              .from('parking_slots')
              .update({'is_available': true})
              .eq('id', slotId);
        }
        
        expiredCount++;
      }
      
      // Refresh data
      _fetchActiveBookings();
      _fetchParkingHistory();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$expiredCount inactive bookings expired'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _freeUpAllSlots() async {
    try {
      setState(() => _isLoading = true);
      
      // Confirm action with dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Warning'),
          content: const Text(
            'This will reset ALL slots to available status, even those that might be currently occupied. Are you sure?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes, Reset All'),
            ),
          ],
        ),
      );
      
      if (confirm != true) return;
      
      // Update all slots to available
      await _supabase
          .from('parking_slots')
          .update({'is_available': true});
      
      // Refresh data
      _fetchActiveBookings();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All slots have been reset to available'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _toggleSlotAvailability(String slotId) async {
    try {
      setState(() => _isLoading = true);
      
      // Get current slot status
      final slotResponse = await _supabase
          .from('parking_slots')
          .select('is_available')
          .eq('id', slotId)
          .single();
      
      final isCurrentlyAvailable = slotResponse['is_available'] ?? false;
      
      // Toggle availability
      await _supabase
          .from('parking_slots')
          .update({'is_available': !isCurrentlyAvailable})
          .eq('id', slotId);
      
      // Refresh data
      _fetchActiveBookings();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Slot is now ${!isCurrentlyAvailable ? 'available' : 'unavailable'}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<List<Map<String, dynamic>>> _fetchParkingLotsWithSlots() async {
    try {
      final response = await _supabase
          .from('parking_lots')
          .select('id, name, parking_slots(*)');
      
      final List<Map<String, dynamic>> parkingLots = [];
      
      for (var lot in response) {
        parkingLots.add({
          'id': lot['id'],
          'name': lot['name'],
          'slots': lot['parking_slots'],
        });
      }
      
      return parkingLots;
    } catch (e) {
      print('Error fetching parking lots with slots: $e');
      return [];
    }
  }

  void _showQRScannerDialog() {
    // For desktop platforms, show a dummy dialog instead
    if (kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('QR Scanner not supported'),
          content: const Text(
            'QR scanning is not supported on this platform. Please use a mobile device to scan QR codes.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // For testing purposes, simulate a scanned QR code
                if (_activeBookings.isNotEmpty) {
                  final booking = _activeBookings.first;
                  final testQrData = {
                    "booking_id": booking['id'],
                    "verification_code": booking['verification_code'],
                  };
                  _processScannedQR(jsonEncode(testQrData));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No active bookings to test with'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              child: const Text('SIMULATE SCAN'),
            ),
          ],
        ),
      );
      return;
    }

    // For mobile platforms, show the QR scanner dialog
    // This will only be executed on mobile platforms where QR scanner works
    try {
      showDialog(
        context: context,
        builder: (dialogContext) => Dialog(
          child: SizedBox(
            height: 400,
            width: 300,
            child: Column(
              children: [
                Expanded(
                  flex: 4,
                  child: QRView(
                    key: qrKey,
                    onQRViewCreated: (controller) {
                      this.controller = controller;
                      controller.scannedDataStream.listen((scanData) {
                        if (scanData.code != null) {
                          Navigator.pop(dialogContext);
                          _processScannedQR(scanData.code!);
                        }
                      });
                    },
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      // If QR scanner fails for any reason, show the simulation dialog instead
      print('Error initializing QR scanner: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('QR scanner error: ${e.toString().split('\n')[0]}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _testDirectVerification() async {
    if (_activeBookings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active bookings to test with'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Try to reach the server directly first
    try {
      final response = await http.get(
        Uri.parse('$qrServerUrl/health'),
        headers: {"Content-Type": "application/json"},
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server health check failed: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server unreachable: $e'),
          backgroundColor: Colors.red,
        ),
      );
      _showServerConfigDialog();
      return;
    }
    
    // Mark first booking as entered
    final booking = _activeBookings.first;
    
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _supabase
          .from('parking_bookings')
          .update({
            'entry_time': now,
            'status': 'active',
            'is_verified': true
          })
          .eq('id', booking['id']);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Database updated! Gate operation simulated.'),
          backgroundColor: Colors.green,
        ),
      );
      
      _fetchActiveBookings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Database error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showQRGenerationOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate QR Codes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
            children: [
            ListTile(
              leading: const Icon(Icons.qr_code),
              title: const Text('Booking Verification QR'),
              subtitle: const Text('Generate QR codes for specific bookings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/admin/generate-qr');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.local_parking),
              title: const Text('Parking Lot & Slot QR'),
              subtitle: const Text('Generate QR codes for parking lots and slots'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/admin/parking-qr-generator');
              },
              ),
            ],
          ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
        ),
        ],
      ),
    );
  }
}
