import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class BrowsePhotographersScreen extends StatefulWidget {
  const BrowsePhotographersScreen({super.key});

  @override
  State<BrowsePhotographersScreen> createState() =>
      _BrowsePhotographersScreenState();
}

class _BrowsePhotographersScreenState extends State<BrowsePhotographersScreen> {
  String searchQuery = '';
  double minRating = 0;
  String? selectedService;
  String? selectedLocation;
  Set<String> selectedIds = {};

  List<String> allLocations = [
    'Metro Manila',
    'Cebu',
    'Davao',
    'Baguio',
    'Batangas',
    'Palawan',
    'Iloilo',
    'Laguna',
    'Bulacan',
    'Pampanga',
    'Quezon',
    'Zamboanga',
  ];

  List<Map<String, dynamic>> photographers = [];

  @override
  void initState() {
    super.initState();
    loadPhotographers();
  }

  Future<void> loadPhotographers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('tblusers')
        .where('role', isEqualTo: 'photographer')
        .where('subscriptionStatus', isEqualTo: 'approved')
        .get();

    setState(() {
      photographers = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  List<Map<String, dynamic>> getFilteredPhotographers() {
    return photographers.where((p) {
      final name = (p['name'] ?? '').toLowerCase();
      final services = List<String>.from(p['services'] ?? []);
      final location = p['location']?.toString();
      final rating = (p['rating'] ?? 0).toDouble();

      return (name.contains(searchQuery.toLowerCase()) ||
              services.any(
                (s) => s.toLowerCase().contains(searchQuery.toLowerCase()),
              )) &&
          rating >= minRating &&
          (selectedService == null || services.contains(selectedService)) &&
          (selectedLocation == null || selectedLocation == location);
    }).toList();
  }

  Future<double?> fetchAverageRating(String photographerId) async {
    final snap = await FirebaseFirestore.instance
        .collection('reviews')
        .where('photographerId', isEqualTo: photographerId)
        .get();

    if (snap.docs.isEmpty) return null;

    final ratings = snap.docs
        .map((doc) => (doc['rating'] ?? 0).toDouble())
        .whereType<double>()
        .toList();

    return ratings.reduce((a, b) => a + b) / ratings.length;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = getFilteredPhotographers();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Photographers'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search photographers...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) => setState(() => searchQuery = value),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Rating:'),
                    Expanded(
                      child: Slider(
                        min: 0,
                        max: 5,
                        divisions: 5,
                        label: '$minRating+',
                        value: minRating,
                        onChanged: (val) => setState(() => minRating = val),
                      ),
                    ),
                  ],
                ),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Filter by Service',
                  ),
                  value: selectedService,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Services'),
                    ),
                    ...{
                      for (var p in photographers)
                        ...(p['services'] ?? []) as List<dynamic>,
                    }.toSet().map(
                      (s) => DropdownMenuItem(value: s, child: Text(s)),
                    ),
                  ],
                  onChanged: (val) => setState(() => selectedService = val),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Filter by Location',
                  ),
                  value: selectedLocation,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Locations'),
                    ),
                    ...allLocations.map(
                      (loc) => DropdownMenuItem(value: loc, child: Text(loc)),
                    ),
                  ],
                  onChanged: (val) => setState(() => selectedLocation = val),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('No photographers match your filters.'),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final p = filtered[index];
                      final id = p['id'];
                      final name = p['name'] ?? 'Photographer';
                      final photoUrl = p['photoUrl'];
                      final services =
                          (p['services'] as List?)?.join(', ') ?? 'N/A';
                      final location = p['location'] ?? 'Unknown';
                      final portfolio = List<String>.from(p['portfolio'] ?? []);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundImage: photoUrl != null
                                          ? NetworkImage(photoUrl)
                                          : const AssetImage(
                                                  'assets/avatar_placeholder.png',
                                                )
                                                as ImageProvider,
                                    ),
                                    FutureBuilder<double?>(
                                      future: fetchAverageRating(id),
                                      builder: (context, snapshot) {
                                        final avg = snapshot.data;
                                        if (avg != null && avg >= 4.5) {
                                          return Positioned(
                                            right: -4,
                                            top: -4,
                                            child: Tooltip(
                                              message: 'Top Rated',
                                              child: Icon(
                                                Icons.verified,
                                                color: Colors.amber,
                                                size: 20,
                                              ),
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                  ],
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Checkbox(
                                      value: selectedIds.contains(id),
                                      onChanged: (bool? selected) {
                                        setState(() {
                                          if (selected == true) {
                                            selectedIds.add(id);
                                          } else {
                                            selectedIds.remove(id);
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Location: $location'),
                                    Text('Services: $services'),
                                    FutureBuilder<double?>(
                                      future: fetchAverageRating(id),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return const SizedBox(height: 18);
                                        }
                                        final avg = snapshot.data;
                                        if (avg == null) {
                                          return const Text('⭐ No ratings yet');
                                        }
                                        return Row(
                                          children: [
                                            ...List.generate(
                                              5,
                                              (i) => Icon(
                                                i < avg.round()
                                                    ? Icons.star
                                                    : Icons.star_border,
                                                color: Colors.amber,
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(avg.toStringAsFixed(1)),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              if (portfolio.isNotEmpty)
                                SizedBox(
                                  height: 80,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: portfolio.length,
                                    itemBuilder: (context, i) => Container(
                                      margin: const EdgeInsets.all(4),
                                      width: 80,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        image: DecorationImage(
                                          image: NetworkImage(portfolio[i]),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton(
                                    onPressed: () => Navigator.pushNamed(
                                      context,
                                      '/photographer_profile',
                                      arguments: id,
                                    ),
                                    child: const Text('View Profile'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pushNamed(
                                      context,
                                      '/book_session',
                                      arguments: id,
                                    ),
                                    child: const Text('Book Now'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (selectedIds.length >= 2)
            Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.compare),
                label: Text('Compare (${selectedIds.length}) Selected'),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/compare_photographers',
                    arguments: selectedIds.toList(),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
