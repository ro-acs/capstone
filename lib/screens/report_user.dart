import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ReportUserScreen extends StatefulWidget {
  final String reportedUserId;
  final String reportedUserName;

  const ReportUserScreen({
    super.key,
    required this.reportedUserId,
    required this.reportedUserName,
  });

  @override
  State<ReportUserScreen> createState() => _ReportUserScreenState();
}

class _ReportUserScreenState extends State<ReportUserScreen> {
  final user = FirebaseAuth.instance.currentUser!;
  final reasonController = TextEditingController();
  File? selectedImage;

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => selectedImage = File(picked.path));
    }
  }

  Future<String?> uploadImage(File image) async {
    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = FirebaseStorage.instance.ref().child(
      'report_screenshots/$fileName.jpg',
    );
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }

  Future<void> submitReport() async {
    final reason = reasonController.text.trim();
    if (reason.isEmpty) return;

    String? imageUrl;
    if (selectedImage != null) {
      imageUrl = await uploadImage(selectedImage!);
    }

    await FirebaseFirestore.instance.collection('reports').add({
      'reporterId': user.uid,
      'reporterName': user.displayName ?? 'Anonymous',
      'reportedUserId': widget.reportedUserId,
      'reportedUserName': widget.reportedUserName,
      'reason': reason,
      'imageUrl': imageUrl ?? '',
      'timestamp': Timestamp.now(),
    });

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Report submitted successfully.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report User')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reporting: ${widget.reportedUserName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (selectedImage != null) Image.file(selectedImage!, height: 150),
            TextButton.icon(
              icon: const Icon(Icons.image),
              label: const Text('Attach Screenshot'),
              onPressed: pickImage,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: submitReport,
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }
}
