// lib/services/paymongo_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class PayMongoService {
  static const String _secretKey = 'sk_test_s6FB8keY2UthTy7TBce7Vfwd';

  static Future<String?> createGcashSource({
    required int amount,
    required String successUrl,
    required String failedUrl,
  }) async {
    final secretKey =
        'sk_test_s6FB8keY2UthTy7TBce7Vfwd'; // Replace with your actual secret key
    final credentials = base64Encode(utf8.encode('$secretKey:'));

    final headers = {
      'Authorization': 'Basic $credentials',
      'Content-Type': 'application/json',
    };

    final body = jsonEncode({
      'data': {
        'attributes': {
          'amount': amount,
          'redirect': {'success': successUrl, 'failed': failedUrl},
          'type': 'gcash',
          'currency': 'PHP',
        },
      },
    });

    final res = await http.post(
      Uri.parse('https://api.paymongo.com/v1/sources'),
      headers: headers,
      body: body,
    );

    print(res.statusCode);

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      final url = json['data']['attributes']['redirect']['checkout_url'];
      print('✅ GCash checkout URL: $url');
      print('$json');
      return url;
    } else {
      print('❌ PayMongo GCash Error (actual failure): ${res.body}');
      return null;
    }
  }
}
