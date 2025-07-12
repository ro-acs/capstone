
import 'dart:convert';
import 'package:http/http.dart' as http;

class PayPalService {
  static const String clientId = 'YOUR-SANDBOX-CLIENT-ID';
  static const String secret = 'YOUR-SANDBOX-SECRET';
  static const String baseUrl = 'https://api-m.sandbox.paypal.com';

  Future<String> getAccessToken() async {
    final basicAuth = base64Encode(utf8.encode('\$clientId:\$secret'));
    final response = await http.post(
      Uri.parse('\$baseUrl/v1/oauth2/token'),
      headers: {
        'Authorization': 'Basic \$basicAuth',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: 'grant_type=client_credentials',
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['access_token'];
    } else {
      throw Exception('Failed to get PayPal access token');
    }
  }

  Future<Map<String, dynamic>> createOrder(String accessToken, String amount) async {
    final response = await http.post(
      Uri.parse('\$baseUrl/v2/checkout/orders'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer \$accessToken',
      },
      body: jsonEncode({
        "intent": "CAPTURE",
        "purchase_units": [
          {
            "amount": {
              "currency_code": "USD",
              "value": amount
            }
          }
        ],
        "application_context": {
          "return_url": "https://example.com/success",
          "cancel_url": "https://example.com/cancel"
        }
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create PayPal order');
    }
  }
}
