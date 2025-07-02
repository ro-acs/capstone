import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PhotographerDetailsScreen extends StatelessWidget {
  final String photographerId;

  const PhotographerDetailsScreen({required this.photographerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Photographer Profile"),
        backgroundColor: Colors.indigo,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('photographers')
            .doc(photographerId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error loading profile."));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.data!.exists) {
            return Center(child: Text("Photographer not found."));
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 60,
                    backgroundImage:
                        data['profileImageUrl'] != null &&
                            data['profileImageUrl'] != ''
                        ? NetworkImage(data['profileImageUrl'])
                        : AssetImage('assets/default_user.png')
                              as ImageProvider,
                  ),
                ),
                SizedBox(height: 16),

                Center(
                  child: Text(
                    data['name'] ?? 'Unnamed',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(height: 8),

                Center(
                  child: Text(
                    "${data['specialty'] ?? 'Photography'} • ${data['location'] ?? 'Unknown'}",
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
                SizedBox(height: 24),

                Text(
                  "About Photographer",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  data['bio'] ?? 'No bio provided.',
                  style: TextStyle(fontSize: 15),
                ),
                SizedBox(height: 24),

                Text(
                  "Portfolio",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),

                data.containsKey('portfolioImages') &&
                        data['portfolioImages'] is List &&
                        (data['portfolioImages'] as List).isNotEmpty
                    ? SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: (data['portfolioImages'] as List).length,
                          itemBuilder: (context, index) {
                            String imageUrl =
                                data['portfolioImages'][index] ?? '';
                            return Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  imageUrl,
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(Icons.broken_image),
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    : Text("No portfolio uploaded."),
                SizedBox(height: 32),

                Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // You can route to booking screen here
                      // Navigator.push(context, MaterialPageRoute(builder: (_) => BookingScreen(photographerId: photographerId)));
                    },
                    icon: Icon(Icons.calendar_today),
                    label: Text("Book Now"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      padding: EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
