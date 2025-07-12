import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:confetti/confetti.dart';

import 'dashboard_client.dart';
import 'dashboard_photographer.dart';
import 'dashboard_admin.dart';
import 'payment_success_screen.dart';

class GCashWebViewPaymentScreen extends StatefulWidget {
  final String paymentUrl;
  final String contextType; // 'booking' or 'registration'
  final String referenceId; // bookingId or user.uid
  final double amount;
  final String note;

  const GCashWebViewPaymentScreen({
    super.key,
    required this.paymentUrl,
    required this.contextType,
    required this.referenceId,
    required this.amount,
    this.note = '',
  });

  @override
  State<GCashWebViewPaymentScreen> createState() =>
      _GCashWebViewPaymentScreenState();
}

class _GCashWebViewPaymentScreenState extends State<GCashWebViewPaymentScreen> {
  bool isLoading = true;
  bool paymentHandled = false;
  late final WebViewController _controller;
  final user = FirebaseAuth.instance.currentUser!;
  final ConfettiController _confettiController = ConfettiController(
    duration: const Duration(seconds: 3),
  );

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            setState(() => isLoading = false);
          },
          onNavigationRequest: (request) {
            final url = request.url;

            if (!paymentHandled &&
                (url.contains("payment-success") || url.contains("success"))) {
              paymentHandled = true;
              _handleSuccessPayment();
              return NavigationDecision.prevent;
            }

            if (!paymentHandled &&
                (url.contains("payment-failed") || url.contains("cancel"))) {
              paymentHandled = true;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("❌ Payment was cancelled or failed."),
                ),
              );
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  Future<void> _handleSuccessPayment() async {
    _confettiController.play();
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    if (widget.contextType == 'booking') {
      final bookingRef = FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.referenceId);

      final receiptId = FirebaseFirestore.instance
          .collection('receipts')
          .doc()
          .id;
      final paymentTimestamp = Timestamp.now();

      String photographerId = '';

      try {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          // 🔍 READ FIRST
          final bookingSnap = await transaction.get(bookingRef);
          if (!bookingSnap.exists) throw Exception("Booking not found.");

          final bookingData = bookingSnap.data()!;
          photographerId = bookingData['photographerId'];

          final photographerRef = FirebaseFirestore.instance
              .collection('users')
              .doc(photographerId);
          final photographerSnap = await transaction.get(photographerRef);

          // 🔍 PREPARE DATA
          final List<dynamic> paymentHistory = List.from(
            bookingData['partialPayment'] ?? [],
          );
          final double currentPaid = paymentHistory
              .fold<num>(0, (sum, item) => sum + (item['price'] as num))
              .toDouble();
          final newPaid = currentPaid + widget.amount;
          final isFullyPaid = newPaid >= (bookingData['finalPrice'] as num);

          final currentBalance = (photographerSnap.data()?['balance'] ?? 0)
              .toDouble();
          final updatedBalance = currentBalance + widget.amount;

          // ✅ THEN DO WRITES
          paymentHistory.add({
            'price': widget.amount,
            'date': paymentTimestamp,
            'note': widget.note,
            'method': 'GCash',
            'receiptId': receiptId,
          });

          transaction.update(bookingRef, {
            'partialPayment': paymentHistory,
            'isPaid': isFullyPaid,
            'status': isFullyPaid ? 'Completed' : bookingData['status'],
          });

          transaction.update(photographerRef, {'balance': updatedBalance});
        });

        // ✅ Write receipt AFTER transaction
        await FirebaseFirestore.instance
            .collection('receipts')
            .doc(receiptId)
            .set({
              'bookingId': widget.referenceId,
              'amount': widget.amount,
              'note': widget.note,
              'method': 'GCash',
              'timestamp': paymentTimestamp,
              'clientId': user.uid,
              'photographerId': photographerId,
            });

        // ✅ Navigate to success screen
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentSuccessScreen(
              contextType: 'booking',
              receiptId: receiptId,
              bookingId: widget.referenceId,
              amount: widget.amount,
              timestamp: paymentTimestamp.toDate(),
            ),
          ),
        );
      } catch (e) {
        debugPrint("❌ Error updating Firestore: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("❌ Failed to record payment.")),
          );
          Navigator.pop(context);
        }
      }
    } else {
      // Registration logic (unchanged)
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.referenceId)
            .update({
              'isPaid': true,
              'paymentMethod': 'GCash',
              'paidAt': Timestamp.now(),
            });

        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.referenceId)
            .get();

        final role = doc['role'];
        Widget dashboard;

        if (role == 'Photographer') {
          dashboard = const DashboardPhotographer();
        } else if (role == 'Client') {
          dashboard = const DashboardClient();
        } else if (role == 'Admin') {
          dashboard = const DashboardAdmin();
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('❌ Unknown role')));
          return;
        }

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => dashboard),
          (route) => false,
        );
      } catch (e) {
        debugPrint("Error updating registration payment: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Failed to update payment status.")),
        );
      }
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("GCash Payment")),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (isLoading) const Center(child: CircularProgressIndicator()),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 3.14 / 2,
              shouldLoop: false,
              emissionFrequency: 0.08,
              numberOfParticles: 20,
              maxBlastForce: 20,
              minBlastForce: 5,
            ),
          ),
        ],
      ),
    );
  }
}
