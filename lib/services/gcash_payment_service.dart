import 'dart:convert';
import 'package:http/http.dart' as http;

class GCashPaymentService {
  static const String backendUrl = 'https://capstone.x10.mx/create-payment';

  static Future<String> getPaymentUrl({
    required String uid,
    required int amountInCentavos, // e.g. 19900 for ₱199
  }) async {
    try {
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': uid, 'amount': amountInCentavos}),
      );

      final Map<String, dynamic> raw = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (raw.containsKey('checkout_url')) {
          return raw['checkout_url'];
        } else if (raw.containsKey('details')) {
          final dynamic details = json.decode(raw['details']);
          final checkoutUrl =
              details['data']?['attributes']?['redirect']?['checkout_url'];

          if (checkoutUrl != null) {
            return checkoutUrl;
          }
        }
        throw Exception('❌ Server response has no checkout_url');
      } else {
        throw Exception(
          '❌ GCash API error: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      print('❌ GCash exception: $e');
      rethrow;
    }
  }
}
