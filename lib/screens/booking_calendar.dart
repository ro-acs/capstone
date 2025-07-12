import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';

class BookingCalendarScreen extends StatefulWidget {
  @override
  _BookingCalendarScreenState createState() => _BookingCalendarScreenState();
}

class _BookingCalendarScreenState extends State<BookingCalendarScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  void _loadBookings() async {
    final uid = _auth.currentUser?.uid;
    final roleDoc = await _db.collection('users').doc(uid).get();
    final role = roleDoc.data()?['role'];

    Query bookingsQuery = _db
        .collection('bookings')
        .where(
          role == 'photographer' ? 'photographerId' : 'clientId',
          isEqualTo: uid,
        )
        .where('status', isEqualTo: 'Confirmed');

    final snapshot = await bookingsQuery.get();

    Map<DateTime, List<Map<String, dynamic>>> loadedEvents = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final DateTime date = (data['date'] as Timestamp).toDate();
      final DateTime dayOnly = DateTime(date.year, date.month, date.day);
      loadedEvents[dayOnly] = [...(loadedEvents[dayOnly] ?? []), data];
    }

    setState(() {
      _events = loadedEvents;
    });
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Booking Calendar')),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.now().subtract(Duration(days: 365)),
            lastDay: DateTime.now().add(Duration(days: 365)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) =>
                _selectedDay != null &&
                day.year == _selectedDay!.year &&
                day.month == _selectedDay!.month &&
                day.day == _selectedDay!.day,
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            eventLoader: _getEventsForDay,
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.deepPurpleAccent,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.deepPurple,
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _selectedDay == null
                ? Center(child: Text('Select a date to view bookings'))
                : ListView(
                    children: _getEventsForDay(_selectedDay!).map((event) {
                      return ListTile(
                        leading: Icon(Icons.event),
                        title: Text(
                          'With: ${event['photographerEmail'] ?? event['clientEmail']}',
                        ),
                        subtitle: Text('Note: ${event['note'] ?? 'None'}'),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
