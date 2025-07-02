import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'photographer_details_screen.dart';

class BrowsePhotographersScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('photographers')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Something went wrong"));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final photographers = snapshot.data!.docs;

        if (photographers.isEmpty) {
          return Center(child: Text("No photographers available"));
        }

        return ListView.builder(
          padding: EdgeInsets.all(12),
          itemCount: photographers.length,
          itemBuilder: (context, index) {
            var data = photographers[index].data() as Map<String, dynamic>;

            return PhotographerCard(
              name: data['name'] ?? 'No Name',
              location: data['location'] ?? 'Unknown',
              profileUrl: data['profileImageUrl'] ?? '',
              specialty: data['specialty'] ?? 'General',
              photographerId: photographers[index].id,
            );
          },
        );
      },
    );
  }
}

class PhotographerCard extends StatelessWidget {
  final String name;
  final String location;
  final String profileUrl;
  final String specialty;
  final String photographerId;

  PhotographerCard({
    required this.name,
    required this.location,
    required this.profileUrl,
    required this.specialty,
    required this.photographerId,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: profileUrl.isNotEmpty
              ? NetworkImage(profileUrl)
              : AssetImage('assets/default_user.png') as ImageProvider,
          radius: 28,
        ),
        title: Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$specialty • $location'),
        trailing: Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  PhotographerDetailsScreen(photographerId: photographerId),
            ),
          );
        },
      ),
    );
  }
}
