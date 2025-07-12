import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class DashboardPhotographer extends StatefulWidget {
  const DashboardPhotographer({super.key});

  @override
  State<DashboardPhotographer> createState() => _DashboardPhotographerState();
}

class _DashboardPhotographerState extends State<DashboardPhotographer> {
  String fullName = '';
  String email = '';
  String? photoUrl;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data != null) {
        setState(() {
          fullName = data['fullName'] ?? '';
          email = data['email'] ?? '';
          photoUrl = data['photoUrl'];
        });
      }
    }
  }

  void logoutUser(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  Widget buildTile(
    String title,
    IconData icon,
    VoidCallback onTap,
    Color color,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: color),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Photographer Dashboard"),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => logoutUser(context),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Colors.deepPurple),
              currentAccountPicture: CircleAvatar(
                backgroundImage: photoUrl != null
                    ? NetworkImage(photoUrl!)
                    : const AssetImage('assets/avatar_placeholder.png'),
              ),
              accountName: Text(fullName.isEmpty ? 'Loading...' : fullName),
              accountEmail: Text(email),
            ),
            ListTile(
              leading: const Icon(Icons.mail),
              title: const Text("Booking Requests"),
              onTap: () => Navigator.pushNamed(context, '/booking_requests'),
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text("Scheduled Bookings"),
              onTap: () => Navigator.pushNamed(context, '/scheduled_bookings'),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text("Booking History"),
              onTap: () => Navigator.pushNamed(context, '/booking_history'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Manage Portfolio"),
              onTap: () => Navigator.pushNamed(context, '/manage_portfolio'),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text("Edit Profile"),
              onTap: () => Navigator.pushNamed(context, '/edit_profile'),
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text("Chat with Clients"),
              onTap: () => Navigator.pushNamed(context, '/chat_with_clients'),
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text("Logout"),
              onTap: () => AuthService.logout(context),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome back,",
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey),
            ),
            Text(
              fullName.isNotEmpty ? fullName : "Photographer",
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  buildTile("Booking Requests", Icons.mail, () {
                    Navigator.pushNamed(context, '/booking_requests');
                  }, Colors.deepPurple),
                  buildTile("Scheduled Bookings", Icons.event, () {
                    Navigator.pushNamed(context, '/scheduled_bookings');
                  }, Colors.green),
                  buildTile("Portfolio", Icons.photo_library, () {
                    Navigator.pushNamed(context, '/manage_portfolio');
                  }, Colors.orange),
                  buildTile("Edit Profile", Icons.edit, () {
                    Navigator.pushNamed(context, '/edit_profile');
                  }, Colors.teal),
                  buildTile("History", Icons.history, () {
                    Navigator.pushNamed(context, '/booking_history');
                  }, Colors.grey),
                  buildTile("Chat", Icons.chat, () {
                    Navigator.pushNamed(context, '/chat_with_clients');
                  }, Colors.indigo),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, "/add_service"),
        backgroundColor: Colors.deepPurple,
        child: Icon(Icons.add),
        tooltip: "Add Service",
      ),
    );
  }
}
