import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'dashboard_client.dart';
import 'dashboard_photographer.dart';
import 'dashboard_admin.dart';

class CheckEmailVerificationScreen extends StatefulWidget {
  const CheckEmailVerificationScreen({super.key});

  @override
  State<CheckEmailVerificationScreen> createState() =>
      _CheckEmailVerificationScreenState();
}

class _CheckEmailVerificationScreenState
    extends State<CheckEmailVerificationScreen> {
  final user = FirebaseAuth.instance.currentUser!;
  Timer? _checkTimer;
  Timer? _resendTimer;
  bool isVerifying = false;
  int secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    // Start auto-check every 5 seconds
    _checkTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkVerificationStatus(auto: true);
    });
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCooldown() {
    setState(() => secondsRemaining = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsRemaining == 0) {
        timer.cancel();
      } else {
        setState(() => secondsRemaining--);
      }
    });
  }

  Future<void> _resendVerificationEmail() async {
    try {
      await user.sendEmailVerification();
      Fluttertoast.showToast(msg: "Verification email resent to ${user.email}");
      _startResendCooldown();
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to resend verification email.");
    }
  }

  Future<void> _checkVerificationStatus({bool auto = false}) async {
    if (isVerifying) return;
    setState(() => isVerifying = true);

    await user.reload();
    final refreshedUser = FirebaseAuth.instance.currentUser;

    if (refreshedUser != null && refreshedUser.emailVerified) {
      _checkTimer?.cancel();
      _resendTimer?.cancel();
      Fluttertoast.showToast(msg: "Email verified!");

      // Get user role
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(refreshedUser.uid)
          .get();
      final role = userDoc['role'];

      if (!mounted) return;
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
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardAdmin()),
        );
      }
    }

    setState(() => isVerifying = false);

    if (!auto) {
      Fluttertoast.showToast(
        msg: "Email not verified yet. Please check your inbox.",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isResendDisabled = secondsRemaining > 0;

    return Scaffold(
      appBar: AppBar(title: const Text("Verify Your Email")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mark_email_unread, size: 60, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                "A verification email has been sent to your email address.\n\nOnce you've verified it, this screen will auto-continue.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 30),
              if (!isVerifying)
                ElevatedButton.icon(
                  onPressed: _checkVerificationStatus,
                  icon: const Icon(Icons.verified),
                  label: const Text("I've Verified"),
                ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: isResendDisabled ? null : _resendVerificationEmail,
                child: Text(
                  isResendDisabled
                      ? "Resend available in ${secondsRemaining}s"
                      : "Resend Email",
                  style: TextStyle(
                    color: isResendDisabled ? Colors.grey : Colors.blueAccent,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "This screen checks automatically every 5 seconds.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
