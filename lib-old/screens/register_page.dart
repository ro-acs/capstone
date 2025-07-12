import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/paymongo_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  String selectedRole = 'client';
  String? _subscriptionType;
  String? _paymentMethod;
  bool _acceptedTerms = false;

  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool isLoading = false;

  String _passwordStrengthLabel = '';
  Color _strengthColor = Colors.grey;

  void _checkPasswordStrength(String password) {
    setState(() {
      if (password.isEmpty) {
        _passwordStrengthLabel = '';
        _strengthColor = Colors.grey;
      } else if (password.length < 6) {
        _passwordStrengthLabel = 'Too short';
        _strengthColor = Colors.red;
      } else if (password.length < 8 || !RegExp(r'[A-Z]').hasMatch(password)) {
        _passwordStrengthLabel = 'Weak';
        _strengthColor = Colors.orange;
      } else if (!RegExp(r'[0-9]').hasMatch(password) ||
          !RegExp(r'[!@#\$&*~]').hasMatch(password)) {
        _passwordStrengthLabel = 'Medium';
        _strengthColor = Colors.amber;
      } else {
        _passwordStrengthLabel = 'Strong';
        _strengthColor = Colors.green;
      }
    });
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Terms and Conditions"),
        content: const SingleChildScrollView(
          child: Text(
            "By registering, you agree to SnapSpot's terms:\n\n"
            "- Use the app responsibly\n"
            "- Respect bookings and users\n"
            "- Comply with payment policies\n"
            "- No fraudulent activity\n",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Future<void> registerUser() async {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
    });

    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();
    final fullName = fullNameController.text.trim();

    bool hasError = false;

    if (email.isEmpty || !email.contains('@')) {
      _emailError = 'Enter a valid email';
      hasError = true;
    }

    if (password.length < 8) {
      _passwordError = 'Password must be at least 8 characters';
      hasError = true;
    }

    if (password != confirmPassword) {
      _confirmPasswordError = 'Passwords do not match';
      hasError = true;
    }

    if (!_acceptedTerms) {
      Fluttertoast.showToast(msg: 'Please accept the terms and conditions');
      hasError = true;
    }

    if (selectedRole == 'photographer') {
      if (_subscriptionType == null || _paymentMethod == null) {
        Fluttertoast.showToast(msg: 'Select subscription and payment method');
        hasError = true;
      }
    }

    if (hasError) {
      setState(() {});
      return;
    }

    try {
      setState(() => isLoading = true);

      final userCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final uid = userCred.user!.uid;

      await FirebaseFirestore.instance.collection('tblusers').doc(uid).set({
        'created_at': Timestamp.now(),
        'credit': 0,
        'email': email,
        'email_preferences': 0,
        'fullName': fullName,
        'last_ip': null,
        'last_login': null,
        'notes': null,
        'phonenumber': null,
        'photoUrl': null,
        'role': selectedRole,
        'security_question_answer': null,
        'security_question_id': 0,
        'status': selectedRole == 'photographer' ? 'pending' : 'none',
        'uid': uid,
        'updated_at': Timestamp.now(),
      });

      if (selectedRole == 'photographer') {
        final cost = _subscriptionType == 'yearly' ? 99900 : 29900;

        await FirebaseFirestore.instance
            .collection('tblsubscription')
            .doc(uid)
            .set({
              'availability': null,
              'created_at': Timestamp.now(),
              'payment_method': _paymentMethod,
              'payment_status': 'pending',
              'subscription_cost': cost,
              'subscription_type': _subscriptionType,
              'uid': uid,
            });

        if (_paymentMethod == 'gcash') {
          final token = await FirebaseAuth.instance.currentUser?.getIdToken();
          final checkoutUrl = await PayMongoService.createGcashSource(
            amount: cost,
            successUrl:
                'http://capstone.x10.mx/gcashSuccess?collection=tblsubscription&id=$uid&token=$token',
            failedUrl: 'https://yourdomain.com/failed',
          );

          if (checkoutUrl != null && context.mounted) {
            await launchUrl(
              Uri.parse(checkoutUrl),
              mode: LaunchMode.externalApplication,
            );
          } else {
            Fluttertoast.showToast(msg: '❌ Failed to start GCash payment');
          }
        } else if (_paymentMethod == 'paypal') {
          // Simulate PayPal payment success
          await FirebaseFirestore.instance
              .collection('tblsubscription')
              .doc(uid)
              .update({
                'payment_status': 'paid',
                'payment_confirmed_at': Timestamp.now(),
              });

          Fluttertoast.showToast(msg: '✅ PayPal payment simulated');

          // You may also send email here
        }
      } else {
        Navigator.pushReplacementNamed(context, '/client_dashboard');
      }

      Fluttertoast.showToast(msg: "🎉 Registration successful!");
    } catch (e) {
      Fluttertoast.showToast(msg: "Registration failed: ${e.toString()}");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // unchanged build() method
    return Scaffold(
      backgroundColor: Colors.deepPurple[50],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Icon(Icons.person_add, size: 80, color: Colors.deepPurple),
              const SizedBox(height: 20),
              const Text(
                "Create Account",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Join SnapSpot to book or offer services",
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: fullNameController,
                decoration: const InputDecoration(
                  labelText: "Full Name",
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: "Email",
                  prefixIcon: const Icon(Icons.email),
                  border: const OutlineInputBorder(),
                  errorText: _emailError,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: _obscurePassword,
                onChanged: _checkPasswordStrength,
                decoration: InputDecoration(
                  labelText: "Password",
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  errorText: _passwordError,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _passwordStrengthLabel,
                  style: TextStyle(color: _strengthColor),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: "Confirm Password",
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  errorText: _confirmPasswordError,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(
                  labelText: "Select Role",
                  prefixIcon: Icon(Icons.group),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'client', child: Text("Client")),
                  DropdownMenuItem(
                    value: 'photographer',
                    child: Text("Photographer"),
                  ),
                ],
                onChanged: (val) => setState(() {
                  selectedRole = val!;
                  _subscriptionType = null;
                  _paymentMethod = null;
                }),
              ),
              if (selectedRole == 'photographer') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _subscriptionType,
                  decoration: const InputDecoration(
                    labelText: "Subscription Type",
                    prefixIcon: Icon(Icons.subscriptions),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'monthly', child: Text("Monthly")),
                    DropdownMenuItem(value: 'yearly', child: Text("Yearly")),
                  ],
                  onChanged: (value) =>
                      setState(() => _subscriptionType = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  decoration: const InputDecoration(
                    labelText: "Payment Method",
                    prefixIcon: Icon(Icons.payment),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'gcash', child: Text("GCash")),
                    DropdownMenuItem(value: 'paypal', child: Text("PayPal")),
                  ],
                  onChanged: (value) => setState(() => _paymentMethod = value),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _acceptedTerms,
                    onChanged: (val) =>
                        setState(() => _acceptedTerms = val ?? false),
                  ),
                  const Text("I accept the "),
                  GestureDetector(
                    onTap: _showTermsDialog,
                    child: const Text(
                      "Terms and Conditions",
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : registerUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple[50],
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.black),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text("Register", style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Already have an account? Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
