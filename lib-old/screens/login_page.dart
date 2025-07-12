import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'payment_screen.dart';
import '/services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool _obscurePassword = true;

  void loginUser() async {
    setState(() => isLoading = true);
    try {
      final authResult = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final uid = authResult.user!.uid;
      final userDoc = await FirebaseFirestore.instance
          .collection('tblusers')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        Fluttertoast.showToast(msg: "User not found in database");
        await FirebaseAuth.instance.signOut();
        return;
      }

      final role = userDoc['role'];
      final status = userDoc['status'] ?? 'none';

      if (role == 'photographer' && status != 'active') {
        final photographerDoc = await FirebaseFirestore.instance
            .collection('tblsubscription')
            .doc(uid)
            .get();

        final role = photographerDoc['role'];
        final paymentMethod = photographerDoc['payment_method'];

        if (paymentMethod == 'gcash' || paymentMethod == 'paypal') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  PaymentSuccessScreen(userId: uid, contextMode: 'register'),
            ),
          );
        } else {
          Fluttertoast.showToast(msg: "No payment method selected.");
          await FirebaseAuth.instance.signOut();
        }
        return;
      }

      Fluttertoast.showToast(msg: "Logged in as $role");
      final idToken = await authResult.user!.getIdToken();
      if (role == 'client') {
        Navigator.pushReplacementNamed(context, '/client_dashboard');
      } else if (role == 'photographer' || role == 'admin') {
        final url = Uri.parse(
          "http://capstone.x10.mx/capstone/auth/verify-token?token=$idToken",
        );
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          Fluttertoast.showToast(msg: "Cannot launch web dashboard.");
        }
      } else {
        Fluttertoast.showToast(msg: "Unknown user role.");
      }
    } on FirebaseAuthException catch (e) {
      Fluttertoast.showToast(msg: e.message ?? "Login failed");
    } catch (e) {
      Fluttertoast.showToast(msg: "Something went wrong");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void showForgotPasswordDialog() {
    final resetEmailController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Forgot Password"),
        content: TextField(
          controller: resetEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: "Enter your email"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = resetEmailController.text.trim();
              Navigator.pop(ctx);
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(
                  email: email,
                );
                Fluttertoast.showToast(msg: "Reset link sent to $email");
              } catch (e) {
                Fluttertoast.showToast(
                  msg: "Failed to send reset link: ${e.toString()}",
                );
              }
            },
            child: const Text("Send"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple[50],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            children: [
              const Icon(Icons.camera_alt, size: 80, color: Colors.deepPurple),
              const SizedBox(height: 20),
              const Text(
                "Welcome to SnapSpot",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Login to continue",
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: "Email",
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: "Password",
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: showForgotPasswordDialog,
                  child: const Text("Forgot Password?"),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : loginUser,
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
                      : const Text("Login", style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, "/register"),
                child: const Text("Don't have an account? Register"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
