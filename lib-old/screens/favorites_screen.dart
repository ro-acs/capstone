import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Map<String, dynamic>> favoritePhotographers = [];
  String sortOption = 'rating';
  String? selectedService;

  final userId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    final favoriteIds = List<String>.from(userDoc.data()?['favorites'] ?? []);

    if (favoriteIds.isEmpty) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: favoriteIds)
        .get();

    final data = snapshot.docs.map((doc) {
      final info = doc.data();
      info['id'] = doc.id;
      return info;
    }).toList();

    setState(() {
      favoritePhotographers = data;
    });
  }

  void removeFromFavorites(String id) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    favoritePhotographers.removeWhere((p) => p['id'] == id);
    await userRef.update({
      'favorites': favoritePhotographers.map((p) => p['id']).toList(),
    });
    setState(() {});
  }

  List<Map<String, dynamic>> getFilteredAndSortedPhotographers() {
    final filtered = favoritePhotographers.where((p) {
      final services = List<String>.from(p['services'] ?? []);
      return selectedService == null || services.contains(selectedService);
    }).toList();

    filtered.sort((a, b) {
      if (sortOption == 'rating') {
        return (b['rating'] ?? 0).compareTo(a['rating'] ?? 0);
      } else if (sortOption == 'price') {
        return (a['price'] ?? 0).compareTo(b['price'] ?? 0);
      }
      return 0;
    });

    return filtered;
  }

  void openMapView() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MapViewScreen(photographers: getFilteredAndSortedPhotographers()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photographers = getFilteredAndSortedPhotographers();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Favorite Photographers'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(icon: const Icon(Icons.map), onPressed: openMapView),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (val) => setState(() => sortOption = val),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rating', child: Text('Sort by Rating')),
              PopupMenuItem(value: 'price', child: Text('Sort by Price')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Filter by Service'),
              value: selectedService,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All Services'),
                ),
                ...{
                  for (var p in favoritePhotographers)
                    ...(p['services'] ?? []) as List<dynamic>,
                }.toSet().map(
                  (s) => DropdownMenuItem(value: s, child: Text(s)),
                ),
              ],
              onChanged: (val) => setState(() => selectedService = val),
            ),
          ),
          Expanded(
            child: photographers.isEmpty
                ? const Center(child: Text('No favorites match your filters.'))
                : ListView.builder(
                    itemCount: photographers.length,
                    itemBuilder: (context, index) {
                      final p = photographers[index];
                      final id = p['id'];
                      final name = p['fullName'] ?? 'Photographer';
                      final rating = (p['rating'] ?? 0).toDouble();
                      final photoUrl = p['photoUrl'];
                      final price = p['price']?.toString() ?? 'N/A';
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
                                leading: CircleAvatar(
                                  backgroundImage: photoUrl != null
                                      ? NetworkImage(photoUrl)
                                      : const AssetImage(
                                              'assets/avatar_placeholder.png',
                                            )
                                            as ImageProvider,
                                  radius: 28,
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Row(
                                  children: List.generate(5, (i) {
                                    return Icon(
                                      i < rating.round()
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber,
                                      size: 18,
                                    );
                                  }),
                                ),
                                trailing: Text('₱$price'),
                              ),
                              if (portfolio.isNotEmpty)
                                SizedBox(
                                  height: 80,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: portfolio.length,
                                    itemBuilder: (context, i) => Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
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
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  OutlinedButton(
                                    onPressed: () => removeFromFavorites(id),
                                    child: const Text('Remove'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/photographer_profile',
                                        arguments: id,
                                      );
                                    },
                                    child: const Text('Profile'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/book_session',
                                        arguments: id,
                                      );
                                    },
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
        ],
      ),
    );
  }
}

class MapViewScreen extends StatelessWidget {
  final List<Map<String, dynamic>> photographers;

  const MapViewScreen({super.key, required this.photographers});

  @override
  Widget build(BuildContext context) {
    final Set<Marker> markers = photographers
        .map((p) {
          final lat = p['lat'];
          final lng = p['lng'];
          if (lat == null || lng == null) return null;
          return Marker(
            markerId: MarkerId(p['id']),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(title: p['fullName']),
          );
        })
        .whereType<Marker>()
        .toSet();

    return Scaffold(
      appBar: AppBar(title: const Text('Photographers Map')),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(13.41, 122.56), // center of the Philippines
          zoom: 5,
        ),
        markers: markers,
      ),
    );
  }
}
