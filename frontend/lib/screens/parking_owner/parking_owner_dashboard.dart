import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../widgets/custom_button.dart';

class ParkingOwnerDashboard extends StatefulWidget {
  const ParkingOwnerDashboard({super.key});

  @override
  State<ParkingOwnerDashboard> createState() => _ParkingOwnerDashboardState();
}

class _ParkingOwnerDashboardState extends State<ParkingOwnerDashboard> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  bool _isLoading = false;
  List<Map<String, dynamic>> _parkingLots = [];
  List<Map<String, dynamic>> _activeBookings = [];
  Map<String, dynamic> _analytics = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _fetchParkingLots(),
        _fetchActiveBookings(),
        _fetchAnalytics(),
      ]);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchParkingLots() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('parking_lots')
          .select('id, name, address, total_slots, latitude, longitude, created_at')
          .eq('owner_id', user.id);

      setState(() {
        _parkingLots = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _fetchActiveBookings() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // First, get all parking lots owned by this user
      final parkingLotIds = _parkingLots.map((lot) => lot['id']).toList();
      if (parkingLotIds.isEmpty) return;

      // Then fetch active bookings for these parking lots
      final response = await _supabase
          .from('parking_bookings')
          .select('''
            id, 
            booking_time, 
            status, 
            verification_code,
            entry_time,
            exit_time,
            total_fee,
            assigned_slot_id,
            profiles!parking_bookings_user_id_fkey(id, name, phone_number),
            parking_slots(id, slot_number, vehicle_type),
            parking_lots!parking_bookings_parking_id_fkey(id, name)
          ''')
          .inFilter('parking_id', parkingLotIds)
          .eq('status', 'active')
          .order('booking_time', ascending: false);

      setState(() {
        _activeBookings = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _fetchAnalytics() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Get all parking lots owned by this user
      final parkingLotIds = _parkingLots.map((lot) => lot['id']).toList();
      if (parkingLotIds.isEmpty) return;

      // Get today's date in UTC
      final today = DateTime.now().toUtc();
      final startOfToday = DateTime.utc(today.year, today.month, today.day).toIso8601String();
      
      // Get total revenue, active bookings, and completed bookings
      final revenueResponse = await _supabase
          .from('parking_bookings')
          .select('total_fee')
          .inFilter('parking_id', parkingLotIds)
          .eq('status', 'completed');
      
      final todayBookingsResponse = await _supabase
          .from('parking_bookings')
          .select('id, status')
          .inFilter('parking_id', parkingLotIds)
          .gte('booking_time', startOfToday);
      
      // Calculate analytics
      double totalRevenue = 0;
      for (var booking in revenueResponse) {
        totalRevenue += (booking['total_fee'] as num? ?? 0).toDouble();
      }
      
      final todayBookings = List<Map<String, dynamic>>.from(todayBookingsResponse);
      final todayCount = todayBookings.length;
      final activeCount = _activeBookings.length;
      final completedCount = todayBookings.where((b) => b['status'] == 'completed').length;
      
      setState(() {
        _analytics = {
          'totalRevenue': totalRevenue,
          'todayBookings': todayCount,
          'activeBookings': activeCount,
          'completedBookings': completedCount,
        };
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _markVehicleExit(String bookingId) async {
    try {
      setState(() => _isLoading = true);
      
      final now = DateTime.now().toUtc().toIso8601String();
      
      await _supabase
          .from('parking_bookings')
          .update({
            'exit_time': now,
            'status': 'completed',
          })
          .eq('id', bookingId);
      
      // Refresh data
      await _loadData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vehicle exit marked successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking exit: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parking Owner Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
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
            Tab(text: 'My Parking Lots'),
            Tab(text: 'Active Bookings'),
            Tab(text: 'Analytics'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildParkingLotsTab(),
                _buildActiveBookingsTab(),
                _buildAnalyticsTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddParkingSlotDialog();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildParkingLotsTab() {
    return _parkingLots.isEmpty
        ? const Center(child: Text('No parking lots found'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _parkingLots.length,
            itemBuilder: (context, index) {
              final lot = _parkingLots[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  title: Text(lot['name'] ?? 'Unnamed Lot'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lot['address'] ?? 'No address'),
                      const SizedBox(height: 4),
                      Text('Total slots: ${lot['total_slots'] ?? 0}'),
                      const SizedBox(height: 4),
                      Text('Created: ${DateFormat('MMM d, yyyy').format(DateTime.parse(lot['created_at']))}'),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showEditParkingLotDialog(lot),
                  ),
                  onTap: () => _navigateToParkingLotDetails(lot['id']),
                ),
              );
            },
          );
  }

  void _navigateToParkingLotDetails(String lotId) {
    // Navigate to details page
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon: Detailed view')),
    );
  }

  Widget _buildActiveBookingsTab() {
    return _activeBookings.isEmpty
        ? const Center(child: Text('No active bookings found'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _activeBookings.length,
            itemBuilder: (context, index) {
              final booking = _activeBookings[index];
              
              // Extract nested data safely
              final userName = booking['profiles']?['name'] ?? 'Unknown';
              final phoneNumber = booking['profiles']?['phone_number'] ?? 'N/A';
              final parkingName = booking['parking_lots']?['name'] ?? 'Unknown';
              final slot = booking['parking_slots'] ?? {'slot_number': 'Unknown', 'vehicle_type': 'Unknown'};
              
              // Format times
              final bookingTime = DateFormat('MMM d, h:mm a').format(
                DateTime.parse(booking['booking_time']).toLocal());
              final entryTime = booking['entry_time'] != null
                  ? DateFormat('h:mm a').format(DateTime.parse(booking['entry_time']).toLocal())
                  : 'Not yet';
              
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Booking #${booking['id'].toString().substring(0, 8)}...',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'ACTIVE',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Customer: $userName'),
                      Text('Phone: $phoneNumber'),
                      const SizedBox(height: 8),
                      Text('Parking: $parkingName'),
                      Text('Slot: ${slot['slot_number']} (${slot['vehicle_type']})'),
                      const SizedBox(height: 8),
                      Text('Booked: $bookingTime'),
                      Text('Entry: $entryTime'),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.exit_to_app),
                          label: const Text('Mark Exit'),
                          onPressed: () => _markVehicleExit(booking['id']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  Widget _buildAnalyticsTab() {
    final revenue = _analytics['totalRevenue'] ?? 0.0;
    final todayBookings = _analytics['todayBookings'] ?? 0;
    final activeBookings = _analytics['activeBookings'] ?? 0;
    final completedBookings = _analytics['completedBookings'] ?? 0;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analytics Overview',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsCard(
                  title: 'Total Revenue',
                  value: '₹${revenue.toStringAsFixed(2)}',
                  icon: Icons.attach_money,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAnalyticsCard(
                  title: 'Today\'s Bookings',
                  value: todayBookings.toString(),
                  icon: Icons.today,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsCard(
                  title: 'Active Bookings',
                  value: activeBookings.toString(),
                  icon: Icons.local_parking,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAnalyticsCard(
                  title: 'Completed Today',
                  value: completedBookings.toString(),
                  icon: Icons.check_circle,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Parking Lots Summary',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _parkingLots.isEmpty
              ? const Center(child: Text('No parking lots found'))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _parkingLots.length,
                  itemBuilder: (context, index) {
                    final lot = _parkingLots[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(lot['name']),
                        subtitle: Text('${lot['total_slots']} slots'),
                        trailing: IconButton(
                          icon: const Icon(Icons.analytics),
                          onPressed: () => _showLotAnalytics(lot['id']),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLotAnalytics(String lotId) {
    // Show detailed analytics for a specific lot
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon: Detailed analytics')),
    );
  }

  void _showEditParkingLotDialog(Map<String, dynamic> lot) {
    // Show dialog to edit parking lot details
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon: Edit parking lot')),
    );
  }

  void _showAddParkingSlotDialog() {
    // Show dialog to add parking slots
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon: Add parking slots')),
    );
  }
} 