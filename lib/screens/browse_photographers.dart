import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'photographer_details.dart';

class BrowsePhotographersScreen extends StatefulWidget {
  const BrowsePhotographersScreen({super.key});

  @override
  State<BrowsePhotographersScreen> createState() =>
      _BrowsePhotographersScreenState();
}

class _BrowsePhotographersScreenState extends State<BrowsePhotographersScreen> {
  // ---------------- STATE ----------------
  String _searchQuery = '';
  double _minRating = 0;
  RangeValues _rateRange = const RangeValues(0, 10000);
  String? _selectedService;
  String? _selectedLocation;
  String _sortOption = 'rating_desc';
  Set<String> _selectedIds = {};
  bool _showFilters = false;
  bool _collapseAll = false;

  // ---------------- PAGINATION ----------------
  final int _limit = 5;
  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _loading = false;

  // ---------------- DATA ----------------
  List<Map<String, dynamic>> _photographers = [];
  Map<String, List<Map<String, dynamic>>> _cachedServices = {};
  Set<String> _expandedPhotographerIds = {};

  final List<String> _allLocations = [
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

  @override
  void initState() {
    super.initState();
    _loadPhotographers();
  }

  Future<void> _loadPhotographers() async {
    if (_loading || !_hasMore) return;

    setState(() => _loading = true);

    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'Photographer')
        .where('isPaid', isEqualTo: true)
        .where('isVerified', isEqualTo: true)
        .orderBy('rating', descending: true)
        .limit(_limit);

    if (_lastDoc != null) {
      query = query.startAfterDocument(_lastDoc!);
    }

    final snap = await query.get();

    if (snap.docs.isNotEmpty) {
      _lastDoc = snap.docs.last;
    } else {
      _hasMore = false;
    }

    final servicesSnap = await FirebaseFirestore.instance
        .collection('services')
        .get();
    final servicesGrouped = <String, List<Map<String, dynamic>>>{};
    for (final doc in servicesSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final photographerId = data['photographerId'];
      if (photographerId == null) continue;
      servicesGrouped.putIfAbsent(photographerId, () => []);
      servicesGrouped[photographerId]!.add(data);
    }

    final List<Map<String, dynamic>> newPhotographers = [];

    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final id = doc.id;
      final services = servicesGrouped[id] ?? [];
      _cachedServices[id] = services;

      newPhotographers.add({...data, 'id': id, 'services': services});
    }

