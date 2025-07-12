import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'dashboard_client.dart';
import 'dashboard_photographer.dart';
import 'dashboard_admin.dart';
import 'choose_subscription_screen.dart';
import '/services/gcash_payment_service.dart'; // ⬅️ Don't forget this

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;

  String email = '';
  String password = '';
  bool isLoading = false;

  void _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    try {
      UserCredential userCred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = userCred.user;

      if (user != null && !user.emailVerified) {
        await _auth.signOut();
        Fluttertoast.showToast(
          msg: "Please verify your email before logging in.",
          toastLength: Toast.LENGTH_LONG,
        );
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Email Not Verified"),
            content: const Text(
              "A verification link was sent to your email. Would you like to resend it?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await user.sendEmailVerification();
                    Fluttertoast.showToast(
                      msg: "Verification email resent to ${user.email}",
                    );
                  } catch (e) {
                    Fluttertoast.showToast(
                      msg: "Failed to resend verification email.",
                    );
                  }
                },
                child: const Text("Resend"),
              ),
            ],
          ),
        );
        setState(() => isLoading = false);
        return;
      }

      final uid = user!.uid;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        Fluttertoast.showToast(msg: 'User data not found.');
        await _auth.signOut();
        setState(() => isLoading = false);
        return;
      }

      final role = userDoc['role'];
      final isPaid = userDoc['isPaid'] ?? true;

      // Photographer not paid → redirect to GCash
      if (role == 'Photographer' && isPaid == false) {
        Fluttertoast.showToast(msg: "Please complete your subscription.");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ChooseSubscriptionScreen(uid: uid)),
        );
        return;
      }

      Fluttertoast.showToast(msg: 'Login successful as $role');

      if (role == 'Client') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardClient()),
        );
      } else if (role == 'Photographer') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardPhotographer()),
        );
      } else if (role == 'Admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardAdmin()),
        );
      } else {
        Fluttertoast.showToast(msg: 'Unknown role: $role');
        await _auth.signOut();
      }
    } on FirebaseAuthException catch (e) {
      Fluttertoast.showToast(msg: e.message ?? 'Login failed.');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showForgotPasswordDialog() {
    String resetEmail = '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextFormField(
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Enter your email',
            prefixIcon: Icon(Icons.email),
          ),
          onChanged: (val) => resetEmail = val,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (resetEmail.trim().isEmpty || !resetEmail.contains('@')) {
                Fluttertoast.showToast(msg: 'Enter a valid email');
                return;
              }

              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(
                  email: resetEmail.trim(),
                );
                Fluttertoast.showToast(
                  msg: 'Password reset email sent to $resetEmail',
                );
              } on FirebaseAuthException catch (e) {
                Fluttertoast.showToast(
                  msg: e.message ?? 'Failed to send email',
                );
              }
            },
            child: const Text(
              'Send Reset Link',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
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
                  padding: const EdgeInsets.all(16.0),
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
                              Icons.lock,
                              size: 60,
                              color: Colors.blue,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Welcome Back!",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.email),
                                labelText: "Email",
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              onChanged: (val) => email = val,
                              validator: (val) =>
                                  val == null || !val.contains('@')
                                  ? 'Enter a valid email'
                                  : null,
                            ),
                            const SizedBox(height: 15),
                            TextFormField(
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.lock),
                                labelText: "Password",
                                border: OutlineInputBorder(),
                              ),
                              obscureText: true,
                              onChanged: (val) => password = val,
                              validator: (val) => val == null || val.length < 6
                                  ? 'Password must be at least 6 characters'
                                  : null,
                            ),
                            const SizedBox(height: 15),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _showForgotPasswordDialog,
                                child: const Text("Forgot password?"),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _login,
                                icon: const Icon(Icons.login),
                                label: const Text("Login"),
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
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  '/mail_entry_screen',
                                );
                              },
                              child: const Text(
                                "Don't have an account? Register",
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
