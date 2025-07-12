import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardAdmin extends StatefulWidget {
  const DashboardAdmin({super.key});

  @override
  State<DashboardAdmin> createState() => _DashboardAdminState();
}

class _DashboardAdminState extends State<DashboardAdmin> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Dashboard")),
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
              leading: const Icon(Icons.people),
              title: const Text("Manage Users"),
            ),
            ListTile(
              leading: const Icon(Icons.book_online),
              title: const Text("All Bookings"),
            ),
            ListTile(
              leading: const Icon(Icons.camera),
              title: const Text("Manage Photographers"),
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text("Reports & Analytics"),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text("App Settings"),
            ),
            ListTile(
              leading: const Icon(Icons.file_present),
              title: const Text("Generate Reports"),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: () => logoutUser(context),
            ),
          ],
        ),
      ),
      body: const Center(
        child: Text("Welcome, Admin!", style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
