import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CompletedBookingsScreen extends StatelessWidget {
  const CompletedBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String currentPhotographerId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text("Completed Bookings")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('photographerId', isEqualTo: currentPhotographerId)
            .where('status', isEqualTo: 'completed')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final bookings = snapshot.data!.docs;

          if (bookings.isEmpty) {
            return const Center(child: Text("No completed bookings."));
          }

          return ListView.builder(
            itemCount: bookings.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              final data = bookings[index].data() as Map<String, dynamic>;
              final clientName = data['clientName'] ?? 'Client';
              final service = data['service'] ?? 'Service';
              final date = (data['date'] as Timestamp).toDate();
              final formattedDate = DateFormat.yMMMd().add_jm().format(date);
              final rating = data['rating']?.toString() ?? 'Unrated';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.done_all, color: Colors.blue),
                  title: Text("$clientName - $service"),
                  subtitle: Text(
                    "Completed on: $formattedDate\nRating: $rating ★",
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
