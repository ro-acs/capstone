import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VerifyProfilesScreen extends StatelessWidget {
  const VerifyProfilesScreen({super.key});

  Future<void> verifyPhotographer(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'isVerified': true,
    });
  }

  Future<void> declinePhotographer(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).delete();
  }

  @override
  Widget build(BuildContext context) {
    final photographersRef = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'Photographer')
        .where('isVerified', isEqualTo: false);

    return Scaffold(
      appBar: AppBar(title: const Text("Verify Photographer Profiles")),
      body: StreamBuilder<QuerySnapshot>(
        stream: photographersRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading profiles."));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final pending = snapshot.data!.docs;
          if (pending.isEmpty) {
            return const Center(child: Text("No pending verifications."));
          }

          return ListView.builder(
            itemCount: pending.length,
            itemBuilder: (context, index) {
              final doc = pending[index];
              final data = doc.data() as Map<String, dynamic>;

              return ListTile(
                title: Text(data['name'] ?? 'Unnamed'),
                subtitle: Text(data['email'] ?? ''),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'verify') {
                      await verifyPhotographer(doc.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Photographer verified.")),
                      );
                    } else if (value == 'decline') {
                      await declinePhotographer(doc.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Photographer declined.")),
                      );
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'verify', child: Text("Verify")),
                    const PopupMenuItem(
                      value: 'decline',
                      child: Text("Decline"),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
