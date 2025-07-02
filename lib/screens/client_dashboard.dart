import 'package:flutter/material.dart';
import 'client_tabs/browse_photographers_screen.dart';
import 'client_tabs/my_bookings_screen.dart';
import 'client_tabs/client_messages_screen.dart';
import 'client_tabs/client_profile_screen.dart';

class ClientDashboardScreen extends StatefulWidget {
  @override
  _ClientDashboardScreenState createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    BrowsePhotographersScreen(),
    MyBookingsScreen(),
    ClientMessagesScreen(),
    ClientProfileScreen(),
  ];

  final List<String> _titles = [
    "Browse Photographers",
    "My Bookings",
    "Messages",
    "My Profile",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        backgroundColor: Colors.indigo,
      ),
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Browse'),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_online),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
