import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> createPayment({
    required String bookingId,
    required double amount,
    required String paymentMethod,
  }) async {
    final response = await _supabase.from('payments').insert({
      'booking_id': bookingId,
      'amount': amount,
      'payment_method': paymentMethod,
      'status': 'pending',
    }).select().single();

    return response;
  }

  Future<void> updatePaymentStatus({
    required String paymentId,
    required String status,
    String? transactionId,
  }) async {
    await _supabase.from('payments').update({
      'status': status,
      'transaction_id': transactionId,
      'payment_time': DateTime.now().toIso8601String(),
    }).eq('id', paymentId);
  }
} 