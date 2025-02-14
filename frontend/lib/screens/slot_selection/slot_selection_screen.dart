import 'package:flutter/material.dart';
import '../payment/payment_screen.dart';

class SlotSelectionScreen extends StatefulWidget {
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final String selectedVehicle;

  const SlotSelectionScreen({
    super.key,
    required this.selectedDate,
    required this.selectedTime,
    required this.selectedVehicle,
  });

  @override
  State<SlotSelectionScreen> createState() => _SlotSelectionScreenState();
}

class _SlotSelectionScreenState extends State<SlotSelectionScreen> {
  String? selectedSlot;

  // Example slots - you might want to fetch these from an API
  final List<String> availableSlots = [
    'Slot A1',
    'Slot A2',
    'Slot B1',
    'Slot B2',
    'Slot C1',
    'Slot C2',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Parking Slot'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Selected Date: ${widget.selectedDate.toString().split(' ')[0]}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Selected Time: ${widget.selectedTime.format(context)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Selected Vehicle: ${widget.selectedVehicle}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            const Text(
              'Available Slots:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: availableSlots.length,
                itemBuilder: (context, index) {
                  final slot = availableSlots[index];
                  return Card(
                    color: selectedSlot == slot
                        ? Theme.of(context).primaryColor
                        : null,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          selectedSlot = slot;
                        });
                      },
                      child: Center(
                        child: Text(
                          slot,
                          style: TextStyle(
                            color: selectedSlot == slot ? Colors.white : null,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: selectedSlot != null
                  ? () {
                      // Navigate to payment screen
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PaymentScreen(
                            selectedDate: widget.selectedDate,
                            selectedTime: widget.selectedTime,
                            selectedVehicle: widget.selectedVehicle,
                            selectedSlot: selectedSlot!,
                          ),
                        ),
                      );
                    }
                  : null,
              child: const Text('Continue to Payment'),
            ),
          ],
        ),
      ),
    );
  }
}