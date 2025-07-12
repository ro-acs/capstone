import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ConfirmPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> args;

  const ConfirmPaymentScreen({super.key, required this.args});

  @override
  State<ConfirmPaymentScreen> createState() => _ConfirmPaymentScreenState();
}

class _ConfirmPaymentScreenState extends State<ConfirmPaymentScreen> {
  bool isProcessing = true;

  @override
  void initState() {
    super.initState();
    _confirmPayment();
  }

  Future<void> _confirmPayment() async {
    final args = widget.args;
    final bookingRef = FirebaseFirestore.instance
        .collection('bookings')
        .doc(args['bookingId']);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snapshot = await tx.get(bookingRef);
        final data = snapshot.data()!;
        final double finalPrice = (data['finalPrice'] as num).toDouble();

        List<dynamic> history = List.from(data['partialPayment'] ?? []);
        double paidTotal = history
            .fold<num>(0, (sum, h) => sum + (h['price'] as num))
            .toDouble();
        double amount = (args['amount'] as num).toDouble();

        history.add({
          'price': amount,
          'date': Timestamp.now(),
          'note': args['note'] ?? '',
          'method': args['method'],
        });

        final isFullyPaid = paidTotal + amount >= finalPrice;

        tx.update(bookingRef, {
          'partialPayment': history,
          'isPaid': isFullyPaid,
          'status': isFullyPaid ? 'Paid' : data['status'],
        });
      });

      Fluttertoast.showToast(msg: "Payment confirmed!");
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to confirm payment: $e");
    } finally {
      setState(() => isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Confirming Payment..."),
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: isProcessing
            ? const CircularProgressIndicator()
            : ElevatedButton.icon(
                onPressed: () => Navigator.popUntil(
                  context,
                  ModalRoute.withName('/my_booking_screen'),
                ),
                icon: const Icon(Icons.check),
                label: const Text("Return to Bookings"),
              ),
      ),
    );
  }
}
