// All previous imports unchanged
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'gcash_webview_payment.dart';
import 'check_email_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final nameController = TextEditingController();

  bool isPhotographer = false;
  String selectedPayment = 'GCash';
  String selectedSubscriptionPlan = 'Basic';
  bool agreedToTerms = false;
  bool isLoading = false;

  String getSubscriptionDetails(String plan) {
    switch (plan) {
      case 'Basic':
        return '₱199 / month\n- 1 GB storage\n- 5 portfolio slots';
      case 'Premium':
        return '₱399 / month\n- 5 GB storage\n- 20 portfolio slots';
      case 'Enterprise':
        return '₱999 / month\n- Unlimited storage\n- 100 portfolio slots';
      default:
        return '';
    }
  }

  Future<void> registerUser() async {
    if (!_formKey.currentState!.validate()) return;
    if (!agreedToTerms) {
      Fluttertoast.showToast(
        msg: "You must agree to the Terms & Conditions to proceed.",
      );
      return;
    }

    setState(() => isLoading = true);

    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final name = nameController.text.trim();

    try {
      final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(
        email,
      );
      if (methods.isNotEmpty) {
        Fluttertoast.showToast(
          msg: "This email is already registered. Try logging in.",
          toastLength: Toast.LENGTH_LONG,
        );
        setState(() => isLoading = false);
        return;
      }

      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user;
      await user!.sendEmailVerification();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': user.email,
        'name': name,
        'role': isPhotographer ? 'Photographer' : 'Client',
        'isVerified': false,
        'isPaid': isPhotographer ? false : null,
        'subscriptionPlan': isPhotographer ? selectedSubscriptionPlan : null,
        'createdAt': Timestamp.now(),
      });

      Fluttertoast.showToast(
        msg: 'Verification email sent to ${user.email}. Please verify.',
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CheckEmailVerificationScreen()),
      );

      if (isPhotographer) {
        if (selectedPayment == 'GCash') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => GCashWebViewPaymentScreen(
                paymentUrl: 'https://your-paymongo-link.com',
                contextType: 'registration',
                referenceId: user.uid,
              ),
            ),
          );
        } else {
          Fluttertoast.showToast(msg: "PayPal payment simulated (success)");
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
                'isPaid': true,
                'paymentMethod': 'PayPal',
                'paidAt': Timestamp.now(),
              });
          Navigator.pushReplacementNamed(context, '/dashboard_selector');
        }
      } else {
        Navigator.pushReplacementNamed(context, '/dashboard_selector');
      }
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred';
      if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      } else if (e.code == 'weak-password') {
        message = 'Password must be at least 6 characters.';
      } else {
        message = e.message ?? 'Something went wrong. Please try again.';
      }
      Fluttertoast.showToast(msg: message);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error: ${e.toString()}');
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
          child: isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.person_add,
                              size: 60,
                              color: Colors.blue,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Create Account",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                labelText: 'Full Name',
                                prefixIcon: Icon(Icons.person),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  value!.isEmpty ? 'Enter your name' : null,
                            ),
                            const SizedBox(height: 15),
                            TextFormField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  value!.isEmpty ? 'Enter your email' : null,
                            ),
                            const SizedBox(height: 15),
                            TextFormField(
                              controller: passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                prefixIcon: Icon(Icons.lock),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) => value!.length < 6
                                  ? 'Minimum 6 characters'
                                  : null,
                            ),
                            const SizedBox(height: 15),
                            TextFormField(
                              controller: confirmPasswordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Confirm Password',
                                prefixIcon: Icon(Icons.lock_outline),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  value != passwordController.text
                                  ? 'Passwords do not match'
                                  : null,
                            ),
                            const SizedBox(height: 15),
                            SwitchListTile(
                              title: const Text('Register as Photographer'),
                              value: isPhotographer,
                              onChanged: (val) =>
                                  setState(() => isPhotographer = val),
                            ),
                            if (isPhotographer) ...[
                              DropdownButtonFormField<String>(
                                value: selectedSubscriptionPlan,
                                items: ['Basic', 'Premium', 'Enterprise']
                                    .map(
                                      (plan) => DropdownMenuItem(
                                        value: plan,
                                        child: Text(
                                          '$plan (${getSubscriptionDetails(plan).split('\n')[0]})',
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) => setState(
                                  () => selectedSubscriptionPlan = val!,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Subscription Plan',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  getSubscriptionDetails(
                                    selectedSubscriptionPlan,
                                  ),
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                value: selectedPayment,
                                items: ['GCash', 'PayPal']
                                    .map(
                                      (method) => DropdownMenuItem(
                                        value: method,
                                        child: Text(method),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => selectedPayment = val!),
                                decoration: const InputDecoration(
                                  labelText: 'Payment Method',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                            const SizedBox(height: 15),
                            CheckboxListTile(
                              title: const Text(
                                "I agree to the Terms & Conditions",
                                style: TextStyle(fontSize: 14),
                              ),
                              value: agreedToTerms,
                              onChanged: (val) =>
                                  setState(() => agreedToTerms = val!),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                            const SizedBox(height: 15),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: registerUser,
                                icon: const Icon(Icons.app_registration),
                                label: const Text("Register"),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  textStyle: const TextStyle(fontSize: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                "Already have an account? Login",
                                style: TextStyle(color: Colors.blueAccent),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
