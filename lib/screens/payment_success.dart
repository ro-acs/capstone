import 'dart:async';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'dashboard_client.dart';
import 'dashboard_photographer.dart';
import 'dashboard_admin.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final String contextType; // 'booking' or 'registration'

  const PaymentSuccessScreen({super.key, required this.contextType});

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  int countdown = 3;
  late Timer _timer;
  late ConfettiController _confettiController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _startConfettiAndSound();
    _startCountdownAndRedirect();
  }

  void _startConfettiAndSound() async {
    _confettiController.play();
    await _audioPlayer.play(AssetSource('success.mp3'));
  }

  void _startCountdownAndRedirect() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (countdown <= 1) {
        timer.cancel();
        await _redirectToDashboard();
      } else {
        setState(() {
          countdown--;
        });
      }
    });
  }

  Future<void> _redirectToDashboard() async {
    if (widget.contextType == 'booking') {
      Navigator.popUntil(context, (route) => route.isFirst);
    } else {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final role = doc.data()?['role'];

      Widget destination;
      if (role == 'Photographer') {
        destination = const DashboardPhotographer();
      } else if (role == 'Client') {
        destination = const DashboardClient();
      } else if (role == 'Admin') {
        destination = const DashboardAdmin();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Unknown user role.")));
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => destination),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _confettiController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Payment Successful"),
        backgroundColor: Colors.green,
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 100,
                  color: Colors.green,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Thank you for your payment!",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  widget.contextType == 'booking'
                      ? "Your booking has been successfully paid and is now pending confirmation."
                      : "Your registration payment was successful. Welcome aboard!",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  "Redirecting to dashboard in $countdown...",
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  icon: const Icon(Icons.home),
                  label: const Text("Go to Dashboard Now"),
                  onPressed: _redirectToDashboard,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 🎉 Confetti Animation
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            emissionFrequency: 0.05,
            numberOfParticles: 20,
            gravity: 0.2,
          ),
        ],
      ),
    );
  }
}
