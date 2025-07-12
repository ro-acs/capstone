import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class BookingCalendarPhotographer extends StatefulWidget {
  const BookingCalendarPhotographer({super.key});

  @override
  State<BookingCalendarPhotographer> createState() => _BookingCalendarPhotographerState();
}

class _BookingCalendarPhotographerState extends State<BookingCalendarPhotographer> {
  final user = FirebaseAuth.instance.currentUser!;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Map<String, dynamic>> _selectedEvents = [];

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('photographerId', isEqualTo: user.uid)
        .get();

    Map<DateTime, List<Map<String, dynamic>>> data = {};

    for (var doc in snapshot.docs) {
      final dataMap = doc.data();
      final Timestamp timestamp = dataMap['date'];
      final DateTime date = DateTime(timestamp.toDate().year, timestamp.toDate().month, timestamp.toDate().day);

      if (!data.containsKey(date)) {
        data[date] = [];
      }

      data[date]!.add({
        'clientName': dataMap['clientName'],
        'status': dataMap['status'],
        'time': dataMap['time'],
        'bookingId': doc.id,
      });
    }

    setState(() {
      _events = data;
      _selectedDay = _focusedDay;
      _selectedEvents = _events[_focusedDay] ?? [];
    });
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  Widget _buildEventList() {
    if (_selectedEvents.isEmpty) {
      return const Center(child: Text("No bookings for this date."));
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: _selectedEvents.length,
      itemBuilder: (context, index) {
        final event = _selectedEvents[index];
        return Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _statusColor(event['status']),
              child: Icon(Icons.event, color: Colors.white),
            ),
            title: Text(event['clientName']),
            subtitle: Text("Time: ${event['time']}"),
            trailing: Text(
              event['status'],
              style: TextStyle(color: _statusColor(event['status']), fontWeight: FontWeight.bold),
            ),
            onTap: () {
              // Optional: Open booking detail page
            },
          ),
        );
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Confirmed':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildReminderBanner() {
    final upcoming = _events.entries
        .where((entry) => entry.key.difference(DateTime.now()).inDays <= 3 && entry.key.isAfter(DateTime.now()))
        .expand((entry) => entry.value)
        .toList();

    if (upcoming.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "You have upcoming bookings in the next 3 days.",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Booking Calendar"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildReminderBanner(),
            TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: _getEventsForDay,
              calendarFormat: CalendarFormat.month,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                  _selectedEvents = _getEventsForDay(selectedDay);
                });
              },
              calendarStyle: const CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Colors.deepPurple,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Colors.purple,
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildEventList()),
          ],
        ),
      ),
    );
  }
}
