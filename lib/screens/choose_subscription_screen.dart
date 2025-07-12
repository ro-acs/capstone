import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'gcash_webview_payment.dart';
import 'paypal_webview_payment.dart';
import '/services/gcash_payment_service.dart';
import '/services/paypal_payment_service.dart';

class ChooseSubscriptionScreen extends StatefulWidget {
  final String uid;

  const ChooseSubscriptionScreen({required this.uid, super.key});

  @override
  State<ChooseSubscriptionScreen> createState() =>
      _ChooseSubscriptionScreenState();
}

class _ChooseSubscriptionScreenState extends State<ChooseSubscriptionScreen> {
  String? selectedPlanId;
  String selectedPayment = 'GCash';
  Map<String, dynamic>? selectedPlanData;
  bool isLoading = false;

  Future<List<QueryDocumentSnapshot>> fetchPlans() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('subscription_plans')
        .get();
    return snapshot.docs;
  }

  void _proceedToPayment() async {
    if (selectedPlanId == null || selectedPlanData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a subscription plan.")),
      );
      return;
    }

    final int? price = selectedPlanData!['price'];
    final String? planName = selectedPlanData!['name'];

    if (price == null || planName == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid plan data.")));
      return;
    }

    try {
      setState(() => isLoading = true);

      if (selectedPayment == 'GCash') {
        final String? url = await GCashPaymentService.getPaymentUrl(
          uid: widget.uid,
          amountInCentavos: price,
        );

        if (url == null || url.isEmpty) {
          throw Exception("GCash URL not returned.");
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => GCashWebViewPaymentScreen(
              paymentUrl: url,
              contextType: 'registration',
              referenceId: widget.uid,
              amount: price / 100,
              note: 'Subscription payment: $planName',
            ),
          ),
        );
      } else if (selectedPayment == 'PayPal') {
        final double phpAmount = price / 100;

        final String? paypalUrl =
            await PayPalPaymentService.getPayPalPaymentUrl(
              bookingId: widget.uid,
              amount: phpAmount,
              note: 'Subscription payment: $planName',
            );

        if (paypalUrl == null || paypalUrl.isEmpty) {
          throw Exception('PayPal payment URL not generated.');
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PayPalWebViewPaymentScreen(
              paymentUrl: paypalUrl,
              contextType: 'registration',
              referenceId: widget.uid,
              uid: widget.uid,
              amount: phpAmount,
              note: 'Subscription payment: $planName',
            ),
          ),
        );
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .update({'subscriptionPlan': selectedPlanId});
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Payment error: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Subscription & Payment')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<QueryDocumentSnapshot>>(
              future: fetchPlans(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || (snapshot.data?.isEmpty ?? true)) {
                  return const Center(
                    child: Text("No subscription plans available."),
                  );
                }

                final plans = snapshot.data!;

                if (selectedPlanId == null && plans.length == 1) {
                  final plan = plans[0].data() as Map<String, dynamic>;
                  selectedPlanId = plans[0].id;
                  selectedPlanData = plan;
                }

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        "Select Subscription Plan:",
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      ...plans.map((doc) {
                        final plan = doc.data() as Map<String, dynamic>;
                        final planId = doc.id;
                        final planName = plan['name'] ?? 'Unnamed';
                        final int? planPrice = plan['price'];

                        final formattedPrice = planPrice != null
                            ? (planPrice / 100).toStringAsFixed(2)
                            : '0.00';

                        return RadioListTile<String>(
                          title: Text('$planName - ₱$formattedPrice'),
                          value: planId,
                          groupValue: selectedPlanId,
                          onChanged: (val) {
                            setState(() {
                              selectedPlanId = val;
                              selectedPlanData = plan;
                            });
                          },
                        );
                      }).toList(),
                      const SizedBox(height: 20),
                      const Text(
                        "Choose Payment Method:",
                        style: TextStyle(fontSize: 16),
                      ),
                      RadioListTile(
                        title: const Text('GCash'),
                        value: 'GCash',
                        groupValue: selectedPayment,
                        onChanged: (val) =>
                            setState(() => selectedPayment = val!),
                      ),
                      RadioListTile(
                        title: const Text('PayPal'),
                        value: 'PayPal',
                        groupValue: selectedPayment,
                        onChanged: (val) =>
                            setState(() => selectedPayment = val!),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.payment),
                        label: const Text("Proceed to Payment"),
                        onPressed: _proceedToPayment,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
