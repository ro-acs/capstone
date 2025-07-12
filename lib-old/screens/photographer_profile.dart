import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class PhotographerProfileScreen extends StatelessWidget {
  final String photographerId;

  const PhotographerProfileScreen({required this.photographerId, Key? key})
    : super(key: key);

  String getChatId(String uid1, String uid2) {
    List<String> uids = [uid1, uid2];
    uids.sort();
    return '${uids[0]}_${uids[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photographer Profile')),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(photographerId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Photographer not found.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final name = data['fullName'] ?? 'No Name';
          final bio = data['bio'] ?? 'No bio available.';
          final location = data['location'] ?? '';
          final profilePicture = data['avatarUrl'] ?? '';
          final portfolio = List<String>.from(data['portfolio'] ?? []);
          final packages = List<Map<String, dynamic>>.from(
            data['packages'] ?? [],
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 60,
                    backgroundImage: profilePicture.isNotEmpty
                        ? NetworkImage(profilePicture)
                        : const AssetImage('assets/images/default_profile.png')
                              as ImageProvider,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (location.isNotEmpty)
                  Center(
                    child: Text(
                      location,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                const SizedBox(height: 16),
                _buildAverageRating(photographerId),
                const SizedBox(height: 16),
                Text('About', style: Theme.of(context).textTheme.titleLarge),
                Text(bio),
                const SizedBox(height: 16),
                Text(
                  'Portfolio',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                _buildPortfolio(portfolio),
                const SizedBox(height: 16),
                Text('Packages', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                _buildPackages(packages),
                const SizedBox(height: 16),
                Text('Reviews', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                _buildReviews(photographerId),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.message),
                      label: const Text('Message'),
                      onPressed: () {
                        final currentUser = FirebaseAuth.instance.currentUser!;
                        final chatId = getChatId(
                          currentUser.uid,
                          photographerId,
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              chatId: chatId,
                              receiverId: photographerId,
                              receiverName: name,
                              receiverAvatar: profilePicture,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: const Text('Book Now'),
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/book_session',
                          arguments: photographerId,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAverageRating(String photographerId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('photographerId', isEqualTo: photographerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text('⭐ No ratings yet.');
        }

        final ratings = snapshot.data!.docs
            .map((doc) => (doc['rating'] ?? 0).toDouble())
            .whereType<double>()
            .toList();

        final avg = ratings.reduce((a, b) => a + b) / ratings.length;
        final avgStr = avg.toStringAsFixed(1);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.star, color: Colors.amber),
            const SizedBox(width: 4),
            Text('$avgStr / 5.0 from ${ratings.length} review(s)'),
            if (avg >= 4.5)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Tooltip(
                  message: 'Top Rated',
                  child: Icon(Icons.verified, color: Colors.amber, size: 18),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPortfolio(List<String> portfolio) {
    if (portfolio.isEmpty) return const Text('No portfolio images.');

    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: portfolio.length,
        separatorBuilder: (context, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              portfolio[index],
              width: 150,
              height: 150,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPackages(List<Map<String, dynamic>> packages) {
    if (packages.isEmpty) return const Text('No available packages.');

    return Column(
      children: packages.map((pkg) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            title: Text(pkg['name'] ?? 'Package'),
            subtitle: Text(pkg['description'] ?? ''),
            trailing: Text('₱${pkg['price']?.toString() ?? '0'}'),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReviews(String photographerId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('photographerId', isEqualTo: photographerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text('No reviews yet.');
        }

        final reviews = snapshot.data!.docs;

        return Column(
          children: reviews.map((doc) {
            final review = doc.data() as Map<String, dynamic>;
            return ListTile(
              leading: const Icon(Icons.person),
              title: Text(review['reviewerName'] ?? 'Anonymous'),
              subtitle: Text(review['comment'] ?? ''),
              trailing: Text('${review['rating'] ?? 0}/5'),
            );
          }).toList(),
        );
      },
    );
  }
}
