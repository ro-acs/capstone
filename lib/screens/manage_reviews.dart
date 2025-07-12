import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ManageReviewsScreen extends StatelessWidget {
  const ManageReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reviewsRef = FirebaseFirestore.instance
        .collection('reviews')
        .orderBy('timestamp', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text("Manage Reviews")),
      body: StreamBuilder<QuerySnapshot>(
        stream: reviewsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading reviews."));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final reviews = snapshot.data!.docs;
          if (reviews.isEmpty) {
            return const Center(child: Text("No reviews found."));
          }

          return ListView.builder(
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final doc = reviews[index];
              final data = doc.data() as Map<String, dynamic>;
              final date = (data['timestamp'] as Timestamp).toDate();

              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(
                    "${data['clientName']} ➤ ${data['photographerName']}",
                  ),
                  subtitle: Text(
                    "Rating: ${data['rating']} ⭐\n" +
                        "${data['comment']}\n" +
                        DateFormat('MMM dd, yyyy – hh:mm a').format(date),
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      await doc.reference.delete();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Review deleted.")),
                      );
                    },
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
