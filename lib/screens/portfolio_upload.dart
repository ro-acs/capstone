import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PortfolioUploadScreen extends StatefulWidget {
  @override
  _PortfolioUploadScreenState createState() => _PortfolioUploadScreenState();
}

class _PortfolioUploadScreenState extends State<PortfolioUploadScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<XFile> _images = [];
  final picker = ImagePicker();
  final Map<String, TextEditingController> _captions = {};
  bool _uploading = false;
  List<Map<String, dynamic>> _uploadedImages = [];

  static const int maxUploads = 10;

  Future<void> _pickImages() async {
    final picked = await picker.pickMultiImage();
    if (picked != null && picked.isNotEmpty) {
      if (_images.length + picked.length > maxUploads) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can only upload up to 10 images.')),
        );
        return;
      }

      setState(() {
        _images.addAll(picked);
        for (var img in picked) {
          _captions[img.path] = TextEditingController();
        }
      });
    }
  }

  Future<void> _uploadPortfolio() async {
    if (_images.isEmpty) return;

    setState(() => _uploading = true);
    final uid = _auth.currentUser!.uid;
    final token = await _auth.currentUser?.getIdToken();
    final uploadUrl =
        'https://capstone.x10.mx/uploadphoto?id=$uid&token=$token';

    for (var image in _images) {
      final file = File(image.path);
      final fileName = path.basename(file.path);

      try {
        var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            file.path,
            filename: fileName,
          ),
        );
        final response = await request.send();

        if (response.statusCode == 200) {
          final respStr = await response.stream.bytesToString();
          final data = json.decode(respStr);
          final imageUrl = data['url'];
          final caption = _captions[image.path]?.text ?? '';

          await _db.collection('portfolio').add({
            'photographerId': uid,
            'imageUrl': imageUrl,
            'caption': caption,
            'timestamp': FieldValue.serverTimestamp(),
          });
        } else {
          throw Exception('Upload failed (${response.statusCode})');
        }
      } catch (e) {
        print("Upload error: $e");
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to upload: $e')));
      }
    }

    setState(() {
      _uploading = false;
      _images.clear();
      _captions.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Portfolio uploaded successfully!')),
    );
    _fetchUploadedImages(); // Refresh
  }

  void _removeImage(int index) {
    setState(() {
      final image = _images[index];
      _captions.remove(image.path);
      _images.removeAt(index);
    });
  }

  void _reorderImages(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final img = _images.removeAt(oldIndex);
      _images.insert(newIndex, img);
    });
  }

  Future<void> _fetchUploadedImages() async {
    try {
      final uid = _auth.currentUser!.uid;
      final response = await http.get(
        Uri.parse('https://capstone.x10.mx/get_photos?id=$uid'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        setState(
          () => _uploadedImages = List<Map<String, dynamic>>.from(jsonData),
        );
      } else {
        throw Exception('Failed to load gallery (${response.statusCode})');
      }
    } catch (e) {
      print("Fetch gallery error: $e");
    }
  }

  void _confirmDelete(Map<String, dynamic> image) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final uid = _auth.currentUser!.uid;
      final response = await http.post(
        Uri.parse('https://capstone.x10.mx/delete_photo'),
        body: {'url': image['url'], 'id': uid},
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Photo deleted.')));
        _fetchUploadedImages(); // Refresh
      } else {
        throw Exception('Delete failed (${response.statusCode})');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchUploadedImages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Portfolio')),
      body: _uploading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.add_photo_alternate_rounded),
                      label: const Text('Select Images'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _images.isEmpty
                        ? const Text('No images selected.')
                        : SizedBox(
                            height: 400,
                            child: ReorderableListView.builder(
                              itemCount: _images.length,
                              shrinkWrap: true,
                              onReorder: _reorderImages,
                              itemBuilder: (context, index) {
                                final image = _images[index];
                                return Dismissible(
                                  key: ValueKey(image.path),
                                  background: Container(
                                    color: Colors.red,
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.only(left: 20),
                                    child: const Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                    ),
                                  ),
                                  direction: DismissDirection.startToEnd,
                                  onDismissed: (_) => _removeImage(index),
                                  child: Card(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(12),
                                              ),
                                          child: Image.file(
                                            File(image.path),
                                            height: 200,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: TextField(
                                            controller: _captions[image.path],
                                            decoration: const InputDecoration(
                                              labelText: 'Caption',
                                              border: OutlineInputBorder(),
                                              prefixIcon: Icon(Icons.edit),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                    const SizedBox(height: 12),
                    if (_images.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: _uploadPortfolio,
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('Upload All'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 20,
                          ),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const Text(
                      'Uploaded Portfolio (Web Server)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _uploadedImages.isEmpty
                        ? const Text('No uploaded images found.')
                        : GridView.builder(
                            itemCount: _uploadedImages.length,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 1,
                                ),
                            itemBuilder: (context, index) {
                              final image = _uploadedImages[index];
                              return Stack(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => Dialog(
                                          child: InteractiveViewer(
                                            child: Image.network(image['url']),
                                          ),
                                        ),
                                      );
                                    },
                                    child: Card(
                                      clipBehavior: Clip.antiAlias,
                                      child: Image.network(
                                        image['url'],
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.broken_image),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5),
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        onPressed: () => _confirmDelete(image),
                                        tooltip: 'Delete',
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}
