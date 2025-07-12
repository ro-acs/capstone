import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ManagePortfolioScreen extends StatefulWidget {
  const ManagePortfolioScreen({super.key});

  @override
  State<ManagePortfolioScreen> createState() => _ManagePortfolioScreenState();
}

class _ManagePortfolioScreenState extends State<ManagePortfolioScreen> {
  final user = FirebaseAuth.instance.currentUser!;
  final TextEditingController descController = TextEditingController();

  Future<void> addPortfolioItem() async {
    String description = descController.text.trim();
    if (description.isEmpty) return;

    await FirebaseFirestore.instance.collection('portfolio').add({
      'photographerId': user.uid,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
    });

    descController.clear();
    Navigator.pop(context);
  }

  Future<void> deletePortfolioItem(String docId) async {
    await FirebaseFirestore.instance
        .collection('portfolio')
        .doc(docId)
        .delete();
  }

  void showAddDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Portfolio Item"),
        content: TextField(
          controller: descController,
          decoration: const InputDecoration(labelText: "Description"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(onPressed: addPortfolioItem, child: const Text("Add")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Portfolio"),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: showAddDialog),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('portfolio')
            .where('photographerId', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final items = snapshot.data!.docs;

          if (items.isEmpty) {
            return const Center(child: Text("No portfolio items yet."));
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final data = items[index].data() as Map<String, dynamic>;
              final docId = items[index].id;

              return ListTile(
                leading: const Icon(Icons.image),
                title: Text(data['description'] ?? 'No description'),
                subtitle: data['timestamp'] != null
                    ? Text((data['timestamp'] as Timestamp).toDate().toString())
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => deletePortfolioItem(docId),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
