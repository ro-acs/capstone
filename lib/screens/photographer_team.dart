import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PhotographerTeamScreen extends StatelessWidget {
  final String teamId;
  const PhotographerTeamScreen({super.key, required this.teamId});

  @override
  Widget build(BuildContext context) {
    final teamMembersRef = FirebaseFirestore.instance
        .collection('users')
        .where('teamId', isEqualTo: teamId)
        .where('role', isEqualTo: 'Photographer');

    final teamServicesRef = FirebaseFirestore.instance
        .collection('services')
        .where('teamId', isEqualTo: teamId);

    return Scaffold(
      appBar: AppBar(title: const Text("Photographer Team")),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              "Team Members",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: teamMembersRef.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final members = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final data = members[index].data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(data['name'] ?? 'Unnamed'),
                      subtitle: Text(data['location'] ?? ''),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              "Team Services",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: teamServicesRef.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final services = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: services.length,
                  itemBuilder: (context, index) {
                    final data = services[index].data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(data['serviceName'] ?? 'No Name'),
                      subtitle: Text(data['description'] ?? ''),
                      trailing: Text('₱${data['price'] ?? 0}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
