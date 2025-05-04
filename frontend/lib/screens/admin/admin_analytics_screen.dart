import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String _selectedTimeFilter = 'today';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  List<Map<String, dynamic>> _parkingLots = [];
  Map<String, dynamic> _analytics = {};
  List<Map<String, dynamic>> _slotStatus = [];
  
  // Search controllers
  final _slotSearchController = TextEditingController();
  final _vehicleSearchController = TextEditingController();
  Map<String, dynamic>? _slotSearchResult;
  List<Map<String, dynamic>> _vehicleSearchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  @override
  void dispose() {
    _slotSearchController.dispose();
    _vehicleSearchController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAccess() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _redirectToLogin();
        return;
      }

      final profile = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null || profile['role'] != 'admin') {
        _redirectToLogin();
        return;
      }

      _loadData();
    } catch (e) {
      print('Error checking admin access: $e');
      _redirectToLogin();
    }
  }

  void _redirectToLogin() {
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadParkingLots(),
        _loadAnalytics(),
        _loadSlotStatus(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadParkingLots() async {
    final response = await _supabase
        .from('parking_lots')
        .select('*, parking_slots(*)');
    setState(() {
      _parkingLots = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      DateTime now = DateTime.now();
      DateTime start;
      DateTime end;

      if (_selectedTimeFilter == 'today') {
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (_selectedTimeFilter == 'yesterday') {
        final yesterday = now.subtract(const Duration(days: 1));
        start = DateTime(yesterday.year, yesterday.month, yesterday.day);
        end = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
      } else if (_selectedTimeFilter == 'week') {
        final weekAgo = now.subtract(const Duration(days: 6));
        start = DateTime(weekAgo.year, weekAgo.month, weekAgo.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (_selectedTimeFilter == 'month') {
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (_selectedTimeFilter == 'year') {
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year, 12, 31, 23, 59, 59);
      } else if (_selectedTimeFilter == 'custom') {
        start = DateTime(_startDate.year, _startDate.month, _startDate.day);
        end = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
      } else {
        // Default to today
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      }

      final startStr = start.toIso8601String();
      final endStr = end.toIso8601String();

      // Fetch bookings in the selected range
      final bookingsResponse = await supabase
          .from('parking_bookings')
          .select('*, parking_lots!parking_bookings_parking_id_fkey (*)')
          .gte('created_at', startStr)
          .lte('created_at', endStr);

      final filteredBookingsCount = bookingsResponse.length;
      double filteredRevenue = 0;
      for (var booking in bookingsResponse) {
        if (booking['total_fee'] != null) {
          filteredRevenue += (booking['total_fee'] as num).toDouble();
        }
      }
      final filteredActiveBookings = bookingsResponse.where((booking) =>
        ['pending', 'active'].contains(booking['status'])).length;

      // Fetch all-time (lifetime) revenue and bookings
      final allBookings = await supabase
          .from('parking_bookings')
          .select('total_fee');
      double lifetimeRevenue = 0;
      for (var booking in allBookings) {
        if (booking['total_fee'] != null) {
          lifetimeRevenue += (booking['total_fee'] as num).toDouble();
        }
      }
      final allTimeBookingsCount = allBookings.length;

      if (mounted) {
        setState(() {
          _analytics = {
            'lifetime_earnings': lifetimeRevenue,
            'all_time_bookings': allTimeBookingsCount,
            'filtered_revenue': filteredRevenue,
            'filtered_bookings': filteredBookingsCount,
            'filtered_active_bookings': filteredActiveBookings,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading analytics: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading analytics: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadSlotStatus() async {
    final response = await _supabase
        .from('parking_slots')
        .select('*, parking_lots(*)');
    
    setState(() {
      _slotStatus = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<void> _updateDynamicPricing(String lotId) async {
    try {
      final bookings = _analytics['bookings_by_lot'][lotId] ?? 0;
      final baseRate = _parkingLots
          .firstWhere((lot) => lot['id'] == lotId)['base_rate_per_hour'];
      
      // Calculate dynamic rate based on bookings
      double dynamicRate = baseRate;
      if (bookings > 10) {
        dynamicRate = baseRate * 1.2; // 20% increase
      } else if (bookings > 5) {
        dynamicRate = baseRate * 1.1; // 10% increase
      }

      // Update parking lot rate
      await _supabase
          .from('parking_lots')
          .update({'rate_per_hour': dynamicRate})
          .eq('id', lotId);

      // Refresh data
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating pricing: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _searchBySlot(String slotNumber) async {
    if (slotNumber.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      final response = await _supabase
          .from('parking_bookings')
          .select('''
            *,
            parking_slots (
              slot_number,
              parking_lots (
                name
              )
            ),
            profiles (
              full_name,
              phone_number,
              aadhaar_number
            )
          ''')
          .eq('parking_slots.slot_number', slotNumber)
          .order('booking_time', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        setState(() {
          _slotSearchResult = response.first;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No booking found for this slot')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _searchByVehicle(String vehicleNumber) async {
    if (vehicleNumber.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      final response = await _supabase
          .from('parking_bookings')
          .select('''
            *,
            parking_slots (
              slot_number,
              parking_lots (
                name
              )
            ),
            profiles (
              full_name,
              phone_number,
              aadhaar_number
            )
          ''')
          .eq('vehicle_number', vehicleNumber)
          .order('booking_time', ascending: false);

      setState(() {
        _vehicleSearchResults = List<Map<String, dynamic>>.from(response);
      });

      if (_vehicleSearchResults.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No bookings found for this vehicle')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _calculateCustomDateRange() async {
    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date cannot be before start date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      // Format dates for queries
      final startDateStr = DateTime(_startDate.year, _startDate.month, _startDate.day).toIso8601String();
      final endDateStr = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59).toIso8601String();
      
      // Get bookings in the date range
      final bookingsResponse = await supabase
          .from('parking_bookings')
          .select('''
            *,
            parking_lots!parking_bookings_parking_id_fkey (*)
          ''')
          .gte('created_at', startDateStr)
          .lte('created_at', endDateStr);

      final bookingsCount = bookingsResponse.length;

      // Calculate revenue for the date range
      double totalRevenue = 0;
      for (var booking in bookingsResponse) {
        if (booking['total_fee'] != null) {
          totalRevenue += (booking['total_fee'] as num).toDouble();
        }
      }

      // Get active bookings in the date range
      final activeBookings = bookingsResponse.where((booking) => 
        ['pending', 'active'].contains(booking['status'])).length;

      if (mounted) {
        setState(() {
          _analytics = {
            ..._analytics,
            'custom_range_bookings': bookingsCount,
            'custom_range_revenue': totalRevenue,
            'custom_active_bookings': activeBookings,
          };
          _isLoading = false;
        });
      }

      // Update UI to show custom range data
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Calculated data for selected date range'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      print('Error calculating custom range analytics: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error calculating custom range: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildSearchSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Search Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Slot Search
            TextField(
              controller: _slotSearchController,
              decoration: InputDecoration(
                labelText: 'Search by Slot Number',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _searchBySlot(_slotSearchController.text),
                ),
              ),
            ),
            if (_slotSearchResult != null) ...[
              const SizedBox(height: 16),
              _buildSlotSearchResult(),
            ],
            const SizedBox(height: 24),
            // Vehicle Search
            TextField(
              controller: _vehicleSearchController,
              decoration: InputDecoration(
                labelText: 'Search by Vehicle Number',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _searchByVehicle(_vehicleSearchController.text),
                ),
              ),
            ),
            if (_vehicleSearchResults.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildVehicleSearchResults(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSlotSearchResult() {
    final booking = _slotSearchResult!;
    final profile = booking['profiles'];
    final slot = booking['parking_slots'];
    final lot = slot['parking_lots'];

    return Card(
      color: Colors.blue.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Parking Lot: ${lot['name']}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('Slot Number: ${slot['slot_number']}'),
            const Divider(),
            Text('Customer Name: ${profile['full_name']}'),
            Text('Phone Number: ${profile['phone_number']}'),
            Text('Aadhaar Number: ${profile['aadhaar_number']}'),
            Text('Vehicle Number: ${booking['vehicle_number']}'),
            Text(
              'Entry Time: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(booking['booking_time']))}',
            ),
            if (booking['exit_time'] != null)
              Text(
                'Exit Time: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(booking['exit_time']))}',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleSearchResults() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _vehicleSearchResults.length,
      itemBuilder: (context, index) {
        final booking = _vehicleSearchResults[index];
        final profile = booking['profiles'];
        final slot = booking['parking_slots'];
        final lot = slot['parking_lots'];

        return Card(
          color: Colors.green.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Parking Lot: ${lot['name']}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Slot Number: ${slot['slot_number']}'),
                const Divider(),
                Text('Customer Name: ${profile['full_name']}'),
                Text('Phone Number: ${profile['phone_number']}'),
                Text('Aadhaar Number: ${profile['aadhaar_number']}'),
                Text('Vehicle Number: ${booking['vehicle_number']}'),
                Text(
                  'Entry Time: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(booking['booking_time']))}',
                ),
                if (booking['exit_time'] != null)
                  Text(
                    'Exit Time: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(booking['exit_time']))}',
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeFilter() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Time Filter',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                _buildFilterChip('Today', 'today'),
                _buildFilterChip('Yesterday', 'yesterday'),
                _buildFilterChip('Week', 'week'),
                _buildFilterChip('Month', 'month'),
                _buildFilterChip('Year', 'year'),
                _buildFilterChip('Custom', 'custom'),
              ],
            ),
            if (_selectedTimeFilter == 'custom') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _startDate = date);
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(DateFormat('MMM dd, yyyy').format(_startDate)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _endDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _endDate = date);
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(DateFormat('MMM dd, yyyy').format(_endDate)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _calculateCustomDateRange,
                  icon: const Icon(Icons.calculate),
                  label: const Text('Calculate Custom Range'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: _selectedTimeFilter == value,
      onSelected: (bool selected) {
        setState(() {
          _selectedTimeFilter = value;
        });
        _loadAnalytics();
      },
    );
  }

  Widget _buildAnalyticsSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analytics Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAnalyticsCard(
                  'Lifetime Earnings',
                  '₹${_analytics['lifetime_earnings']?.toStringAsFixed(2) ?? '0.00'}',
                  Icons.currency_rupee,
                  Colors.green,
                ),
                _buildAnalyticsCard(
                  'All-Time Bookings',
                  '${_analytics['all_time_bookings'] ?? 0}',
                  Icons.book_online,
                  Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilteredAnalytics() {
    String label = '';
    if (_selectedTimeFilter == 'today') label = 'Today';
    else if (_selectedTimeFilter == 'yesterday') label = 'Yesterday';
    else if (_selectedTimeFilter == 'week') label = 'This Week';
    else if (_selectedTimeFilter == 'month') label = 'This Month';
    else if (_selectedTimeFilter == 'year') label = 'This Year';
    else if (_selectedTimeFilter == 'custom') label = 'Custom Range';
    else label = 'Selected';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label Analytics',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAnalyticsCard(
                  'Revenue',
                  '₹${_analytics['filtered_revenue']?.toStringAsFixed(2) ?? '0.00'}',
                  Icons.bar_chart,
                  Colors.purple,
                ),
                _buildAnalyticsCard(
                  'Bookings',
                  '${_analytics['filtered_bookings'] ?? 0}',
                  Icons.calendar_month,
                  Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Slot Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _parkingLots.length,
              itemBuilder: (context, index) {
                final lot = _parkingLots[index];
                final slots = lot['parking_slots'] as List;
                final availableSlots =
                    slots.where((slot) => slot['is_available'] == true).length;
                final totalSlots = slots.length;

                return ExpansionTile(
                  title: Text(lot['name']),
                  subtitle: Text(
                    '$availableSlots/$totalSlots slots available',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Base Rate: ₹${lot['base_rate_per_hour']}/hour',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Current Rate: ₹${lot['rate_per_hour']}/hour',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => _updateDynamicPricing(lot['id']),
                            child: const Text('Update Dynamic Pricing'),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: slots.map((slot) {
                              return Chip(
                                label: Text('Slot ${slot['slot_number']}'),
                                backgroundColor: slot['is_available']
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.red.withOpacity(0.2),
                                labelStyle: TextStyle(
                                  color: slot['is_available']
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Analytics'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchSection(),
                    const SizedBox(height: 16),
                    _buildTimeFilter(),
                    const SizedBox(height: 16),
                    _buildAnalyticsSummary(),
                    const SizedBox(height: 16),
                    _buildFilteredAnalytics(),
                    const SizedBox(height: 16),
                    _buildSlotStatus(),
                  ],
                ),
              ),
            ),
    );
  }
}
