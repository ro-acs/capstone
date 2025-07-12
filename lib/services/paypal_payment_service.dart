import 'package:http/http.dart' as http;
import 'dart:convert';

class PayPalPaymentService {
  static const String backendEndpoint =
      'https://capstone.x10.mx/createpaypalorder'; // Replace this

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

      final Map<String, dynamic> data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['paypal_url'] != null) {
        return data['paypal_url'];
      } else {
        throw Exception('PayPal URL not received');
      }
    } catch (e) {
      print('PayPal error: $e');
      return null;
    }
  }
}
