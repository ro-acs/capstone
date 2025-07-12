import 'dart:convert';
import 'package:http/http.dart' as http;

class PayPalPaymentService {
  static const String backendUrl = 'https://capstone.x10.mx/create-paypal-order';

  static Future<String?> getPayPalPaymentUrl({
    required String bookingId,
    required double amount,
    String note = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'bookingId': bookingId,
          'amount': amount,
          'note': note,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['paypal_url'];
      } else {
        print('❌ PayPal Error: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Exception during PayPal call: $e');
      return null;
    }
  }
}
