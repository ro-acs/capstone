import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PhotographerDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> photographer;

  const PhotographerDetailsScreen({super.key, required this.photographer});

  @override
  Widget build(BuildContext context) {
    final name = photographer['name'] ?? 'Photographer';
    final location = photographer['location'] ?? 'Unknown';
    final photoUrl = photographer['photoUrl'];
    final services = List<Map<String, dynamic>>.from(
      photographer['services'] ?? [],
    );
    final email = photographer['email'] ?? 'Not available';
    final phone = photographer['phone'] ?? 'Not available';
    final gallery = List<String>.from(photographer['gallery'] ?? []);
    final bio = photographer['bio'] ?? 'No biography available.';
    final photographerId = photographer['id'];

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        backgroundColor: const Color(0xFF7F00FF),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: photoUrl != null
                        ? NetworkImage(photoUrl)
                        : const AssetImage('assets/avatar_placeholder.png')
                              as ImageProvider,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(location, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(photographer['id'])
                        .collection('reviews')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Text("No ratings yet");
                      }

                      final docs = snapshot.data!.docs;
                      final ratings = docs
                          .map((doc) => (doc['rating'] ?? 0).toDouble())
                          .toList();
                      final avgRating =
                          ratings.reduce((a, b) => a + b) / ratings.length;

                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              5,
                              (i) => Icon(
                                i < avgRating.round()
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${avgRating.toStringAsFixed(1)} ★ from ${docs.length} reviews',
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'About',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(bio, textAlign: TextAlign.justify),
            const SizedBox(height: 24),
            const Text(
              'Contact',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListTile(leading: const Icon(Icons.email), title: Text(email)),
            ListTile(leading: const Icon(Icons.phone), title: Text(phone)),
            const SizedBox(height: 24),
            const Text(
              'Services',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...services.map(
              (s) => Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text(s['serviceName'] ?? 'Service'),
                  subtitle: Text(s['description'] ?? 'No description provided'),
                  trailing: Text('₱${s['price']}'),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (gallery.isNotEmpty) ...[
              const Text(
                'Gallery',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: gallery.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              FullscreenImageViewer(imageUrl: gallery[i]),
                        ),
                      ),
                      child: Image.network(
                        gallery[i],
                        width: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            _buildPortfolio(photographerId),
            const SizedBox(height: 24),
            _buildReviewsSection(photographerId),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.chat),
                  label: const Text("Chat"),
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/chat',
                      arguments: photographerId,
                    );
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.rate_review),
                  label: const Text("Review"),
                  onPressed: () => _showReviewDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.pushNamed(
              context,
              '/book_photographer',
              arguments: photographerId,
            );
          },
          icon: const Icon(Icons.calendar_today),
          label: const Text('Book Now'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPortfolio(String photographerId) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('portfolio')
          .where('photographerId', isEqualTo: photographerId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text("No portfolio images.");
        }

        final imageUrls = snapshot.data!.docs
            .map((doc) => doc['imageUrl'] as String)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Portfolio",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: imageUrls.length,
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            FullscreenImageViewer(imageUrl: imageUrls[index]),
                      ),
                    ),
                    child: Image.network(
                      imageUrls[index],
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                separatorBuilder: (_, __) => const SizedBox(width: 8),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReviewsSection(String photographerId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(photographerId)
          .collection('reviews')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final reviews = snapshot.data!.docs;

        if (reviews.isEmpty) return const Text("No reviews yet.");

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reviews',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...reviews.map((r) {
              final data = r.data() as Map<String, dynamic>;
              final rating = (data['rating'] ?? 0).toDouble();
              final comment = data['comment'] ?? '';
              final user = data['userName'] ?? 'Anonymous';
              return ListTile(
                leading: Icon(Icons.star, color: Colors.amber),
                title: Text(comment),
                subtitle: Text('$user • $rating ★'),
              );
            }),
          ],
        );
      },
    );
  }

  void _showReviewDialog(BuildContext context) {
    final _commentController = TextEditingController();
    double _selectedRating = 5;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text("Leave a Review"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("How was your experience?"),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 5,
                  children: List.generate(
                    5,
                    (index) => IconButton(
                      icon: Icon(
                        index < _selectedRating
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber,
                        size: 25,
                      ),
                      onPressed: () =>
                          setState(() => _selectedRating = index + 1),
                    ),
                  ),
                ),
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: "Your review...",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              child: const Text("Submit"),
              onPressed: () async {
                final comment = _commentController.text.trim();
                final userId =
                    FirebaseAuth.instance.currentUser?.uid ?? 'guest';
                final docId = photographer['id'];
                final userDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .get();
                final userName = userDoc.data()?['name'] ?? 'Anonymous';

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(docId)
                    .collection('reviews')
                    .add({
                      'user': userId,
                      'rating': _selectedRating,
                      'userName': userName,
                      'comment': comment,
                      'timestamp': FieldValue.serverTimestamp(),
                    });

                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Review submitted")),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class FullscreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const FullscreenImageViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: Hero(tag: imageUrl, child: Image.network(imageUrl)),
        ),
      ),
    );
  }
}
