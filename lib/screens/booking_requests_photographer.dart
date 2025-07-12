// Add necessary imports
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class BookingRequestsPhotographerScreen extends StatefulWidget {
  const BookingRequestsPhotographerScreen({super.key});

  @override
  State<BookingRequestsPhotographerScreen> createState() =>
      _BookingRequestsPhotographerScreenState();
}

class _BookingRequestsPhotographerScreenState
    extends State<BookingRequestsPhotographerScreen> {
  final user = FirebaseAuth.instance.currentUser!;
  String searchQuery = '';
  String statusFilter = 'All';
  String locationFilter = '';
  double minPrice = 0;
  double maxPrice = double.infinity;
  String sortOption = 'Latest';
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Future<void> generateInvoice(Map<String, dynamic> booking) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('SnapSpot Invoice', style: pw.TextStyle(fontSize: 20)),
            pw.SizedBox(height: 10),
            pw.Text('Client: ${booking['clientName']}'),
            pw.Text('Service: ${booking['serviceName']}'),
            pw.Text('Date: ${booking['date']}'),
            pw.Text('Location: ${booking['location']}'),
            pw.Text('Status: ${booking['status']}'),
            pw.Text('Amount: PHP ${booking['price'].toStringAsFixed(2)}'),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final bookingRef = FirebaseFirestore.instance
        .collection('bookings')
        .where('photographerId', isEqualTo: user.uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Requests'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(150),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by client, service, or location',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                  ),
                  onChanged: (val) => setState(() => searchQuery = val),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DropdownButton<String>(
                    value: statusFilter,
                    items:
                        ['All', 'Pending', 'Approved', 'Completed', 'Cancelled']
                            .map(
                              (status) => DropdownMenuItem(
                                value: status,
                                child: Text(status),
                              ),
                            )
                            .toList(),
                    onChanged: (val) => setState(() => statusFilter = val!),
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<String>(
                    value: sortOption,
                    items: ['Latest', 'Price Low to High', 'Price High to Low']
                        .map(
                          (sort) =>
                              DropdownMenuItem(value: sort, child: Text(sort)),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => sortOption = val!),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          TableCalendar(
            focusedDay: _focusedDay,
            firstDay: DateTime.utc(2020),
            lastDay: DateTime.utc(2030),
            selectedDayPredicate: (day) =>
                _selectedDay != null &&
                day.year == _selectedDay!.year &&
                day.month == _selectedDay!.month &&
                day.day == _selectedDay!.day,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: bookingRef.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                List<DocumentSnapshot> bookings = snapshot.data!.docs;

                // Apply filtering
                bookings = bookings.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nameMatch = (data['clientName'] ?? '')
                      .toString()
                      .toLowerCase()
                      .contains(searchQuery.toLowerCase());
                  final serviceMatch = (data['serviceName'] ?? '')
                      .toString()
                      .toLowerCase()
                      .contains(searchQuery.toLowerCase());
                  final locationMatch = (data['location'] ?? '')
                      .toString()
                      .toLowerCase()
                      .contains(searchQuery.toLowerCase());
                  final statusMatch =
                      statusFilter == 'All' ||
                      (data['status'] ?? '') == statusFilter;
                  final priceMatch =
                      (data['price'] ?? 0) >= minPrice &&
                      (data['price'] ?? 0) <= maxPrice;
                  final dateMatch =
                      _selectedDay == null ||
                      (data['date'] as String).startsWith(
                        DateFormat('yyyy-MM-dd').format(_selectedDay!),
                      );

                  return (nameMatch || serviceMatch || locationMatch) &&
                      statusMatch &&
                      priceMatch &&
                      dateMatch;
                }).toList();

                // Apply sorting
                if (sortOption == 'Latest') {
                  bookings.sort((a, b) {
                    final aDate = a['timestamp'] ?? '';
                    final bDate = b['timestamp'] ?? '';
                    return bDate.compareTo(aDate);
                  });
                } else if (sortOption == 'Price Low to High') {
                  bookings.sort(
                    (a, b) => (a['price'] as num).compareTo(b['price'] as num),
                  );
                } else if (sortOption == 'Price High to Low') {
                  bookings.sort(
                    (a, b) => (b['price'] as num).compareTo(a['price'] as num),
                  );
                }

                if (bookings.isEmpty) {
                  return const Center(child: Text('No bookings found.'));
                }

                return ListView.builder(
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final doc = bookings[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: Text(data['clientName'] ?? 'Client'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${data['serviceName']}'),
                            Text('Date: ${data['date']}'),
                            Text('Location: ${data['location']}'),
                            Text('Status: ${data['status']}'),
                          ],
                        ),
                        trailing: Wrap(
                          spacing: 6,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.picture_as_pdf),
                              onPressed: () => generateInvoice(data),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chat),
                              onPressed: () {
                                // Navigate to chat screen
                                Navigator.pushNamed(
                                  context,
                                  '/chat_with_clients',
                                  arguments: {'clientId': data['clientId']},
                                );
                              },
                            ),
                            if (data['status'] == 'Pending') ...[
                              IconButton(
                                icon: const Icon(
                                  Icons.check,
                                  color: Colors.green,
                                ),
                                onPressed: () async {
                                  await doc.reference.update({
                                    'status': 'Approved',
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                ),
                                onPressed: () async {
                                  await doc.reference.update({
                                    'status': 'Cancelled',
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
