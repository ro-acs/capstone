import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminManageServicesScreen extends StatelessWidget {
  const AdminManageServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final servicesRef = FirebaseFirestore.instance
        .collection('services')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text("All Services (Admin)")),
      body: StreamBuilder<QuerySnapshot>(
        stream: servicesRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Center(child: Text("Error loading services."));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final services = snapshot.data!.docs;
          if (services.isEmpty)
            return const Center(child: Text("No services available."));

          return ListView.builder(
            itemCount: services.length,
            itemBuilder: (context, index) {
              final doc = services[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(doc['serviceName']),
                  subtitle: Text(
                    '${doc['description']}\n₱${doc['price']} • ${doc['category']}',
                  ),
                  trailing: Text(doc['isAvailable'] ? '✅' : '❌'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
