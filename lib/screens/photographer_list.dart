import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snapshot/screens/create_booking.dart';

class PhotographerListScreen extends StatelessWidget {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Browse Photographers')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('users')
            .where('role', isEqualTo: 'photographer')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final photographers = snapshot.data?.docs ?? [];
          if (photographers.isEmpty) {
            return Center(child: Text('No photographers found.'));
          }

          return ListView.builder(
            itemCount: photographers.length,
            itemBuilder: (context, index) {
              final photographer = photographers[index];
              final data = photographer.data() as Map<String, dynamic>;
              final profileUrl = data['profileUrl'] ?? '';
              final email = data['email'] ?? 'Photographer';
              final bio = data['bio'] ?? 'No bio available.';

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundImage: profileUrl.isNotEmpty
                        ? NetworkImage(profileUrl)
                        : null,
                    child: profileUrl.isEmpty
                        ? Icon(Icons.person, color: Colors.white)
                        : null,
                    backgroundColor: Colors.deepPurple.shade200,
                  ),
                  title: Text(email),
                  subtitle: Text(
                    bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateBookingScreen(
                          photographerId: photographer.id,
                          photographerEmail: email,
                        ),
                      ),
                    );
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
