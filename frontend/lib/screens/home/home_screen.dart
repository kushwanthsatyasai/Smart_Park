import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../booking/map_screen.dart';
import '../booking/booking_history_screen.dart';
import '../profile/complete_profile_screen.dart';
import '../scanner_screen.dart';
import '../booking/booking_confirmation_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/profile_service.dart';
import '../profile/profile_completion_screen.dart';
import '../../widgets/vehicle_selector.dart';
import 'package:provider/provider.dart';
import '../../providers/vehicle_provider.dart';

const Color primaryBlue = Color(0xFF1A73E8);
const Color secondaryBlue = Color(0xFF4285F4);
const Color lightBlue = Color(0xFFE8F0FE);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final supabase = Supabase.instance.client;
  String? userName;
  bool isLoading = true;
  bool isAdmin = false;
  Map<String, dynamic>? _activeBooking;
  final _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadActiveBooking();
    _checkProfileCompletion();
    // Load default vehicle
    Provider.of<VehicleProvider>(context, listen: false).loadDefaultVehicle();
  }

  Future<void> _loadUserData() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw 'User not authenticated';
      }

      final userData =
          await supabase.from('profiles').select().eq('id', userId).single();

      if (mounted) {
        setState(() {
          userName = userData['full_name'] ?? 'User';
          isAdmin = userData['is_admin'] ?? false;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          userName = 'User';
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadActiveBooking() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('parking_bookings')
          .select('''
            *,
            parking_lots!parking_bookings_parking_id_fkey (*),
            parking_slots!parking_bookings_slot_id_fkey (*)
          ''')
          .eq('user_id', userId)
          .or('status.eq.pending,status.eq.active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      print('Active booking response: $response'); // Debug print

      if (mounted) {
        setState(() {
          _activeBooking = response;
        });
      }
    } catch (e) {
      print('Error loading active booking: $e');
    }
  }

  Future<void> _signOut() async {
    try {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  void _navigateToMap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MapScreen()),
    );
  }

  void _navigateToScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );
  }

  void _navigateToBookingHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BookingHistoryScreen()),
    );
  }

  void _navigateToProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      try {
        final profile =
            await supabase.from('profiles').select().eq('id', userId).single();

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CompleteProfileScreen(
                userId: userId,
                existingProfile: profile,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CompleteProfileScreen(
                userId: userId,
                existingProfile: null,
              ),
            ),
          );
        }
      }
    }
  }

  void _navigateToActiveBooking() async {
    try {
      if (_activeBooking == null) {
        await _loadActiveBooking();
      }

      if (_activeBooking != null) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookingConfirmationScreen(
                bookingDetails: _activeBooking!,
                parkingLot: _activeBooking!['parking_lots'],
                assignedSlot: _activeBooking!['parking_slots'],
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No active booking found'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('Error navigating to active booking: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkProfileCompletion() async {
    final profile = await _profileService.getUserProfile();
    final isComplete = await _profileService.isProfileComplete();

    if (!isComplete && mounted) {
      // Show profile completion screen
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false, // Prevent back button
          child: Dialog(
            child: ProfileCompletionScreen(
              existingProfile: profile,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleProvider = Provider.of<VehicleProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Parking'),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          if (!isLoading) VehicleSelector(
            onVehicleSelected: (vehicle) {
              final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
              vehicleProvider.setSelectedVehicle(vehicle);
            },
            initialVehicle: vehicleProvider.selectedVehicle,
            isCompact: true,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadActiveBooking();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Welcome, $userName!',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    _buildActiveBookingCard(),
                    const SizedBox(height: 24),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: [
                        _buildFeatureCard(
                          context,
                          'Find Parking',
                          Icons.location_on,
                          _navigateToMap,
                          Colors.blue,
                        ),
                        _buildFeatureCard(
                          context,
                          'Scan QR',
                          Icons.qr_code_scanner,
                          _navigateToScanner,
                          Colors.green,
                        ),
                        _buildFeatureCard(
                          context,
                          'Booking History',
                          Icons.history,
                          _navigateToBookingHistory,
                          Colors.orange,
                        ),
                        _buildFeatureCard(
                          context,
                          'Profile',
                          Icons.person,
                          _navigateToProfile,
                          Colors.purple,
                        ),
                      ],
                    ),
                    if (isAdmin) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Admin Features',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        children: [
                          _buildFeatureCard(
                            context,
                            'Dashboard',
                            Icons.dashboard,
                            () =>
                                Navigator.pushNamed(context, '/admin/dashboard'),
                            Colors.red,
                          ),
                          _buildFeatureCard(
                            context,
                            'Register Parking',
                            Icons.local_parking,
                            () => Navigator.pushNamed(
                                context, '/admin/register-parking'),
                            Colors.teal,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildActiveBookingCard() {
    if (_activeBooking == null) {
      return const SizedBox.shrink();
    }

    final parkingLot = _activeBooking!['parking_lots'];
    final slot = _activeBooking!['parking_slots'];
    
    if (parkingLot == null || slot == null) {
      print('Invalid booking data: ${_activeBooking!}');
      return const SizedBox.shrink();
    }

    final isEntry = _activeBooking!['entry_time'] == null;
    final isExit = _activeBooking!['entry_time'] != null && 
                   _activeBooking!['exit_time'] == null;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Active Booking',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(parkingLot['name'] ?? 'Unknown Location'),
                Text('Slot: ${slot['slot_number']}'),
                Text('Status: ${_activeBooking!['status']?.toUpperCase() ?? 'UNKNOWN'}'),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isEntry ? Colors.orange : (isExit ? Colors.green : Colors.blue),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isEntry ? 'PENDING ENTRY' : (isExit ? 'PENDING EXIT' : 'ACTIVE'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookingConfirmationScreen(
                          bookingDetails: _activeBooking!,
                          parkingLot: parkingLot,
                          assignedSlot: slot,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Show QR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                if (parkingLot['latitude'] != null && parkingLot['longitude'] != null)
                  ElevatedButton.icon(
                    onPressed: () async {
                      final url = 'https://www.google.com/maps/dir/?api=1&destination=${parkingLot['latitude']},${parkingLot['longitude']}';
                      if (await canLaunch(url)) {
                        await launch(url);
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not open directions')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text('Navigate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, String title, IconData icon,
      VoidCallback onTap, Color color) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.7),
                color,
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 40,
                color: Colors.white,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
