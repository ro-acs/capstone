import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../check_email_verification_screen.dart';
import '../gcash_webview_payment.dart';
import '../payment_success.dart';
import '/services/gcash_payment_service.dart';

class TermsConditionsScreen extends StatefulWidget {
  final String email;
  final String password;
  final String name;
  final bool isPhotographer;
  final String? subscriptionPlan;

  const TermsConditionsScreen({
    super.key,
    required this.email,
    required this.password,
    required this.name,
    required this.isPhotographer,
    this.subscriptionPlan,
  });

  @override
  State<TermsConditionsScreen> createState() => _TermsConditionsScreenState();
}

class _TermsConditionsScreenState extends State<TermsConditionsScreen> {
  bool agreed = false;
  bool isLoading = false;
  String selectedPaymentMethod = 'GCash';
  String? planName;
  int? subscriptionPrice;

  @override
  void initState() {
    super.initState();
    _fetchSubscriptionDetails();
  }

  Future<void> _fetchSubscriptionDetails() async {
    if (widget.isPhotographer && widget.subscriptionPlan != null) {
      try {
        final planDoc = await FirebaseFirestore.instance
            .collection('subscription_plans')
            .doc(widget.subscriptionPlan)
            .get();

        if (planDoc.exists) {
          setState(() {
            subscriptionPrice = planDoc.data()?['price'];
            planName = planDoc.data()?['name'];
          });
        }
      } catch (e) {
        Fluttertoast.showToast(msg: "Failed to load plan details.");
      }
    }
  }

  Future<void> _completeRegistration() async {
    if (!agreed) {
      Fluttertoast.showToast(msg: "Please agree to the terms and conditions.");
      return;
    }

    setState(() => isLoading = true);

    try {
      final userCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: widget.email,
            password: widget.password,
          );

      final user = userCred.user!;
      await user.sendEmailVerification();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': widget.email,
        'name': widget.name,
        'role': widget.isPhotographer ? 'Photographer' : 'Client',
        'subscriptionPlan': widget.subscriptionPlan,
        'subscriptionPrice': subscriptionPrice,
        'isVerified': false,
        'isPaid': widget.isPhotographer ? false : null,
        'createdAt': Timestamp.now(),
      });

      Fluttertoast.showToast(
        msg: 'Verification email sent to ${user.email}. Please verify.',
      );

      if (widget.isPhotographer) {
        if (selectedPaymentMethod == 'GCash') {
          if (subscriptionPrice == null) {
            Fluttertoast.showToast(msg: "No price found for the plan.");
            return;
          }

          final checkoutUrl = await GCashPaymentService.getPaymentUrl(
            uid: user.uid,
            amountInCentavos: subscriptionPrice!,
          );

          if (checkoutUrl != null) {
            Navigator.pushReplacementNamed(
              context,
              '/gcash_payment',
              arguments: {
                'paymentUrl': checkoutUrl,
                'contextType': 'registration',
                'referenceId': user.uid,
                'amount': subscriptionPrice,
                'note': 'Photographer registration payment',
              },
            );
          } else {
            Fluttertoast.showToast(msg: "❌ Failed to create GCash link.");
          }
        } else {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
                'isPaid': true,
                'paymentMethod': 'PayPal',
                'paidAt': Timestamp.now(),
              });

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const PaymentSuccessScreen(contextType: 'registration'),
            ),
          );
        }
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const CheckEmailVerificationScreen(),
          ),
        );
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: ${e.toString()}");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1D3557), Color(0xFF457B9D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.rule, size: 60, color: Colors.teal),
                    const SizedBox(height: 10),
                    const Text(
                      "Step 5: Terms & Conditions",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SizedBox(
                      height: 200,
                      child: SingleChildScrollView(
                        child: Text('''
By creating an account, you agree to the following terms:

1. Provide accurate and complete information.
2. Respectful behavior is expected on the platform.
3. SnapSpot reserves the right to verify, suspend, or ban accounts.
4. Photographers must complete payment and verification.
5. All bookings are subject to admin approval.
6. All data is handled per our privacy policy.

Failure to comply may result in termination of service.
                        ''', textAlign: TextAlign.justify),
                      ),
                    ),
                    const SizedBox(height: 15),
                    CheckboxListTile(
                      value: agreed,
                      onChanged: (val) => setState(() => agreed = val ?? false),
                      title: const Text("I agree to the Terms & Conditions"),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    if (widget.isPhotographer) ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: selectedPaymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Payment Method',
                          border: OutlineInputBorder(),
                        ),
                        items: ['GCash', 'PayPal'].map((method) {
                          return DropdownMenuItem(
                            value: method,
                            child: Text(method),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => selectedPaymentMethod = val!),
                      ),
                      const SizedBox(height: 20),
                      if (planName != null && subscriptionPrice != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Selected Plan: $planName",
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Price: ₱${(subscriptionPrice! / 100).toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: agreed && !isLoading
                            ? _completeRegistration
                            : null,
                        icon: const Icon(Icons.check_circle),
                        label: isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text("Finish Registration"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(fontSize: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
