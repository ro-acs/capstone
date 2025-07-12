import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PortfolioViewerScreen extends StatelessWidget {
  final String photographerId;
  final String photographerEmail;

  const PortfolioViewerScreen({
    required this.photographerId,
    required this.photographerEmail,
  });

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore _db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(title: Text('$photographerEmail\'s Portfolio')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('portfolio')
            .where('photographerId', isEqualTo: photographerId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());

          final photos = snapshot.data!.docs;

          if (photos.isEmpty) {
            return Center(child: Text('No portfolio images yet.'));
          }

          return GridView.builder(
            padding: EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // 2 images per row
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.8,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final data = photos[index].data() as Map<String, dynamic>;
              final imageUrl = data['imageUrl'] ?? '';
              final caption = data['caption'] ?? '';

              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GridTile(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey,
                      child: Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
                  footer: Container(
                    padding: EdgeInsets.all(6),
                    color: Colors.black.withOpacity(0.6),
                    child: Text(
                      caption,
                      style: TextStyle(color: Colors.white, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
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
