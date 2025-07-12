import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PortfolioLikesScreen extends StatefulWidget {
  final String photographerId;
  const PortfolioLikesScreen({super.key, required this.photographerId});

  @override
  State<PortfolioLikesScreen> createState() => _PortfolioLikesScreenState();
}

class _PortfolioLikesScreenState extends State<PortfolioLikesScreen> {
  final user = FirebaseAuth.instance.currentUser!;

  Future<void> toggleLike(String portfolioId) async {
    final docRef = FirebaseFirestore.instance
        .collection('portfolio')
        .doc(portfolioId)
        .collection('likes')
        .doc(user.uid);

    final snapshot = await docRef.get();
    if (snapshot.exists) {
      await docRef.delete();
    } else {
      await docRef.set({'likedAt': Timestamp.now()});
    }
  }

  Future<bool> isLiked(String portfolioId) async {
    final doc = await FirebaseFirestore.instance
        .collection('portfolio')
        .doc(portfolioId)
        .collection('likes')
        .doc(user.uid)
        .get();
    return doc.exists;
  }

  Stream<QuerySnapshot> getPortfolio() {
    return FirebaseFirestore.instance
        .collection('portfolio')
        .where('photographerId', isEqualTo: widget.photographerId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photographer Portfolio')),
      body: StreamBuilder<QuerySnapshot>(
        stream: getPortfolio(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty)
            return const Center(child: Text('No portfolio images yet.'));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final portfolioId = doc.id;

              return Card(
                margin: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Image.network(data['imageUrl']),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(data['caption'] ?? ''),
                    ),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('portfolio')
                          .doc(portfolioId)
                          .collection('likes')
                          .snapshots(),
                      builder: (context, snapshot) {
                        final likeCount = snapshot.data?.docs.length ?? 0;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('❤️ $likeCount likes'),
                            IconButton(
                              icon: const Icon(Icons.favorite_border),
                              onPressed: () => toggleLike(portfolioId),
                            ),
                          ],
                        );
                      },
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
