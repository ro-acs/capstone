// Updated DashboardClient with additional features

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/auth_service.dart';
import 'edit_profile.dart';
import 'my_bookings.dart';
import 'chat_screen.dart';
import 'chat_with_photographers.dart';

class DashboardClient extends StatefulWidget {
  const DashboardClient({super.key});

  @override
  State<DashboardClient> createState() => _DashboardClientState();
}

class _DashboardClientState extends State<DashboardClient> {
  final currentUser = FirebaseAuth.instance.currentUser!;
  String clientName = '';
  String email = '';
  String? photoUrl;
  Map<String, dynamic>? nextBooking;
  int total = 0,
      completed = 0,
      upcoming = 0,
      unreadMessages = 0,
      unreadNotifications = 0;

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};

  @override
  void initState() {
    super.initState();
    _loadClientData();
    _loadNotifications();
    _loadBookings();
  }

  Future<void> _loadClientData() async {
    final doc = await FirebaseFirestore.instance
        .collection('tblusers')
        .doc(currentUser.uid)
        .get();
    final data = doc.data()!;
    setState(() {
      clientName = data['fullName'] ?? '';
      email = data['email'] ?? '';
      photoUrl = data['photoUrl'];
    });
  }

  Future<void> _loadNotifications() async {
    final snapNotifs = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: currentUser.uid)
        .where('read', isEqualTo: false)
        .get();

    final snapChats = await FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .get();

    int unreadMsgCount = 0;
    for (var doc in snapChats.docs) {
      final data = doc.data();
      if (data['unreadBy'] != null &&
          (data['unreadBy'] as List).contains(currentUser.uid)) {
        unreadMsgCount++;
      }
    }

    setState(() {
      unreadNotifications = snapNotifs.size;
      unreadMessages = unreadMsgCount;
    });
  }

  Future<void> _loadBookings() async {
    final snap = await FirebaseFirestore.instance
        .collection('bookings')
        .where('clientId', isEqualTo: currentUser.uid)
        .get();

    final docs = snap.docs;
    int comp = 0, upc = 0;
    Map<DateTime, List<Map<String, dynamic>>> ev = {};

    for (var b in docs) {
      final d = (b['date'] as Timestamp).toDate();
      final s = b['status'] as String;
      if (s == 'completed') comp++;
      if (s == 'upcoming') upc++;

      final day = DateTime(d.year, d.month, d.day);
      ev[day] = (ev[day] ?? []);
      ev[day]!.add({'id': b.id, 'details': b.data()});
    }

    final upBookings = docs.where((b) => b['status'] == 'upcoming').toList()
      ..sort(
        (a, b) => (a['date'] as Timestamp).compareTo(b['date'] as Timestamp),
      );

    setState(() {
      total = docs.length;
      completed = comp;
      upcoming = upc;
      nextBooking = upBookings.isNotEmpty ? upBookings.first.data() : null;
      _events = ev;
    });
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Colors.deepPurple),
              currentAccountPicture: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfilePage()),
                ),
                child: CircleAvatar(
                  backgroundImage: photoUrl != null
                      ? NetworkImage(photoUrl!)
                      : const AssetImage('assets/avatar_placeholder.png')
                            as ImageProvider,
                ),
              ),
              accountName: Text(clientName),
              accountEmail: Text(email),
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text("Browse Photographers"),
              onTap: () =>
                  Navigator.pushNamed(context, "/browse_photographers"),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text("My Bookings"),
              trailing: unreadNotifications > 0
                  ? _badge(unreadNotifications)
                  : null,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.message),
              title: const Text("Chat"),
              trailing: unreadMessages > 0 ? _badge(unreadMessages) : null,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatWithPhotographersScreen(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: () => AuthService.logout(context),
            ),
          ],
        ),
      ),
      appBar: AppBar(title: Text('${_greeting()}, $clientName!')),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadClientData();
          await _loadNotifications();
          await _loadBookings();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _statCard(Icons.event, 'Total', total, Colors.blue),
                  _statCard(
                    Icons.access_time,
                    'Upcoming',
                    upcoming,
                    Colors.orange,
                  ),
                  _statCard(
                    Icons.check_circle,
                    'Completed',
                    completed,
                    Colors.green,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TableCalendar(
                firstDay: DateTime.utc(DateTime.now().year, 1, 1),
                lastDay: DateTime.utc(DateTime.now().year + 1, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                eventLoader: (day) =>
                    _events[DateTime(day.year, day.month, day.day)] ?? [],
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                  final events =
                      _events[DateTime(
                        selected.year,
                        selected.month,
                        selected.day,
                      )];
                  if (events != null && events.isNotEmpty) {
                    showModalBottomSheet(
                      context: context,
                      builder: (_) => ListView(
                        children: events.map((e) {
                          final d = e['details'];
                          final dt = (d['date'] as Timestamp).toDate();
                          return ListTile(
                            title: Text(d['photographerName'] ?? ''),
                            subtitle: Text(
                              DateFormat.yMMMd().add_jm().format(dt),
                            ),
                            trailing: Text(d['status']),
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/view_booking',
                              arguments: e['id'],
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }
                },
                selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
                calendarStyle: const CalendarStyle(markerSize: 6),
              ),
              const SizedBox(height: 16),
              _buildNextBookingCard(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.book),
                  label: const Text("View My Bookings"),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, String label, int count, Color color) {
    return Expanded(
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, size: 30, color: color),
              const SizedBox(height: 6),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(label, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(int count) {
    return CircleAvatar(
      radius: 10,
      backgroundColor: Colors.red,
      child: Text(
        '$count',
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
    );
  }

  Widget _buildNextBookingCard() {
    if (nextBooking == null) return const Text("📭 No upcoming bookings.");
    final d = (nextBooking!['date'] as Timestamp).toDate();
    final diff = d.difference(DateTime.now()).inDays;
    final timeStr = nextBooking!['timeSlot'] ?? '';
    final payStatus =
        nextBooking!['paymentMethod'] == 'GCash' &&
            (nextBooking!['paymentProofs'] as List?)?.isNotEmpty == true
        ? '🟡 Verifying Payment'
        : '🟢 Paid';

    final photographerId = nextBooking!['photographerId'];
    final photographerName = nextBooking!['photographerName'];
    final photographerAvatar = nextBooking!['photographerAvatar'] ?? '';

    final chatId = [currentUser.uid, photographerId]..sort();
    final chatKey = '${chatId[0]}_${chatId[1]}';

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            title: const Text("📌 Next Booking"),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("With: $photographerName"),
                Text("Date: ${DateFormat.yMMMd().format(d)} at $timeStr"),
                if (diff > 0) Text("⏳ $diff day(s) to go"),
                Text(payStatus),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.chat),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    chatId: chatKey,
                    receiverId: photographerId,
                    receiverName: photographerName,
                    receiverAvatar: photographerAvatar,
                  ),
                ),
              ),
            ),
          ),
          ButtonBar(
            alignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.edit_calendar),
                label: const Text("Reschedule"),
                onPressed: () {
                  // Add reschedule logic here
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.cancel),
                label: const Text("Cancel"),
                onPressed: () {
                  // Add cancel logic here
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
