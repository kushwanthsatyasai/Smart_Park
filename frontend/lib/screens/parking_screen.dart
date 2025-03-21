import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ParkingScreen extends StatefulWidget {
  // ... (existing code)

  @override
  State<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends State<ParkingScreen> {
  // ... (existing code)

  void checkAvailability() async {
    try {
      final response =
          await Supabase.instance.client
              .from('parking_slots')
              .select('available_slots')
              .eq('id', parkingId)
              .single()
              .execute();

      if (response.error != null) {
        throw response.error!;
      }

      final availableSlots = response.data['available_slots'] as int;

      if (availableSlots > 0) {
        // Navigate to booking screen
        final booked = await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => BookingScreen(
                  parkingId: parkingId,
                  availableSlots: availableSlots,
                ),
          ),
        );

        // If booking was successful, refresh the availability
        if (booked == true) {
          checkAvailability(); // Refresh the count
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No parking slots available')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (existing code)
  }
}
