import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import '/models/route_arguments.dart';
import 'my_booking_screen.dart';

class DashboardPhotographer extends StatefulWidget {
  const DashboardPhotographer({super.key});

  @override
  State<DashboardPhotographer> createState() => _DashboardPhotographerState();
}

class _DashboardPhotographerState extends State<DashboardPhotographer> {
  final user = FirebaseAuth.instance.currentUser!;
  String name = '';
  bool isPhotographer = false;
  String profileImageUrl = '';
  int totalBookings = 0;
  int pendingBookings = 0;
  int totalReviews = 0;
  bool isVerified = false;
  bool isPaid = false;
  int unreadMessages = 0;
  int newBookingRequests = 0;
  ThemeMode _themeMode = ThemeMode.dark;
  double totalEarnings = 0.0;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  DateTime? _selectedDay;
  double _withdrawable = 0.0;
  double _processing = 0.0;

  @override
  void initState() {
    super.initState();
    fetchPhotographerData();
    fetchStats();
  }

  Future<void> fetchPhotographerData() async {
    // Refresh current user object
    await FirebaseAuth.instance.currentUser?.reload();
    final updatedUser = FirebaseAuth.instance.currentUser;

    if (updatedUser == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(updatedUser.uid)
        .get();

    if (doc.exists) {
      final isPaidField = doc.data()?['isPaid'];

      setState(() {
        name = doc['name'] ?? '';
        profileImageUrl = doc['profileImageUrl'] ?? '';
        isPaid = isPaidField == true; // ensure it's a boolean
        isVerified = updatedUser.emailVerified;
        isPhotographer = doc['role'] == 'Photographer' ? true : false;
      });
    }
  }

  Future<void> fetchStats() async {
    final bookingsSnapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('photographerId', isEqualTo: user.uid)
        .get();

    final reviewsSnapshot = await FirebaseFirestore.instance
        .collection('reviews')
        .where('photographerId', isEqualTo: user.uid)
        .get();

    final messagesSnapshot = await FirebaseFirestore.instance
        .collection('chats')
        .where('users', arrayContains: user.uid)
        .get();

    int unread = 0;
    double earnings = 0.0;
    double withdrawable = 0.0;
    double processing = 0.0;
    Map<DateTime, List<Map<String, dynamic>>> events = {};

    for (var doc in messagesSnapshot.docs) {
      final messages = await doc.reference.collection('messages').get();
      for (var msg in messages.docs) {
        if (msg['senderId'] != user.uid && msg['isRead'] == false) {
          unread++;
        }
      }
    }

    for (var booking in bookingsSnapshot.docs) {
      if (booking['status'] == 'Completed') {
        double price = (booking['price'] as num?)?.toDouble() ?? 0.0;
        earnings += price;

        if (booking['payoutStatus'] == 'Withdrawable') {
          withdrawable += price;
        } else {
          processing += price;
        }
      }
      DateTime bookingDate = (booking['date'] as Timestamp).toDate();
      DateTime normalizedDate = DateTime(
        bookingDate.year,
        bookingDate.month,
        bookingDate.day,
      );
      events.putIfAbsent(normalizedDate, () => []).add({
        'clientName': booking['clientName'],
        'price': booking['price'],
        'status': booking['status'],
        'bookingId': booking.id,
      });
    }

    setState(() {
      totalBookings = bookingsSnapshot.docs.length;
      pendingBookings = bookingsSnapshot.docs
          .where((doc) => doc['status'] == 'Pending')
          .length;
      totalReviews = reviewsSnapshot.docs.length;
      unreadMessages = unread;
      newBookingRequests = pendingBookings;
      totalEarnings = earnings;
      _events = events;
    });
  }

  Future<void> _withdrawNow() async {
    if (_withdrawable <= 0) {
      Fluttertoast.showToast(msg: 'No withdrawable balance available.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Withdrawal'),
        content: Text(
          'Do you want to request withdrawal of ₱${_withdrawable.toStringAsFixed(2)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('withdrawals').add({
        'photographerId': user.uid,
        'amount': _withdrawable,
        'status': 'Pending',
        'requestedAt': Timestamp.now(),
      });

      Fluttertoast.showToast(msg: 'Withdrawal request submitted.');
      setState(() {
        _withdrawable = 0.0;
      });
      fetchStats(); // Refresh after request
    }
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.logout),
            label: const Text("Logout"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  Future<void> _cancelBooking(
    String bookingId,
    String clientId,
    String clientName,
  ) async {
    final TextEditingController reasonController = TextEditingController();

    final confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Cancel Booking for $clientName?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Please enter a reason for cancellation:"),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Back"),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;

              await FirebaseFirestore.instance
                  .collection('bookings')
                  .doc(bookingId)
                  .update({
                    'status': 'Cancelled',
                    'cancellationReason': reason,
                    'cancelledBy': 'Photographer',
                    'cancelledAt': FieldValue.serverTimestamp(),
                  });

              // TODO: send email or notification to client using clientId or email

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Booking cancelled for $clientName.")),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Confirm Cancel"),
          ),
        ],
      ),
    );

    if (confirm == true && reasonController.text.trim().isNotEmpty) {
      final reason = reasonController.text.trim();

      // Update booking status and reason
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
            'status': 'Cancelled',
            'cancellationReason': reason,
            'cancelledBy': 'Photographer',
            'cancelledAt': Timestamp.now(),
          });

      // Optional: send in-app notification
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': clientId,
        'title': 'Booking Cancelled',
        'message': 'Your booking has been cancelled. Reason: $reason',
        'timestamp': Timestamp.now(),
        'read': false,
      });

      // Optional: send email using EmailJS or SMTP backend (if you have that set up)
      // await sendCancellationEmail(clientEmail, reason);

      Fluttertoast.showToast(msg: 'Booking cancelled and client notified.');
      fetchStats(); // Refresh stats
      Navigator.pop(context); // Close bottom sheet if open
    } else if (reasonController.text.trim().isEmpty) {
      Fluttertoast.showToast(msg: 'Please enter a reason to cancel.');
    }
  }

  void _onDaySelected(DateTime day, DateTime focusedDay) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('photographerId', isEqualTo: user.uid)
        .where('date', isEqualTo: Timestamp.fromDate(day))
        .get();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        if (snapshot.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No bookings on this date.'),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: snapshot.docs.map((doc) {
            final data = doc.data();
            return Card(
              child: ListTile(
                title: Text('Client: ${data['clientName'] ?? 'Unknown'}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status: ${data['status']}'),
                    Text('Time: ${data['time'] ?? 'N/A'}'),
                  ],
                ),
                trailing: data['status'] != 'Cancelled'
                    ? IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () => _cancelBooking(
                          doc.id,
                          doc['clientId'],
                          doc['clientName'],
                        ),
                      )
                    : const Text('❌ Cancelled'),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.light,
        fontFamily: GoogleFonts.poppins().fontFamily,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: GoogleFonts.poppins().fontFamily,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text("Photographer Dashboard"),
          actions: [
            IconButton(
              icon: const Icon(Icons.open_in_browser),
              tooltip: 'Open Web Dashboard',
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  final idToken = await user.getIdToken();
                  final Uri webUri = Uri.parse(
                    'https://your-website.com/dashboard?token=$idToken',
                  );

                  if (await canLaunchUrl(webUri)) {
                    await launchUrl(
                      webUri,
                      mode: LaunchMode.externalApplication,
                    );
                  } else {
                    Fluttertoast.showToast(
                      msg: 'Could not launch web dashboard',
                    );
                  }
                } else {
                  Fluttertoast.showToast(msg: 'User not logged in');
                }
              },
            ),
          ],
        ),
        drawer: _buildDrawer(),
        body: RefreshIndicator(
          onRefresh: () async {
            await fetchPhotographerData();
            await fetchStats();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 20),
              _buildEarningsCard(),
              const SizedBox(height: 20),
              _buildStatsRow(),
              const SizedBox(height: 20),
              TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2100, 12, 31),
                focusedDay: _selectedDay ?? DateTime.now(),
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: (day) =>
                    _events[DateTime(day.year, day.month, day.day)] ?? [],
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                  });
                },
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7F00FF),
                  ),
                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    color: Color(0xFF7F00FF),
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    color: Color(0xFF7F00FF),
                  ),
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: const Color(0xFFE100FF),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: const Color(0xFF7F00FF),
                    shape: BoxShape.circle,
                  ),
                  weekendTextStyle: const TextStyle(color: Colors.redAccent),
                  defaultTextStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_selectedDay != null && _events[_selectedDay] != null)
                ..._events[_selectedDay]!.map((booking) {
                  return ListTile(
                    title: Text(
                      '📷 ${booking['clientName']} — ₱${booking['price']}',
                    ),
                    subtitle: Text('Status: ${booking['status']}'),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _selectedDay!,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (pickedDate != null) {
                        await FirebaseFirestore.instance
                            .collection('bookings')
                            .doc(booking['bookingId'])
                            .update({'date': Timestamp.fromDate(pickedDate)});
                        Fluttertoast.showToast(msg: "Booking rescheduled.");
                        fetchStats();
                      }
                    },
                  );
                }).toList(),
              const SizedBox(height: 20),
              _buildDashboardGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEarningsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💼 Earnings Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildEarningsItem("Withdrawable", _withdrawable, Colors.green),
              _buildEarningsItem("Processing", _processing, Colors.orange),
            ],
          ),
          const Divider(height: 24),
          Center(
            child: Text(
              'Total: P${(totalEarnings).toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton.icon(
              onPressed: _withdrawNow,
              icon: const Icon(Icons.account_balance_wallet),
              label: const Text("Withdraw Now"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          'P${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
      ],
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
          Hero(
            tag: 'profileAvatar',
            child: CircleAvatar(
              radius: 40,
              backgroundImage: profileImageUrl.isNotEmpty
                  ? NetworkImage(profileImageUrl)
                  : const AssetImage('assets/default_profile.png')
                        as ImageProvider,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hello, $name 👋",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 8),
                _buildStatusRow("Verified Email", isVerified),
                _buildStatusRow("Subscription", isPaid),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, bool value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value ? "✅ Yes" : "❌ No",
          style: TextStyle(
            color: value ? Colors.lightGreenAccent : Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatCard('📸 Bookings', totalBookings, Colors.teal),
        _buildStatCard('⏳ Pending', pendingBookings, Colors.orange),
        _buildStatCard('⭐ Reviews', totalReviews, Colors.indigo),
      ],
    );
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black,
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardGrid() {
    final buttons = [
      {
        'icon': Icons.design_services,
        'label': 'Manage Services',
        'route': '/manage_services',
        'badge': 0,
      },
      {
        'icon': Icons.request_page,
        'label': 'Booking Requests',
        'route': '/my_booking_screen',
        'badge': newBookingRequests,
      },
      {
        'icon': Icons.chat,
        'label': 'Messages',
        'route': '/chat_with_clients',
        'badge': unreadMessages,
      },
      {
        'icon': Icons.upload,
        'label': 'Portfolio Upload',
        'route': '/portfolio_upload',
        'badge': 0,
      },
      {
        'icon': Icons.star,
        'label': 'Reviews',
        'route': '/review_photographer',
        'badge': 0,
      },
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: buttons.map((b) {
        return GestureDetector(
          onTap: () {
            if (b['route'] == '/chat_with_clients') {
              Navigator.pushNamed(
                context,
                b['route'] as String,
                arguments: ChatWithClientsArgs('photographer'),
              );
            } else if (b['route'] as String == '/my_booking_screen') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      MyBookingsScreen(isPhotographerView: isPhotographer),
                ),
              );
            } else if (b['route'] as String == '/review_photographer') {
              Navigator.pushNamed(
                context,
                '/review_photographer',
                arguments: {'photographerId': user.uid},
              );
            } else {
              Navigator.pushNamed(context, b['route'] as String);
            }
          },
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Theme.of(context).cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        b['icon'] as IconData,
                        size: 38,
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        b['label'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              if ((b['badge'] as int) > 0)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${b['badge']}',
                      style: TextStyle(
                        color: Theme.of(context).cardColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF7F00FF), Color(0xFFE100FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: profileImageUrl.isNotEmpty
                      ? NetworkImage(profileImageUrl)
                      : const AssetImage('assets/default_profile.png')
                            as ImageProvider,
                ),
                const SizedBox(height: 10),
                Text(
                  'Photographer: $name',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
          ),
          _buildDrawerItem(
            Icons.design_services,
            'Manage Services',
            '/manage_services',
          ),
          _buildDrawerItem(
            Icons.request_page,
            'Booking Requests',
            '/my_booking_screen',
            badge: newBookingRequests,
          ),
          _buildDrawerItem(
            Icons.chat,
            'Chat with Clients',
            '/chat_with_clients',
            badge: unreadMessages,
          ),
          _buildDrawerItem(
            Icons.upload_file,
            'Portfolio Upload',
            '/portfolio_upload',
          ),
          _buildDrawerItem(Icons.star, 'View Reviews', '/review_photographer'),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout'),
            onTap: _confirmLogout,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    IconData icon,
    String title,
    String route, {
    int badge = 0,
  }) {
    return ListTile(
      leading: Stack(
        children: [
          Icon(icon),
          if (badge > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                ),
                child: Text(
                  '$badge',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).cardColor,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(title),
      onTap: () {
        if (route == '/chat_with_clients') {
          Navigator.pushNamed(
            context,
            route,
            arguments: ChatWithClientsArgs('photographer'),
          );
        } else if (route == '/review_photographer') {
          Navigator.pushNamed(
            context,
            '/review_photographer',
            arguments: {'photographerId': user.uid},
          );
        } else if (route == '/my_booking_screen') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  MyBookingsScreen(isPhotographerView: isPhotographer),
            ),
          );
        } else {
          Navigator.pushNamed(context, route);
        }
      },
    );
  }
}
