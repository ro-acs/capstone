import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  final bool isPhotographerView;
  const MyBookingsScreen({super.key, this.isPhotographerView = false});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final currentUser = FirebaseAuth.instance.currentUser!;

  String getChatId(String uid1, String uid2) {
    List<String> uids = [uid1, uid2];
    uids.sort();
    return '${uids[0]}_${uids[1]}';
  }

  List<Map<String, dynamic>> bookings = [];
  bool isLoading = true;
  String sortOption = 'Date';
  late Stream<QuerySnapshot> bookingStream;

  @override
  void initState() {
    super.initState();
    bookingStream = FirebaseFirestore.instance
        .collection('bookings')
        .where(
          widget.isPhotographerView ? 'photographerId' : 'clientId',
          isEqualTo: currentUser.uid,
        )
        .snapshots();
  }

  Future<void> cancelBooking(String bookingId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Cancel Booking"),
        content: const Text(
          "Are you sure you want to cancel this booking? Any payments will not be refunded.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          TextButton(
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
          .update({'status': 'Cancelled'});

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Booking cancelled")));
    }
  }

  List<Map<String, dynamic>> parseBookings(QuerySnapshot snapshot) {
    final List<Map<String, dynamic>> fetched = [];

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;

      final finalPrice = (data['finalPrice'] as num?)?.toDouble() ?? 0.0;
      final status = data['status'] ?? 'Unknown';
      final discount = (data['discountAmount'] as num?)?.toDouble() ?? 0.0;
      final promoCode = data['promoCode'] ?? '';

      double partialTotal = 0.0;
      List<Map<String, dynamic>> history = [];

      final partial = data['partialPayment'];

      if (partial is List) {
        for (var entry in partial) {
          if (entry is Map &&
              entry['price'] is num &&
              entry['date'] is Timestamp) {
            final price = (entry['price'] as num).toDouble();
            final date = (entry['date'] as Timestamp).toDate();
            partialTotal += price;
            history.add({'price': price, 'date': date});
          }
        }
      }

      final remaining = (finalPrice - partialTotal).clamp(0, double.infinity);

      fetched.add({
        'id': doc.id,
        'otherUserName': widget.isPhotographerView
            ? data['clientName'] ?? 'Client'
            : data['photographerName'] ?? 'Photographer',
        'bookingDate': (data['bookingDate'] as Timestamp).toDate(),
        'finalPrice': finalPrice,
        'partialPaid': partialTotal,
        'partialHistory': history,
        'remaining': remaining,
        'status': status,
        'otherUserId': widget.isPhotographerView
            ? data['clientId']
            : data['photographerId'],
        'discount': discount,
        'promoCode': promoCode,
        'isPaid': data['isPaid'] ?? false,
      });
    }

    if (sortOption == 'Amount') {
      fetched.sort((a, b) => b['finalPrice'].compareTo(a['finalPrice']));
    } else {
      fetched.sort((a, b) => b['bookingDate'].compareTo(a['bookingDate']));
    }

    return fetched;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isPhotographerView ? "Client Bookings" : "My Bookings",
        ),
        backgroundColor: Colors.deepPurple,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                sortOption = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Date', child: Text("Sort by Date")),
              const PopupMenuItem(
                value: 'Amount',
                child: Text("Sort by Amount"),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: bookingStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final bookings = parseBookings(snapshot.data!);

          if (bookings.isEmpty) {
            return const Center(child: Text("No bookings found."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final b = bookings[index];
              final isFullyPaid = b['isPaid'] == true;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 3,
                child: ExpansionTile(
                  title: Text(b['otherUserName']),
                  subtitle: Text(
                    DateFormat('MMMM d, yyyy').format(b['bookingDate']),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Paid: ₱${b['partialPaid'].toStringAsFixed(2)} / ₱${b['finalPrice'].toStringAsFixed(2)}",
                          ),
                          if (isFullyPaid)
                            const Text(
                              "Fully Paid",
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else
                            Text(
                              "Remaining: ₱${b['remaining'].toStringAsFixed(2)}",
                            ),
                          Text("Status: ${b['status']}"),
                          if ((b['discount'] as double) > 0)
                            Text(
                              b['promoCode'] != ''
                                  ? "Promo Applied: ${b['promoCode']} — You saved ₱${(b['discount'] as double).toStringAsFixed(2)}"
                                  : "You saved ₱${(b['discount'] as double).toStringAsFixed(2)}",
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (b['partialHistory'].isNotEmpty) ...[
                            const SizedBox(height: 6),
                            const Text("Payment History:"),
                            ...b['partialHistory'].map<Widget>((entry) {
                              final amount = entry['price'] as double;
                              final date = entry['date'] as DateTime;
                              final formattedDate = DateFormat(
                                'MMM d, yyyy • hh:mm a',
                              ).format(date);
                              return Text(
                                "• ₱${amount.toStringAsFixed(2)} on $formattedDate",
                              );
                            }).toList(),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.info),
                                label: const Text("Details"),
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/booking_detail',
                                    arguments: b['id'],
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.chat),
                                label: const Text("Chat"),
                                onPressed: () {
                                  final chatId = getChatId(
                                    currentUser.uid,
                                    b['otherUserId'],
                                  );
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        chatId: chatId,
                                        receiverId: b['otherUserId'],
                                        receiverName: b['otherUserName'],
                                        receiverAvatar: '',
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              if (!widget.isPhotographerView &&
                                  b['status'] != 'Completed' &&
                                  b['status'] != 'Cancelled')
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      Navigator.pushNamed(
                                        context,
                                        '/edit_booking',
                                        arguments: b['id'],
                                      );
                                    } else if (value == 'cancel') {
                                      cancelBooking(b['id']);
                                    } else if (value == 'pay') {
                                      Navigator.pushNamed(
                                        context,
                                        '/make_payment',
                                        arguments: {
                                          'bookingId': b['id'],
                                          'remaining': b['remaining'],
                                          'photographerId': b['otherUserId'],
                                          'clientId': currentUser.uid,
                                        },
                                      );
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem<String>(
                                      value: 'edit',
                                      child: ListTile(
                                        leading: Icon(Icons.edit),
                                        title: Text("Edit Booking"),
                                      ),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'cancel',
                                      child: ListTile(
                                        leading: Icon(
                                          Icons.cancel,
                                          color: Colors.red,
                                        ),
                                        title: Text("Cancel Booking"),
                                      ),
                                    ),
                                    if (!isFullyPaid)
                                      const PopupMenuItem<String>(
                                        value: 'pay',
                                        child: ListTile(
                                          leading: Icon(Icons.payment),
                                          title: Text("Make a Payment"),
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
