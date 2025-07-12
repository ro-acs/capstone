import 'dart:convert';
import 'package:http/http.dart' as http;

class PayPalPaymentService {
  static Future<String?> getPayPalPaymentUrl({
    required String bookingId,
    required double amount,
    required String note,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
          'https://your-backend-url.com/create-paypal-payment',
        ), // change this
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'bookingId': bookingId,
          'amount': amount,
          'note': note,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['approvalUrl']; // e.g. "https://paypal.com/checkout?..."
      } else {
        print("❌ PayPal server error: ${response.body}");
        return null;
      }
    } catch (e) {
      print("❌ PayPal API error: $e");
      return null;
    }
  }
}
