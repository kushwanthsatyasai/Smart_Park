import 'package:flutter/material.dart';
import '../qr_code_screen.dart';
import '../../widgets/custom_button.dart';

class PaymentScreen extends StatelessWidget {
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final String selectedVehicle;
  final String selectedSlot;

  const PaymentScreen({
    Key? key,
    required this.selectedDate,
    required this.selectedTime,
    required this.selectedVehicle,
    required this.selectedSlot,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Mock payment amount calculation
    final double amount = selectedVehicle == 'Car' ? 20.0 : 10.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Booking Details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow('Date', 
                      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                    _buildDetailRow('Time', selectedTime.format(context)),
                    _buildDetailRow('Vehicle', selectedVehicle),
                    _buildDetailRow('Slot', selectedSlot),
                    _buildDetailRow('Amount', '\$${amount.toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ),
            const Spacer(),
            CustomButton(
              text: 'Pay Now',
              onPressed: () {
                // Mock successful payment
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => QRCodeScreen(
                      bookingData: 'Booking-${DateTime.now().millisecondsSinceEpoch}',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
} 