import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class TeamPortfolioUploadScreen extends StatefulWidget {
  const TeamPortfolioUploadScreen({super.key});

  @override
  State<TeamPortfolioUploadScreen> createState() =>
      _TeamPortfolioUploadScreenState();
}

class _TeamPortfolioUploadScreenState extends State<TeamPortfolioUploadScreen> {
  final user = FirebaseAuth.instance.currentUser!;
  final List<File> _images = [];
  bool _uploading = false;

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _images.addAll(picked.map((e) => File(e.path)));
      });
    }
  }

  Future<void> _uploadImages() async {
    if (_images.isEmpty) return;
    setState(() => _uploading = true);

    for (var img in _images) {
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = FirebaseStorage.instance.ref().child(
        'team_portfolio/${user.uid}/$fileName.jpg',
      );
      await ref.putFile(img);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('team_portfolio').add({
        'teamId': user.uid,
        'imageUrl': url,
        'uploadedAt': Timestamp.now(),
      });
    }

    setState(() {
      _images.clear();
      _uploading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Images uploaded to team portfolio.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Team Portfolio')),
      body: Column(
        children: [
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _pickImages,
            icon: const Icon(Icons.photo_library),
            label: const Text('Select Images'),
          ),
          const SizedBox(height: 10),
          if (_images.isNotEmpty)
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _images.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemBuilder: (context, index) =>
                    Image.file(_images[index], fit: BoxFit.cover),
              ),
            ),
          if (_uploading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            ),
          if (_images.isNotEmpty && !_uploading)
            Padding(
              padding: const EdgeInsets.all(8),
              child: ElevatedButton.icon(
                onPressed: _uploadImages,
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Upload All'),
              ),
            ),
        ],
      ),
    );
  }
}
