import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import 'my_booking_screen.dart';
import 'chat_with_photographers.dart';

class DashboardClient extends StatefulWidget {
  const DashboardClient({super.key});

  @override
  State<DashboardClient> createState() => _DashboardClientState();
}

class _DashboardClientState extends State<DashboardClient> {
  final user = FirebaseAuth.instance.currentUser!;
  String userName = '';
  String profileImageUrl = '';
  String userEmail = '';

  int completedBookings = 0;
  int pendingBookings = 0;
  int cancelledBookings = 0;
  int processingBookings = 0;
  double totalSpend = 0;
  double awaitingPayment = 0;

  Map<DateTime, List<Map<String, dynamic>>> events = {};
  DateTime? _selectedDay;
  StreamSubscription? _bookingSub;

  @override
  void initState() {
    super.initState();
    fetchClientInfo();
    startBookingListener();
  }

  @override
  void dispose() {
    _bookingSub?.cancel();
    super.dispose();
  }

  Future<void> fetchClientInfo() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (doc.exists) {
      setState(() {
        userName = doc['name'] ?? '';
        profileImageUrl = doc['profileImageUrl'] ?? '';
        userEmail = doc['email'] ?? user.email ?? '';
      });
    }
  }

  void startBookingListener() {
    final firestore = FirebaseFirestore.instance;

    _bookingSub = firestore
        .collection('bookings')
        .where('clientId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
          int completed = 0, pending = 0, cancelled = 0, processing = 0;
          double total = 0, awaiting = 0;
          final Map<DateTime, List<Map<String, dynamic>>> newEvents = {};

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final status = data['status'];
            final finalPrice = (data['finalPrice'] as num?)?.toDouble() ?? 0.0;

            double partialTotal = 0.0;
            final partial = data['partialPayment'];

            if (partial is List) {
              for (var entry in partial) {
                if (entry is Map && entry['price'] is num) {
                  partialTotal += (entry['price'] as num).toDouble();
                }
              }
            }

            total += partialTotal;
            final remaining = (finalPrice - partialTotal).clamp(
              0,
              double.infinity,
            );
            awaiting += remaining;

            switch (status) {
              case 'Completed':
                completed++;
                break;
              case 'Pending':
                pending++;
                break;
              case 'Cancelled':
                cancelled++;
                break;
              case 'Processing':
                processing++;
                break;
            }

            final bookingDate = (data['bookingDate'] as Timestamp).toDate();
            final normalizedDate = DateTime(
              bookingDate.year,
              bookingDate.month,
              bookingDate.day,
            );
            newEvents.putIfAbsent(normalizedDate, () => []).add({
              'photographer': data['photographerName'] ?? '',
              'price': finalPrice,
              'status': status,
              'bookingId': doc.id,
            });
          }

          setState(() {
            completedBookings = completed;
            pendingBookings = pending;
            cancelledBookings = cancelled;
            processingBookings = processing;
            totalSpend = total;
            awaitingPayment = awaiting;
            events = newEvents;
          });
        });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: GoogleFonts.poppins().fontFamily,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: GoogleFonts.poppins().fontFamily,
      ),
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.deepPurple,
          centerTitle: true,
          elevation: 0,
          title: const Text("SnapSpot Client"),
        ),
        drawer: _buildDrawer(),
        body: RefreshIndicator(
          onRefresh: () async {
            await fetchClientInfo();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 20),
              _buildSpendCard(),
              const SizedBox(height: 20),
              _buildStatsRow(),
              const SizedBox(height: 20),
              _buildCalendar(),
              const SizedBox(height: 20),
              _buildBookingList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF7F00FF), Color(0xFFE100FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundImage: profileImageUrl.isNotEmpty
                ? NetworkImage(profileImageUrl)
                : const AssetImage('assets/default_profile.png')
                      as ImageProvider,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hello, ${userName.isNotEmpty ? userName : 'Client'} 👋",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(userEmail, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Total Spend',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'P${totalSpend.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              'Awaiting Payment: P${awaitingPayment.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStatCard('Completed', completedBookings, Colors.green),
        _buildStatCard('Pending', pendingBookings, Colors.orange),
        _buildStatCard('Cancelled', cancelledBookings, Colors.red),
        _buildStatCard('Processing', processingBookings, Colors.blue),
      ],
    );
  }

  Widget _buildStatCard(String title, int value, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text(
                value.toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2100, 12, 31),
      focusedDay: _selectedDay ?? DateTime.now(),
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      eventLoader: (day) => events[day] ?? [],
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
        });
      },
      calendarStyle: const CalendarStyle(
        todayDecoration: BoxDecoration(
          color: Colors.deepPurple,
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: Colors.purple,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildBookingList() {
    if (_selectedDay == null || events[_selectedDay] == null) {
      return const SizedBox();
    }

    List<Map<String, dynamic>> dayEvents = events[_selectedDay!]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bookings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ...dayEvents.map((event) {
          return Card(
            elevation: 2,
            child: ListTile(
              title: Text(event['photographer']),
              subtitle: Text('P${event['price'].toStringAsFixed(2)}'),
              trailing: Text(event['status']),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(bottomRight: Radius.circular(32)),
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple, Colors.purple],
              ),
            ),
            accountName: Text(
              userName.isNotEmpty ? userName : 'SnapSpot Client',
            ),
            accountEmail: Text(userEmail),
            currentAccountPicture: CircleAvatar(
              backgroundImage: profileImageUrl.isNotEmpty
                  ? NetworkImage(profileImageUrl)
                  : const AssetImage('assets/default_profile.png')
                        as ImageProvider,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("Browse Photographers"),
            onTap: () => Navigator.pushNamed(context, '/browse_photographers'),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("My Bookings"),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MyBookingsScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("Chat with Photographers"),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChatWithPhotographers()),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}
