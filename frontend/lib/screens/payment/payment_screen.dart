import 'package:flutter/material.dart';
import '../qr_code_screen.dart';
import '../../widgets/custom_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../booking/booking_confirmation_screen.dart';

class PaymentScreen extends StatefulWidget {
  final String bookingId;
  final double amount;

  const PaymentScreen({
    super.key,
    required this.bookingId,
    required this.amount,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedPaymentMethod = 'card';
  bool _isProcessing = false;

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);

    try {
      final supabase = Supabase.instance.client;

      // First get the booking details
      final booking = await supabase
          .from('bookings')
          .select()
          .eq('id', widget.bookingId)
          .single();

      // Update booking with payment details
      final response = await supabase
          .from('bookings')
          .update({
            'payment_method': _selectedPaymentMethod,
            'payment_status': 'completed',
            'booking_status': 'confirmed',
          })
          .eq('id', widget.bookingId)
          .select()
          .single();

      // Ensure response is properly typed
      final Map<String, dynamic> bookingDetails = response as Map<String, dynamic>;

      // Create payment record
      await supabase.from('payments').insert({
        'booking_id': widget.bookingId,
        'amount': widget.amount,
        'payment_method': _selectedPaymentMethod,
        'status': 'completed',
        'transaction_id': 'TXN-${DateTime.now().millisecondsSinceEpoch}',
      });

      // Get parking lot and slot details
      final parkingLotResponse = await supabase
          .from('parking_lots')
          .select()
          .eq('id', booking['parking_lot_id'])
          .single();

      final assignedSlotResponse = await supabase
          .from('parking_slots')
          .select()
          .eq('id', booking['assigned_slot_id'])
          .single();

      // Ensure responses are properly typed
      final Map<String, dynamic> parkingLot = parkingLotResponse as Map<String, dynamic>;
      final Map<String, dynamic> assignedSlot = assignedSlotResponse as Map<String, dynamic>;

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BookingConfirmationScreen(
              bookingDetails: bookingDetails,
              parkingLot: parkingLot,
              assignedSlot: assignedSlot,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mock payment amount calculation
    final double amount = widget.amount;

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
                    _buildDetailRow('Amount', '\$${amount.toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ),
            const Spacer(),
            CustomButton(
              text: 'Pay Now',
              onPressed: _processPayment,
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
