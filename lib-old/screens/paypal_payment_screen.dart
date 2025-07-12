// lib/screens/paypal_screen.dart
import 'package:flutter/material.dart';
import '../services/paypal_service.dart';
import 'package:url_launcher/url_launcher.dart';

class PaypalPaymentScreen extends StatefulWidget {
  final String userId;
  const PaypalPaymentScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<PaypalPaymentScreen> createState() => _PayPalScreenState();
}

class _PayPalScreenState extends State<PaypalPaymentScreen> {
  final PayPalService _payPalService = PayPalService();
  String? _approvalUrl;

  Future<void> _startPayPalPayment() async {
    try {
      final accessToken = await _payPalService.getAccessToken();
      final order = await _payPalService.createOrder(accessToken, '10.00');

      final links = order['links'] as List<dynamic>;
      final approvalLink = links.firstWhere(
        (link) => link['rel'] == 'approve',
      )['href'];

      setState(() {
        _approvalUrl = approvalLink;
      });

      // Open the approval URL in browser (can use WebView for in-app)
      if (await canLaunchUrl(Uri.parse(_approvalUrl!))) {
        await launchUrl(
          Uri.parse(_approvalUrl!),
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw Exception('Could not launch PayPal approval URL');
      }
    } catch (e) {
      print('Error during PayPal Payment: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PayPal Sandbox Payment')),
      body: Center(
        child: ElevatedButton(
          onPressed: _startPayPalPayment,
          child: const Text('Pay with PayPal'),
        ),
      ),
    );
  }
}
