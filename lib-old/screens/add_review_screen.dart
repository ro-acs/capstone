import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddReviewScreen extends StatefulWidget {
  final String photographerId;
  final String photographerName;
  final String? bookingId;

  const AddReviewScreen({
    super.key,
    required this.photographerId,
    required this.photographerName,
    this.bookingId,
  });

  @override
  State<AddReviewScreen> createState() => _AddReviewScreenState();
}

class _AddReviewScreenState extends State<AddReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  double _rating = 0;
  bool _isSubmitting = false;

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate() || _rating == 0) return;

    setState(() => _isSubmitting = true);

    final user = FirebaseAuth.instance.currentUser!;
    final reviewerDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final reviewerName = reviewerDoc.data()?['name'] ?? 'Anonymous';

    final reviewData = {
      'clientId': user.uid,
      'photographerId': widget.photographerId,
      'photographerName': widget.photographerName,
      'reviewerName': reviewerName,
      'comment': _commentController.text.trim(),
      'rating': _rating,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance.collection('reviews').add(reviewData);

    if (widget.bookingId != null) {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .update({'reviewSubmitted': true, 'rating': _rating});
    }

    setState(() => _isSubmitting = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Thank you for your review!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Review ${widget.photographerName}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your Rating', style: TextStyle(fontSize: 18)),
              Slider(
                value: _rating,
                min: 0,
                max: 5,
                divisions: 5,
                label: _rating.toString(),
                onChanged: (value) => setState(() => _rating = value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _commentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Comment',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a comment.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Submit Review'),
                  onPressed: _isSubmitting ? null : _submitReview,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
