import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class PaymentProofUploadPage extends StatefulWidget {
  final String bookingId;
  final String photographerId;

  const PaymentProofUploadPage({
    super.key,
    required this.bookingId,
    required this.photographerId,
  });

  @override
  State<PaymentProofUploadPage> createState() => _PaymentProofUploadPageState();
}

class _PaymentProofUploadPageState extends State<PaymentProofUploadPage> {
  File? _image;
  bool _isUploading = false;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 75);
    if (picked != null) {
      setState(() => _image = File(picked.path));
    }
  }

  Future<void> _uploadProof() async {
    if (_image == null) return;
    setState(() => _isUploading = true);

    try {
      final fileName =
          'proofs/${widget.bookingId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putFile(_image!);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .update({'paymentProofUrl': url, 'paymentStatus': 'pending'});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment proof uploaded successfully')),
      );
      setState(() {
        _image = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Payment Proof'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .doc(widget.bookingId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final bookingData = snapshot.data!.data() as Map<String, dynamic>;
          final existingProof = bookingData['paymentProofUrl'] as String?;
          final paymentStatus =
              bookingData['paymentStatus']?.toString() ?? 'not uploaded';

          final isEditable =
              paymentStatus.toLowerCase() == 'rejected' ||
              existingProof == null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (existingProof != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Uploaded Proof:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          existingProof,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text(
                            'Status: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            paymentStatus.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(paymentStatus),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                    ],
                  ),

                if (!isEditable)
                  const Text(
                    'Proof already uploaded. You cannot change it unless rejected.',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),

                if (isEditable) ...[
                  if (_image != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        _image!,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Camera'),
                        onPressed: () => _pickImage(ImageSource.camera),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.photo),
                        label: const Text('Gallery'),
                        onPressed: () => _pickImage(ImageSource.gallery),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton.icon(
                    icon: const Icon(Icons.upload),
                    label: const Text('Upload Proof'),
                    onPressed: _isUploading ? null : _uploadProof,
                  ),
                  if (_isUploading) const SizedBox(height: 16),
                  if (_isUploading) const CircularProgressIndicator(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
