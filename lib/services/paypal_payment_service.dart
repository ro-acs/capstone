import 'package:http/http.dart' as http;
import 'dart:convert';

class PayPalPaymentService {
  static const String backendEndpoint =
      'https://your-server.com/create-paypal-payment'; // Replace this

  static Future<String?> getPayPalPaymentUrl({
    required String bookingId,
    required double amount,
    required String note,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(backendEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'bookingId': bookingId,
          'amount': amount,
          'note': note,
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['approvalUrl']; // URL to redirect to PayPal WebView
      } else {
        print(
          "❌ PayPal backend error: ${response.statusCode} ${response.body}",
        );
        return null;
      }
    } catch (e) {
      print("❌ Exception fetching PayPal URL: $e");
      return null;
    }
  }
}
