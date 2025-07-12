import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UserReportsScreen extends StatelessWidget {
  const UserReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reportsRef = FirebaseFirestore.instance
        .collection('reports')
        .orderBy('timestamp', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text("User Reports")),
      body: StreamBuilder<QuerySnapshot>(
        stream: reportsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading reports."));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final reports = snapshot.data!.docs;
          if (reports.isEmpty) {
            return const Center(child: Text("No reports found."));
          }

          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final doc = reports[index];
              final data = doc.data() as Map<String, dynamic>;
              final date = (data['timestamp'] as Timestamp).toDate();

              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(
                    "Reported User: ${data['reportedUserName'] ?? 'N/A'}",
                  ),
                  subtitle: Text(
                    "Reason: ${data['reason'] ?? 'N/A'}\nBy: ${data['reporterName'] ?? 'Unknown'}\n${DateFormat('MMM dd, yyyy – hh:mm a').format(date)}",
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    onPressed: () async {
                      await doc.reference.delete();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Report deleted.")),
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
