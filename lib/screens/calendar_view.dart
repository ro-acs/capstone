import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarViewScreen extends StatefulWidget {
  const CalendarViewScreen({super.key});

  @override
  State<CalendarViewScreen> createState() => _CalendarViewScreenState();
}

class _CalendarViewScreenState extends State<CalendarViewScreen> {
  final user = FirebaseAuth.instance.currentUser!;
  String userRole = '';
  Map<DateTime, List<Map<String, dynamic>>> events = {};
  DateTime focusedDay = DateTime.now();
  DateTime? selectedDay;

  @override
  void initState() {
    super.initState();
    fetchUserRole();
  }

  Future<void> fetchUserRole() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    setState(() => userRole = doc['role']);
    fetchBookings();
  }

  Future<void> fetchBookings() async {
    Query bookingsRef = FirebaseFirestore.instance.collection('bookings');

    if (userRole == 'Client') {
      bookingsRef = bookingsRef.where('clientId', isEqualTo: user.uid);
    } else if (userRole == 'Photographer') {
      bookingsRef = bookingsRef.where('photographerId', isEqualTo: user.uid);
    }

    final snapshot = await bookingsRef.get();
    final Map<DateTime, List<Map<String, dynamic>>> calendarData = {};

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final date = (data['date'] as Timestamp).toDate();
      final eventDate = DateTime(date.year, date.month, date.day);
      calendarData[eventDate] = calendarData[eventDate] ?? [];
      calendarData[eventDate]!.add(data);
    }

    setState(() => events = calendarData);
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Booking Calendar")),
      body: Column(
        children: [
          TableCalendar(
            focusedDay: focusedDay,
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            selectedDayPredicate: (day) => isSameDay(selectedDay, day),
            onDaySelected: (selected, focused) {
              setState(() {
                selectedDay = selected;
                focusedDay = focused;
              });
            },
            eventLoader: _getEventsForDay,
            calendarStyle: const CalendarStyle(
              markerDecoration: BoxDecoration(
                color: Colors.deepPurple,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              children: _getEventsForDay(selectedDay ?? focusedDay)
                  .map(
                    (event) => ListTile(
                      title: Text("${event['serviceName'] ?? 'Session'}"),
                      subtitle: Text(
                        "${event['status']} - ${event['location'] ?? ''}",
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
