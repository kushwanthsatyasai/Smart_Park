import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'qr_ticket_screen.dart';

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> bookingDetails;
  final Map<String, dynamic> parkingLot;
  final Map<String, dynamic> assignedSlot;

  const PaymentScreen({
    Key? key,
    required this.bookingDetails,
    required this.parkingLot,
    required this.assignedSlot,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isLoading = false;
  int? _selectedCardIndex;
  final _supabase = Supabase.instance.client;

  // Dummy card data - Replace with actual user's cards from database
  final List<Map<String, dynamic>> _cards = [
    {
      'number': '6473 7538 1823 0425',
      'name': 'Cameron Williamson',
      'type': 'visa',
    },
    {
      'number': '7934 2940 0298 1948',
      'name': 'Cameron Williamson',
      'type': 'visa',
    },
  ];

  Future<void> _processPayment() async {
    if (_selectedCardIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a payment method'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Update booking status to paid
      await _supabase
          .from('parking_bookings')
          .update({
            'status': 'paid',
            'payment_method': 'card',
            'payment_status': 'completed',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.bookingDetails['id']);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => QRTicketScreen(
              bookingDetails: widget.bookingDetails,
              parkingLot: widget.parkingLot,
              assignedSlot: widget.assignedSlot,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final startTime = widget.bookingDetails['booking_time'] != null
        ? DateTime.parse(widget.bookingDetails['booking_time'])
        : DateTime.now();
    final endTime = startTime.add(Duration(hours: widget.bookingDetails['duration']));

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Payment Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // Show payment info
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: Colors.yellow[100],
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.parkingLot['name'],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.parkingLot['address'],
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}PM to ${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}PM',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryRow(
                    'Rate',
                    '₹${widget.assignedSlot['rate_per_hour']}/hour',
                  ),
                  _buildSummaryRow(
                    'Duration',
                    '${widget.bookingDetails['duration']} Hours',
                  ),
                  _buildSummaryRow(
                    'Slot',
                    widget.assignedSlot['slot_number'],
                  ),
                  const Divider(height: 32),
                  _buildSummaryRow(
                    'Total Amount',
                    '₹${widget.bookingDetails['total_fee']}',
                    isTotal: true,
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Payment Methods',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildPaymentOption('PayPal', 'assets/paypal.png'),
                      const SizedBox(width: 12),
                      _buildPaymentOption('Apple Pay', 'assets/apple_pay.png'),
                      const SizedBox(width: 12),
                      _buildPaymentOption('Google Pay', 'assets/google_pay.png'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Saved Cards',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: [
                      const Text(
                        'Payment Methods',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          // Add new card
                        },
                        child: const Text('+ Add Card'),
                      ),
                    ],
                  ),
                  ..._cards.asMap().entries.map((entry) {
                    final index = entry.key;
                    final card = entry.value;
                    return _buildCardOption(
                      card['number'],
                      card['name'],
                      card['type'],
                      index,
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _processPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Pay Now',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal ? Colors.black : Colors.grey[600],
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isTotal ? Colors.black : Colors.grey[800],
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String name, String iconPath) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Image.asset(
          iconPath,
          height: 24,
        ),
      ),
    );
  }

  Widget _buildCardOption(
    String number,
    String name,
    String type,
    int index,
  ) {
    final isSelected = index == _selectedCardIndex;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCardIndex = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.credit_card,
                color: isSelected ? Colors.blue : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    number,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    name,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Image.asset(
              'assets/${type.toLowerCase()}.png',
              height: 24,
            ),
          ],
        ),
      ),
    );
  }
}
