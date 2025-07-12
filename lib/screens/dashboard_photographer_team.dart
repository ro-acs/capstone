import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DashboardPhotographerTeam extends StatefulWidget {
  const DashboardPhotographerTeam({super.key});

  @override
  State<DashboardPhotographerTeam> createState() =>
      _DashboardPhotographerTeamState();
}

class _DashboardPhotographerTeamState extends State<DashboardPhotographerTeam> {
  final user = FirebaseAuth.instance.currentUser!;
  String name = '';
  String profileImageUrl = '';
  int unreadMessages = 0;
  int pendingRequests = 0;

  @override
  void initState() {
    super.initState();
    fetchTeamInfo();
    fetchBadges();
  }

  Future<void> fetchTeamInfo() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (doc.exists) {
      setState(() {
        name = doc['name'] ?? '';
        profileImageUrl = doc['profileImageUrl'] ?? '';
      });
    }
  }

  Future<void> fetchBadges() async {
    final messages = await FirebaseFirestore.instance
        .collection('teamChats')
        .where('teamId', isEqualTo: user.uid)
        .where('unreadBy', arrayContains: user.uid)
        .get();

    final requests = await FirebaseFirestore.instance
        .collection('teamBookings')
        .where('teamId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'Pending')
        .get();

    setState(() {
      unreadMessages = messages.docs.length;
      pendingRequests = requests.docs.length;
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Team Photographer Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await fetchTeamInfo();
              await fetchBadges();
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundImage: profileImageUrl.isNotEmpty
                        ? NetworkImage(profileImageUrl)
                        : const AssetImage('assets/default_profile.png')
                              as ImageProvider,
                    radius: 30,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Team Lead: $name',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('Manage Team Members'),
              onTap: () => Navigator.pushNamed(context, '/team_members'),
            ),
            ListTile(
              leading: const Icon(Icons.upload),
              title: const Text('Team Portfolio Upload'),
              onTap: () => Navigator.pushNamed(context, '/team_portfolio'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Row(
                children: [
                  const Text('Shared Bookings'),
                  if (pendingRequests > 0) ...[
                    const SizedBox(width: 6),
                    Badge(count: pendingRequests),
                  ],
                ],
              ),
              onTap: () => Navigator.pushNamed(context, '/team_bookings'),
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: Row(
                children: [
                  const Text('Team Chat'),
                  if (unreadMessages > 0) ...[
                    const SizedBox(width: 6),
                    Badge(count: unreadMessages),
                  ],
                ],
              ),
              onTap: () => Navigator.pushNamed(context, '/team_chat'),
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Team Analytics'),
              onTap: () => Navigator.pushNamed(context, '/team_analytics'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: Center(
        child: Text(
          'Welcome, $name! You have $pendingRequests pending requests and $unreadMessages unread messages.',
        ),
      ),
    );
  }
}

class Badge extends StatelessWidget {
  final int count;
  const Badge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        count.toString(),
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
