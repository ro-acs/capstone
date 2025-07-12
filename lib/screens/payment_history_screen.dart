import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentHistoryScreen extends StatelessWidget {
  final String bookingId;

  const PaymentHistoryScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Payment History"),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final data = snap.data!.data()!;
          final history = List.from(data['partialPayment'] ?? []);
          if (history.isEmpty)
            return const Center(child: Text("No payments yet."));

          return ListView.builder(
            itemCount: history.length,
            itemBuilder: (ctx, i) {
              final entry = history[i];
              final payDate = (entry['date'] as Timestamp).toDate();
              return ListTile(
                title: Text("₱${(entry['price'] as num).toStringAsFixed(2)}"),
                subtitle: Text(
                  "${entry['method'] ?? ''} • ${payDate.toLocal()}",
                ),
                trailing: Icon(Icons.receipt, color: Colors.deepPurple),
                onTap: () => Navigator.pushNamed(
                  context,
                  '/payment_receipt',
                  arguments: {'bookingId': bookingId, 'index': i},
                ),
              );
            },
          );
        },
      ),
    );
  }
}