    setState(() {
      _photographers.addAll(newPhotographers);
      _loading = false;
    });
  }

  List<Map<String, dynamic>> _filtered() {
    List<Map<String, dynamic>> list = _photographers.where((p) {
      final name = (p['name'] ?? p['name'] ?? '').toString().toLowerCase();
      final loc = p['location']?.toString();
      final rating = (p['rating'] ?? 0).toDouble();
      final services = List<Map<String, dynamic>>.from(p['services'] ?? []);
      final serviceNames = services
          .map((s) => (s['serviceName'] ?? '').toString().toLowerCase())
          .toList();

      final matchesSearch =
          _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase()) ||
          serviceNames.any((s) => s.contains(_searchQuery.toLowerCase()));

      final matchesRating = rating >= _minRating;
      final matchesService =
          _selectedService == null ||
          serviceNames.contains(_selectedService?.toLowerCase());

      final matchesLocation =
          _selectedLocation == null || _selectedLocation == loc;

      final matchesRate = services.any((s) {
        final rate = (s['rate'] ?? 0).toDouble();
        return rate >= _rateRange.start && rate <= _rateRange.end;
      });

      return matchesSearch &&
          matchesRating &&
          matchesService &&
          matchesLocation &&
          matchesRate;
    }).toList();

    switch (_sortOption) {
      case 'price_asc':
        list.sort((a, b) => _minPrice(a).compareTo(_minPrice(b)));
        break;
      case 'price_desc':
        list.sort((a, b) => _minPrice(b).compareTo(_minPrice(a)));
        break;
      case 'service_count':
        list.sort(
          (a, b) => (b['services']?.length ?? 0).compareTo(
            a['services']?.length ?? 0,
          ),
        );
        break;
      case 'rating_desc':
      default:
        list.sort((a, b) => (b['rating'] ?? 0).compareTo(a['rating'] ?? 0));
    }

    return list;
  }

  double _minPrice(Map<String, dynamic> p) {
    final services = List<Map<String, dynamic>>.from(p['services'] ?? []);
    if (services.isEmpty) return double.infinity;
    return services
        .map((s) => (s['rate'] ?? 0).toDouble())
        .reduce((a, b) => a < b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7F00FF),
        title: const Text('Browse Photographers'),
        actions: [
          IconButton(
            icon: Icon(_collapseAll ? Icons.expand : Icons.expand_less),
            onPressed: () {
              setState(() {
                _collapseAll = !_collapseAll;
                _expandedPhotographerIds.clear();
              });
            },
          ),
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_alt_off : Icons.filter_alt),
            tooltip: _showFilters ? 'Hide filters' : 'Show filters',
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showFilters) _buildFiltersCard(),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('No photographers match.'))
                : ListView.builder(
                    itemCount: list.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == list.length) {
                        return _hasMore
                            ? TextButton(
                                onPressed: _loadPhotographers,
                                child: const Text('Load more'),
                              )
                            : const SizedBox.shrink();
                      }
                      return _photographerTile(list[i]);
                    },
                  ),
          ),
          if (_selectedIds.length >= 2) _compareButton(),
        ],
      ),
    );
  }

  Widget _buildFiltersCard() {
    final serviceSet = {
      for (var p in _photographers)
        ...List<Map<String, dynamic>>.from(
          p['services'] ?? [],
        ).map((s) => s['serviceName'] ?? ''),
    };

    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by name or service…',
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            Row(
              children: [
                const Text('Rating'),
                Expanded(
                  child: Slider(
                    min: 0,
                    max: 5,
                    divisions: 5,
                    label: _minRating.toStringAsFixed(1),
                    value: _minRating,
                    onChanged: (v) => setState(() => _minRating = v),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Text('Price Range'),
                Expanded(
                  child: RangeSlider(
                    values: _rateRange,
                    min: 0,
                    max: 10000,
                    divisions: 20,
                    labels: RangeLabels(
                      '₱${_rateRange.start.round()}',
                      '₱${_rateRange.end.round()}',
                    ),
                    onChanged: (v) => setState(() => _rateRange = v),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: serviceSet.map((s) {
                final selected = s == _selectedService;
                return ChoiceChip(
                  label: Text(s),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    _selectedService = selected ? null : s;
                  }),
                );
              }).toList(),
            ),
            DropdownButtonFormField<String>(
              value: _selectedLocation,
              hint: const Text('Select Location'),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.place)),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All Locations'),
                ),
                ..._allLocations.map(
                  (l) => DropdownMenuItem(value: l, child: Text(l)),
                ),
              ],
              onChanged: (val) => setState(() => _selectedLocation = val),
            ),
            DropdownButtonFormField<String>(
              value: _sortOption,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.sort)),
              items: const [
                DropdownMenuItem(
                  value: 'rating_desc',
                  child: Text('Rating: High → Low'),
                ),
                DropdownMenuItem(
                  value: 'price_asc',
                  child: Text('Price: Low → High'),
                ),
                DropdownMenuItem(
                  value: 'price_desc',
                  child: Text('Price: High → Low'),
                ),
                DropdownMenuItem(
                  value: 'service_count',
                  child: Text('Most Services'),
                ),
              ],
              onChanged: (v) =>
                  setState(() => _sortOption = v ?? 'rating_desc'),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.clear),
                label: const Text('Clear Filters'),
                onPressed: () => setState(() {
                  _searchQuery = '';
                  _minRating = 0;
                  _rateRange = const RangeValues(0, 10000);
                  _selectedService = null;
                  _selectedLocation = null;
                  _sortOption = 'rating_desc';
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photographerTile(Map<String, dynamic> p) {
    final id = p['id'];
    final name = p['name'] ?? 'Photographer';
    final photoUrl = p['photoUrl'];
    final rating = (p['rating'] ?? 0).toDouble();
    final price = (p['price'] ?? 0).toDouble();
    final services = List<Map<String, dynamic>>.from(p['services'] ?? []);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: photoUrl != null
              ? NetworkImage(photoUrl)
              : const AssetImage('assets/avatar_placeholder.png')
                    as ImageProvider,
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: List.generate(
                5,
                (i) => Icon(
                  i < rating.round() ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 16,
                ),
              ),
            ),
            Text('Starts at ₱${price.toStringAsFixed(0)}'),
          ],
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'View Details',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PhotographerDetailsScreen(photographer: p),
                  ),
                );
              },
            ),
            Checkbox(
              value: _selectedIds.contains(id),
              onChanged: (sel) => setState(() {
                if (sel == true) {
                  _selectedIds.add(id);
                } else {
                  _selectedIds.remove(id);
                }
              }),
            ),
          ],
        ),
        onTap: () => setState(() {
          if (_selectedIds.contains(id)) {
            _selectedIds.remove(id);
          } else {
            _selectedIds.add(id);
          }
        }),
      ),
    );
  }

  Widget _compareButton() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7F00FF),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.compare),
        label: Text('Compare (${_selectedIds.length}) Selected'),
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/compare_photographers',
            arguments: _selectedIds.toList(),
          );
        },
      ),
    );
  }

  void _showPhotographerDetails(
    BuildContext context,
    Map<String, dynamic> photographer,
  ) {
    final name = photographer['name'] ?? 'Photographer';
    final rating = (photographer['rating'] ?? 0).toDouble();
    final location = photographer['location'] ?? 'Unknown';
    final photoUrl = photographer['photoUrl'];
    final services = List<Map<String, dynamic>>.from(
      photographer['services'] ?? [],
    );

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundImage: photoUrl != null
                      ? NetworkImage(photoUrl)
                      : const AssetImage('assets/avatar_placeholder.png')
                            as ImageProvider,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Center(child: Text(location)),
              const SizedBox(height: 8),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < rating.round() ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Services Offered',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...services.map(
                (s) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s['serviceName'] ?? 'Service'),
                  subtitle: Text('₱${(s['price'] ?? 0).toString()}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
