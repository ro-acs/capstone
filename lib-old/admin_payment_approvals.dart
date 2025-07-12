import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPaymentApprovalsPage extends StatelessWidget {
  const AdminPaymentApprovalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final pendingPhotographers = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'photographer')
        .where('subscriptionStatus', isEqualTo: 'pending')
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text("Pending Payment Approvals")),
      body: StreamBuilder(
        stream: pendingPhotographers,
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;

          if (docs.isEmpty)
            return const Center(child: Text("No pending payments."));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, index) {
              final user = docs[index].data();
              return Card(
                child: ListTile(
                  title: Text(user['fullName']),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Email: ${user['email']}"),
                      Text("Submitted: ${user['submittedAt'].toDate()}"),
                    ],
                  ),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection("users")
                          .doc(docs[index].id)
                          .update({'subscriptionStatus': 'active'});
                    },
                    child: const Text("Approve"),
                  ),
                  onTap: () {
                    final url = user['paymentProofUrl'];
                    if (url != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(title: const Text("View Proof")),
                            body: Center(child: Image.network(url)),
                          ),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
