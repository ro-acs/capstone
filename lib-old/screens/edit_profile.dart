import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:reorderables/reorderables.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final bioController = TextEditingController();

  String? profilePictureUrl;
  List<Map<String, dynamic>> galleryImages = [];
  String? uid;
  String? userRole;

  bool isLoading = true;
  final int maxGalleryImages = 5;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      uid = user.uid;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data();
      if (data != null) {
        fullNameController.text = data['fullName'] ?? '';
        emailController.text = data['email'] ?? '';
        bioController.text = data['bio'] ?? '';
        profilePictureUrl = data['profilePicture'];
        userRole = data['role'];
        if (data['galleryImages'] != null) {
          galleryImages = List<Map<String, dynamic>>.from(
            data['galleryImages'],
          );
        }
      }
    }
    setState(() => isLoading = false);
  }

  Future<void> updateProfile() async {
    try {
      final updateData = {
        'fullName': fullNameController.text.trim(),
        'galleryImages': galleryImages,
        'profilePicture': profilePictureUrl,
      };

      if (userRole == 'photographer') {
        updateData['bio'] = bioController.text.trim();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(updateData);
      Fluttertoast.showToast(msg: "Profile updated!");
      Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to update profile");
    }
  }

  Future<void> pickProfilePicture() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final ref = FirebaseStorage.instance.ref().child("users/$uid/profile.jpg");
    await ref.putFile(File(picked.path));
    final url = await ref.getDownloadURL();

    setState(() => profilePictureUrl = url);

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'profilePicture': url,
    });

    Fluttertoast.showToast(msg: "Profile picture updated!");
  }

  Future<void> pickGalleryImage({bool fromCamera = false}) async {
    if (galleryImages.length >= maxGalleryImages) {
      Fluttertoast.showToast(
        msg: "Maximum of $maxGalleryImages images allowed.",
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    );
    if (picked == null) return;

    final file = File(picked.path);
    final filename = "gallery_${DateTime.now().millisecondsSinceEpoch}.jpg";
    final ref = FirebaseStorage.instance.ref().child(
      "users/$uid/gallery/$filename",
    );

    final upload = await ref.putFile(file);
    final url = await upload.ref.getDownloadURL();

    setState(() {
      galleryImages.add({'url': url, 'caption': ''});
    });
  }

  Future<void> deleteGalleryImage(int index) async {
    try {
      final url = galleryImages[index]['url'];
      final ref = FirebaseStorage.instance.refFromURL(url);
      await ref.delete();

      setState(() => galleryImages.removeAt(index));
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to delete image.");
    }
  }

  void showImageFull(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text("Preview")),
          body: Center(child: PhotoView(imageProvider: NetworkImage(url))),
        ),
      ),
    );
  }

  void reorderGallery(int oldIndex, int newIndex) {
    setState(() {
      final item = galleryImages.removeAt(oldIndex);
      galleryImages.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: Colors.deepPurple,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (profilePictureUrl != null)
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: NetworkImage(profilePictureUrl!),
                      )
                    else
                      const CircleAvatar(
                        radius: 50,
                        child: Icon(Icons.person, size: 40),
                      ),
                    TextButton.icon(
                      onPressed: pickProfilePicture,
                      icon: const Icon(Icons.edit),
                      label: const Text("Change Profile Picture"),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: fullNameController,
                      decoration: const InputDecoration(
                        labelText: "Full Name",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: "Email (read-only)",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),
                    if (userRole == 'photographer') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: bioController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: "Bio",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.info),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Gallery",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.photo),
                                onPressed: () =>
                                    pickGalleryImage(fromCamera: false),
                                tooltip: "Upload from Gallery",
                              ),
                              IconButton(
                                icon: const Icon(Icons.camera_alt),
                                onPressed: () =>
                                    pickGalleryImage(fromCamera: true),
                                tooltip: "Upload from Camera",
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (galleryImages.isEmpty)
                        const Text("No images uploaded.")
                      else
                        ReorderableWrap(
                          needsLongPressDraggable: false,
                          spacing: 8,
                          runSpacing: 8,
                          onReorder: reorderGallery,
                          children: List.generate(galleryImages.length, (
                            index,
                          ) {
                            final img = galleryImages[index];
                            return Column(
                              key: ValueKey(img['url']),
                              children: [
                                Stack(
                                  children: [
                                    GestureDetector(
                                      onTap: () => showImageFull(img['url']),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          img['url'],
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: GestureDetector(
                                        onTap: () => deleteGalleryImage(index),
                                        child: const CircleAvatar(
                                          radius: 12,
                                          backgroundColor: Colors.black54,
                                          child: Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 100,
                                  child: TextField(
                                    onChanged: (val) =>
                                        galleryImages[index]['caption'] = val,
                                    controller: TextEditingController(
                                      text: img['caption'],
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: "Caption",
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 4,
                                        horizontal: 8,
                                      ),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: updateProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          "Save Changes",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
