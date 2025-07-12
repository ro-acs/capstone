import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarBookingsScreen extends StatefulWidget {
  const CalendarBookingsScreen({super.key});

  @override
  State<CalendarBookingsScreen> createState() => _CalendarBookingsScreenState();
}

class _CalendarBookingsScreenState extends State<CalendarBookingsScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _bookings = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchBookings();
  }

  void _fetchBookings() async {
    final clientId = FirebaseAuth.instance.currentUser!.uid;

    final snapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('clientId', isEqualTo: clientId)
        .get();

    final Map<DateTime, List<Map<String, dynamic>>> data = {};

    for (var doc in snapshot.docs) {
      final booking = doc.data();
      final DateTime date = (booking['date'] as Timestamp).toDate();
      final DateTime key = DateTime(
        date.year,
        date.month,
        date.day,
      ); // strip time

      data.putIfAbsent(key, () => []).add({
        'photographerName': booking['photographerName'],
        'service': booking['service'],
        'status': booking['status'],
        'notes': booking['notes'],
        'date': date,
      });
    }

    setState(() {
      _bookings = data;
    });
  }

  List<Map<String, dynamic>> _getBookingsForDay(DateTime day) {
    final DateTime key = DateTime(day.year, day.month, day.day);
    return _bookings[key] ?? [];
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingsToday = _getBookingsForDay(_selectedDay!);

    return Scaffold(
      appBar: AppBar(title: const Text("My Booking Calendar")),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            eventLoader: _getBookingsForDay,
            calendarStyle: const CalendarStyle(
              markerDecoration: BoxDecoration(
                color: Colors.deepPurple,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: bookingsToday.isEmpty
                ? const Center(child: Text("No bookings on this day"))
                : ListView.builder(
                    itemCount: bookingsToday.length,
                    itemBuilder: (context, index) {
                      final b = bookingsToday[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(b['status']),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(b['photographerName'] ?? 'Photographer'),
                          subtitle: Text(
                            "${b['service']} • ${b['notes'] ?? ''}",
                          ),
                          trailing: Text(b['status'].toString().toUpperCase()),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
