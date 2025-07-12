import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ScheduledBookingsScreen extends StatelessWidget {
  const ScheduledBookingsScreen({super.key});

  void markAsCompleted(BuildContext context, String bookingId) async {
    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .update({'status': 'completed'});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Booking marked as completed")),
    );
  }

  void confirmMarkCompleted(BuildContext context, String bookingId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Mark as Completed"),
        content: const Text("Are you sure you want to mark this booking as completed?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              markAsCompleted(context, bookingId);
            },
            child: const Text("Yes, Complete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String currentPhotographerId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text("Scheduled Bookings")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('photographerId', isEqualTo: currentPhotographerId)
            .where('status', isEqualTo: 'accepted')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final bookings = snapshot.data!.docs;

          if (bookings.isEmpty) {
            return const Center(child: Text("No scheduled bookings."));
          }

          return ListView.builder(
            itemCount: bookings.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              final data = bookings[index].data() as Map<String, dynamic>;
              final bookingId = bookings[index].id;
              final clientName = data['clientName'] ?? 'Client';
              final service = data['service'] ?? 'Service';
              final date = (data['date'] as Timestamp).toDate();
              final formattedDate = DateFormat.yMMMd().add_jm().format(date);

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.calendar_today, color: Colors.deepPurple),
                  title: Text("$clientName - $service"),
                  subtitle: Text("Scheduled for: $formattedDate"),
                  trailing: ElevatedButton.icon(
                    onPressed: () => confirmMarkCompleted(context, bookingId),
                    icon: const Icon(Icons.check),
                    label: const Text("Complete"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
