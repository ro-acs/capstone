import 'package:flutter/material.dart';

import 'photographer_tabs/photographer_bookings_screen.dart';
import 'photographer_tabs/photographer_messages_screen.dart';
import 'photographer_tabs/photographer_profile_screen.dart';
import 'photographer_tabs/photographer_reviews_screen.dart';

class PhotographerDashboardScreen extends StatefulWidget {
  @override
  _PhotographerDashboardScreenState createState() =>
      _PhotographerDashboardScreenState();
}

class _PhotographerDashboardScreenState
    extends State<PhotographerDashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    PhotographerBookingsScreen(),
    PhotographerMessagesScreen(),
    PhotographerReviewsScreen(),
    PhotographerProfileScreen(),
  ];

  final List<String> _titles = [
    'My Bookings',
    'Messages',
    'Reviews',
    'My Profile',
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
          BottomNavigationBarItem(
            icon: Icon(Icons.event_available),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star_rate),
            label: 'Reviews',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
