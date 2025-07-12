// Enhanced UI for MyBookingsScreen with improved visuals and structure

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/paymongo_service.dart';

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('clientId', isEqualTo: currentUser.uid)
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final bookings = snapshot.data!.docs;
          if (bookings.isEmpty) {
            return const Center(
              child: Text(
                'No bookings found.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final doc = bookings[index];
              final data = doc.data() as Map<String, dynamic>;
              final status =
                  data['status']?.toString().toLowerCase() ?? 'pending';
              final paymentMethod =
                  data['paymentMethod']?.toString().toLowerCase() ?? '';
              final isUnpaid = status == 'pending_payment';
              final date = (data['date'] as Timestamp).toDate();
              final formattedDate = DateFormat.yMMMd().add_jm().format(date);

              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, color: Colors.deepPurple),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              data['photographerName'] ?? 'Photographer',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (status != 'cancelled' && status != 'completed')
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'cancel')
                                  _confirmCancel(context, doc.id);
                                if (value == 'reschedule')
                                  _reschedule(context, doc.id);
                                if (value == 'change_payment')
                                  _changePayment(
                                    context,
                                    doc.id,
                                    paymentMethod,
                                  );
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'cancel',
                                  child: Text('Cancel'),
                                ),
                                const PopupMenuItem(
                                  value: 'reschedule',
                                  child: Text('Reschedule'),
                                ),
                                if (isUnpaid)
                                  const PopupMenuItem(
                                    value: 'change_payment',
                                    child: Text('Change Payment Method'),
                                  ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Service: ${data['service'] ?? 'Service'}'),
                      Text('Date: $formattedDate'),
                      Text(
                        'Status: ${status.replaceAll('_', ' ').toUpperCase()}',
                      ),
                      if (data['rating'] != null)
                        Text('Rating: ${data['rating']} ★'),
                      const SizedBox(height: 8),
                      if (status == 'completed' &&
                          data['reviewSubmitted'] != true)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            icon: const Icon(Icons.rate_review),
                            label: const Text('Leave a Review'),
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/add_review',
                                arguments: {
                                  'photographerId': data['photographerId'],
                                  'photographerName': data['photographerName'],
                                  'bookingId': doc.id,
                                },
                              );
                            },
                          ),
                        ),
                      if (status == 'verifying_payment')
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('⏳ Payment is being verified...'),
                        ),
                      if (isUnpaid)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.payment),
                            label: Text(
                              'Pay Now (${paymentMethod.toUpperCase()})',
                            ),
                            onPressed: () async {
                              final amount =
                                  (data['package']['price'] ?? 0) * 100;
                              final id = doc.id;
                              final token = await FirebaseAuth
                                  .instance
                                  .currentUser
                                  ?.getIdToken();
                              final checkoutUrl =
                                  await PayMongoService.createGcashSource(
                                    amount: amount,
                                    successUrl:
                                        'http://capstone.x10.mx/gcashSuccess?collection=bookings&id=$id&token=$token',
                                    failedUrl: 'https://yourdomain.com/failed',
                                  );
                              if (checkoutUrl != null && context.mounted) {
                                launchUrl(
                                  Uri.parse(checkoutUrl),
                                  mode: LaunchMode.externalApplication,
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Failed to generate payment link.',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      if (status == 'completed' &&
                          data['paymentHistory'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Paid ₱${data['package']['price']} via ${paymentMethod.toUpperCase()}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.download),
                                tooltip: 'Download Invoice',
                                onPressed: () => _generateInvoice(
                                  context,
                                  data,
                                  formattedDate,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _generateInvoice(
    BuildContext context,
    Map<String, dynamic> data,
    String formattedDate,
  ) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'SnapSpot Payment Invoice',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Photographer: ${data['photographerName']}'),
              pw.Text('Service: ${data['service']}'),
              pw.Text('Date: $formattedDate'),
              pw.Text('Amount Paid: ₱${data['package']['price']}'),
              pw.Text('Payment Method: ${data['paymentMethod']}'),
              pw.SizedBox(height: 30),
              pw.Text(
                'Thank you for booking with SnapSpot!',
                style: pw.TextStyle(fontSize: 16),
              ),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  void _confirmCancel(BuildContext context, String bookingId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Cancel"),
        content: const Text("Are you sure you want to cancel this booking?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({'status': 'cancelled', 'cancelledAt': Timestamp.now()});
    }
  }

  void _reschedule(BuildContext context, String bookingId) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      initialDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
            'date': Timestamp.fromDate(picked),
            'status': 'pending_payment',
          });
    }
  }

  void _changePayment(
    BuildContext context,
    String bookingId,
    String currentMethod,
  ) async {
    String? newMethod = await showDialog<String>(
      context: context,
      builder: (context) {
        String? selected = currentMethod;
        return AlertDialog(
          title: const Text("Change Payment Method"),
          content: StatefulBuilder(
            builder: (context, setState) {
              final methods = ['gcash', 'paypal'];
              return DropdownButton<String>(
                value: methods.contains(selected) ? selected : null,
                isExpanded: true,
                items: methods.map((method) {
                  return DropdownMenuItem(
                    value: method,
                    child: Text(method[0].toUpperCase() + method.substring(1)),
                  );
                }).toList(),
                onChanged: (value) => setState(() => selected = value),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
    if (newMethod != null && newMethod != currentMethod) {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({'paymentMethod': newMethod, 'paymentProofs': []});
    }
  }
}
