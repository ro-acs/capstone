// Make sure these packages are in pubspec.yaml:
// cloud_firestore, firebase_auth, firebase_storage, image_picker, flutter_rating_bar

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ReviewPhotographerScreen extends StatefulWidget {
  final String photographerId;
  const ReviewPhotographerScreen({super.key, required this.photographerId});

  @override
  State<ReviewPhotographerScreen> createState() =>
      _ReviewPhotographerScreenState();
}

class _ReviewPhotographerScreenState extends State<ReviewPhotographerScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  double _rating = 3;
  final _reviewController = TextEditingController();
  List<XFile> _attachedImages = [];
  bool _showForm = false;
  bool _canReview = false;
  String? _currentReviewId;
  String _sortBy = 'timestamp'; // or 'rating'

  @override
  void initState() {
    super.initState();
    _checkBookingEligibility();
  }

  Future<void> _checkBookingEligibility() async {
    final uid = _auth.currentUser?.uid;
    final bookings = await _firestore
        .collection('bookings')
        .where('clientId', isEqualTo: uid)
        .where('photographerId', isEqualTo: widget.photographerId)
        .where('status', isEqualTo: 'completed')
        .get();
    setState(() {
      _canReview = bookings.docs.isNotEmpty;
    });
  }

  Future<List<String>> _uploadImages(List<XFile> files) async {
    final uid = _auth.currentUser!.uid;
    List<String> urls = [];
    for (var file in files) {
      final ref = _storage.ref().child(
        'review_images/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await ref.putFile(File(file.path));
      final url = await ref.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }

  Future<void> _submitReview() async {
    final uid = _auth.currentUser!.uid;
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final reviewerName = userDoc['fullName'] ?? 'Anonymous';
    final reviewerAvatar = userDoc['photoUrl'] ?? '';

    List<String> imageUrls = [];
    if (_attachedImages.isNotEmpty) {
      imageUrls = await _uploadImages(_attachedImages);
    }

    final data = {
      'photographerId': widget.photographerId,
      'reviewerId': uid,
      'reviewerName': reviewerName,
      'reviewerAvatar': reviewerAvatar,
      'reviewText': _reviewController.text.trim(),
      'rating': _rating,
      'imageUrls': imageUrls,
      'timestamp': FieldValue.serverTimestamp(),
    };

    if (_currentReviewId != null) {
      await _firestore.collection('reviews').doc(_currentReviewId).update(data);
    } else {
      await _firestore.collection('reviews').add(data);
    }

    setState(() {
      _showForm = false;
      _reviewController.clear();
      _rating = 3;
      _attachedImages.clear();
      _currentReviewId = null;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Review submitted.")));
  }

  void _editReview(DocumentSnapshot doc) {
    setState(() {
      _reviewController.text = doc['reviewText'];
      _rating = (doc['rating'] ?? 3).toDouble();
      _currentReviewId = doc.id;
      _showForm = true;
    });
  }

  Future<void> _deleteReview(String id) async {
    await _firestore.collection('reviews').doc(id).delete();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Review deleted.")));
  }

  Widget _buildReviewForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                "Your Review",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () => setState(() => _showForm = false),
              ),
            ],
          ),
          Slider(
            value: _rating,
            min: 1,
            max: 5,
            divisions: 4,
            label: _rating.toString(),
            onChanged: (val) => setState(() => _rating = val),
          ),
          TextField(
            controller: _reviewController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Write your experience...",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _attachedImages
                .map(
                  (file) => Stack(
                    children: [
                      Image.file(
                        File(file.path),
                        height: 80,
                        width: 80,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _attachedImages.remove(file)),
                          child: const CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.red,
                            child: Icon(Icons.close, size: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
          Row(
            children: [
              TextButton.icon(
                icon: Icon(Icons.add_photo_alternate),
                label: Text("Attach"),
                onPressed: () async {
                  final picker = await ImagePicker().pickMultiImage();
                  if (picker != null) {
                    setState(() => _attachedImages.addAll(picker));
                  }
                },
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: Icon(Icons.send),
                label: Text("Submit"),
                onPressed: _submitReview,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _starDisplay(double rating) {
    return Row(
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 16,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Photographer Reviews"),
        actions: [
          PopupMenuButton<String>(
            onSelected: (val) => setState(() => _sortBy = val),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'timestamp', child: Text('Newest')),
              const PopupMenuItem(value: 'rating', child: Text('Top Rated')),
            ],
          ),
        ],
      ),
      floatingActionButton: _canReview
          ? FloatingActionButton.extended(
              onPressed: () => setState(() => _showForm = true),
              icon: Icon(Icons.rate_review),
              label: Text("Write Review"),
            )
          : null,
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('reviews')
                .where('photographerId', isEqualTo: widget.photographerId)
                .orderBy(_sortBy, descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return Center(child: CircularProgressIndicator());

              final reviews = snapshot.data!.docs;

              if (reviews.isEmpty)
                return Center(child: Text("No reviews yet."));

              return ListView(
                padding: const EdgeInsets.all(12),
                children: reviews.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final isMine = data['reviewerId'] == uid;
                  final images = List<String>.from(data['imageUrls'] ?? []);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundImage: data['reviewerAvatar'] != null
                                    ? NetworkImage(data['reviewerAvatar'])
                                    : null,
                                child: data['reviewerAvatar'] == null
                                    ? Icon(Icons.person)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['reviewerName'] ?? "User",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        _starDisplay(
                                          (data['rating'] ?? 0).toDouble(),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(
                                          Icons.verified,
                                          size: 14,
                                          color: Colors.green,
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          "Verified",
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (isMine)
                                PopupMenuButton(
                                  onSelected: (val) {
                                    if (val == 'edit')
                                      _editReview(doc);
                                    else if (val == 'delete')
                                      _deleteReview(doc.id);
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(data['reviewText'] ?? ''),
                          if (images.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: images
                                    .map(
                                      (url) => GestureDetector(
                                        onTap: () => showDialog(
                                          context: context,
                                          builder: (_) =>
                                              Dialog(child: Image.network(url)),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.network(
                                            url,
                                            height: 80,
                                            width: 80,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          if (_showForm)
            Align(alignment: Alignment.bottomCenter, child: _buildReviewForm()),
        ],
      ),
    );
  }
}
