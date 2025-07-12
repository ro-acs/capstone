// ... [top imports same as yours]
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ManageServicesScreen extends StatefulWidget {
  const ManageServicesScreen({super.key});

  @override
  State<ManageServicesScreen> createState() => _ManageServicesScreenState();
}

class _ManageServicesScreenState extends State<ManageServicesScreen> {
  final user = FirebaseAuth.instance.currentUser!;
  final _formKey = GlobalKey<FormState>();

  String serviceName = '';
  String serviceDesc = '';
  double price = 0;
  String category = 'Portrait';
  bool available = true;
  String imageUrl = '';
  final List<String> categories = [
    'Wedding',
    'Birthday',
    'Product',
    'Event',
    'Portrait',
    'Other',
  ];

  String _search = '';
  String _sortOption = 'Newest';
  String _filterCategory = 'All';
  bool _filterAvailable = false;
  List<String> selectedIds = [];

  final picker = ImagePicker();

  Future<String?> uploadImage(XFile file) async {
    final storageRef = FirebaseStorage.instance.ref().child(
      'service_images/${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await storageRef.putFile(File(file.path));
    return await storageRef.getDownloadURL();
  }

  void _sortServices(List<QueryDocumentSnapshot> list) {
    list.sort((a, b) {
      switch (_sortOption) {
        case 'Oldest':
          return (a['createdAt'] as Timestamp).compareTo(b['createdAt']);
        case 'Price: Low to High':
          return (a['price'] as num).compareTo(b['price']);
        case 'Price: High to Low':
          return (b['price'] as num).compareTo(a['price']);
        case 'Newest':
        default:
          return (b['createdAt'] as Timestamp).compareTo(a['createdAt']);
      }
    });
  }

  Future<void> duplicateService(DocumentSnapshot doc) async {
    await FirebaseFirestore.instance.collection('services').add({
      'photographerId': user.uid,
      'serviceName': '${doc['serviceName']} (Copy)',
      'description': doc['description'],
      'price': doc['price'],
      'category': doc['category'],
      'available': doc['available'],
      'imageUrl': doc['imageUrl'],
      'createdAt': Timestamp.now(),
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Service duplicated')));
  }

  Future<void> deleteService(String docId) async {
    await FirebaseFirestore.instance.collection('services').doc(docId).delete();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Service deleted')));
  }

  Future<void> deleteSelectedServices() async {
    for (final id in selectedIds) {
      await FirebaseFirestore.instance.collection('services').doc(id).delete();
    }
    setState(() => selectedIds.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${selectedIds.length} service(s) deleted')),
    );
  }

  Future<void> showAddServiceDialog() async {
    // clear form data
    serviceName = '';
    serviceDesc = '';
    price = 0;
    category = 'Portrait';
    available = true;
    imageUrl = '';
    XFile? pickedImage;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Add Service"),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (pickedImage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Image.file(File(pickedImage!.path), height: 120),
                    ),
                  TextButton.icon(
                    icon: const Icon(Icons.photo),
                    label: const Text("Choose Image"),
                    onPressed: () async {
                      final file = await picker.pickImage(
                        source: ImageSource.gallery,
                      );
                      if (file != null) setState(() => pickedImage = file);
                    },
                  ),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Service Name',
                    ),
                    onChanged: (val) => serviceName = val,
                    validator: (val) => val!.isEmpty ? 'Enter name' : null,
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Description'),
                    onChanged: (val) => serviceDesc = val,
                    validator: (val) =>
                        val!.isEmpty ? 'Enter description' : null,
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Price'),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => price = double.tryParse(val) ?? 0,
                    validator: (val) => price <= 0 ? 'Enter valid price' : null,
                  ),
                  DropdownButtonFormField<String>(
                    value: category,
                    items: categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) => setState(() => category = val!),
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  SwitchListTile(
                    value: available,
                    title: const Text("Available"),
                    onChanged: (val) => setState(() => available = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              child: const Text("Add"),
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  String? finalImageUrl = '';
                  if (pickedImage != null)
                    finalImageUrl = await uploadImage(pickedImage!);

                  await FirebaseFirestore.instance.collection('services').add({
                    'photographerId': user.uid,
                    'serviceName': serviceName,
                    'description': serviceDesc,
                    'price': price,
                    'category': category,
                    'available': available,
                    'imageUrl': finalImageUrl ?? '',
                    'createdAt': Timestamp.now(),
                  });

                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final servicesRef = FirebaseFirestore.instance
        .collection('services')
        .where('photographerId', isEqualTo: user.uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Services"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: deleteSelectedServices,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: showAddServiceDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Search...'),
                    onChanged: (val) => setState(() => _search = val),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _sortOption,
                  items:
                      [
                            'Newest',
                            'Oldest',
                            'Price: Low to High',
                            'Price: High to Low',
                          ]
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                  onChanged: (val) => setState(() => _sortOption = val!),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: _filterCategory,
                  items: ['All', ...categories]
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) => setState(() => _filterCategory = val!),
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    const Text("Available Only"),
                    Switch(
                      value: _filterAvailable,
                      onChanged: (val) =>
                          setState(() => _filterAvailable = val),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: servicesRef.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                var list = snapshot.data!.docs;

                // Filters
                list = list.where((doc) {
                  final match = doc['serviceName']
                      .toString()
                      .toLowerCase()
                      .contains(_search.toLowerCase());
                  final matchCat =
                      _filterCategory == 'All' ||
                      doc['category'] == _filterCategory;
                  final matchAvail =
                      !_filterAvailable || doc['available'] == true;
                  return match && matchCat && matchAvail;
                }).toList();

                _sortServices(list);

                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final doc = list[index];
                    final selected = selectedIds.contains(doc.id);
                    return Card(
                      child: ListTile(
                        leading:
                            doc['imageUrl'] != null &&
                                doc['imageUrl'].isNotEmpty
                            ? Image.network(
                                doc['imageUrl'],
                                width: 60,
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.photo),
                        title: Text(doc['serviceName']),
                        subtitle: Text(
                          '${doc['description']}\n₱${doc['price'].toStringAsFixed(2)} • ${doc['category']} • ${doc['available'] ? "Available" : "Unavailable"}',
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: selected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    selectedIds.add(doc.id);
                                  } else {
                                    selectedIds.remove(doc.id);
                                  }
                                });
                              },
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'duplicate') {
                                  duplicateService(doc);
                                } else if (value == 'delete') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Confirm Deletion'),
                                      content: const Text(
                                        'Are you sure you want to delete this service?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                          ),
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    await deleteService(doc.id);
                                  }
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'duplicate',
                                  child: Text('Duplicate'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
