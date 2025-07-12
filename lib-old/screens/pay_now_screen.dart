import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '/services/paymongo_service.dart';

class PayNowScreen extends StatelessWidget {
  final int amount;

  const PayNowScreen({required this.amount, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pay with GCash')),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.payment),
          label: const Text('Pay Now'),
          onPressed: () async {
            final checkoutUrl = await PayMongoService.createGcashSource(
              amount: amount,
              successUrl: 'https://yourdomain.com/success',
              failedUrl: 'https://yourdomain.com/failed',
            );

            if (checkoutUrl != null &&
                await canLaunchUrl(Uri.parse(checkoutUrl))) {
              launchUrl(
                Uri.parse(checkoutUrl),
                mode: LaunchMode.externalApplication,
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to start payment')),
              );
            }
          },
        ),
      ),
    );
  }
}
