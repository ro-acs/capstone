import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';

class BookingDetailScreen extends StatelessWidget {
  final String bookingId;

  const BookingDetailScreen({super.key, required this.bookingId});

  String getChatId(String uid1, String uid2) {
    List<String> uids = [uid1, uid2];
    uids.sort();
    return '${uids[0]}_${uids[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Booking Details")),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || !snapshot.data!.exists)
            return const Center(child: Text("Booking not found"));

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final List<dynamic> serviceIds = data['services'] ?? [];
          final total = (data['finalPrice'] as num?)?.toDouble() ?? 0.0;
          final partialPayments = List<Map<String, dynamic>>.from(
            data['partialPayment'] ?? [],
          );
          final partial = partialPayments.fold<double>(
            0.0,
            (sum, item) => sum + ((item['price'] ?? 0) as num).toDouble(),
          );
          final isPaid = data['isPaid'] ?? false;
          final status = data['status'] ?? 'pending';
          final bookingDate = (data['bookingDate'] as Timestamp?)?.toDate();
          final notes = data['note'] ?? '';
          final formatDate = bookingDate != null
              ? DateFormat.yMMMd().add_jm().format(bookingDate)
              : 'N/A';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Status: ${status.toUpperCase()}",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                Text("Booking Date: $formatDate"),
                const SizedBox(height: 10),
                if (notes.isNotEmpty) Text("Note: $notes"),
                const SizedBox(height: 20),

                const Text(
                  "Selected Services",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                FutureBuilder<List<DocumentSnapshot>>(
                  future: Future.wait(
                    serviceIds.map((id) {
                      return FirebaseFirestore.instance
                          .collection('services')
                          .doc(id)
                          .get();
                    }),
                  ),
                  builder: (context, serviceSnapshot) {
                    if (serviceSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!serviceSnapshot.hasData ||
                        serviceSnapshot.data!.isEmpty) {
                      return const Text("No services found.");
                    }

                    final serviceDocs = serviceSnapshot.data!;

                    // ✅ Sort alphabetically by service name
                    serviceDocs.sort((a, b) {
                      final nameA =
                          (a.data() as Map<String, dynamic>)['name'] ?? '';
                      final nameB =
                          (b.data() as Map<String, dynamic>)['name'] ?? '';
                      return nameA.toString().compareTo(nameB.toString());
                    });

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: serviceDocs.map((doc) {
                        final service = doc.data() as Map<String, dynamic>;
                        final name = service['name'] ?? 'Unnamed Service';
                        final price = service['price'] ?? 0;
                        final description =
                            service['description'] ?? 'No description';
                        final duration = service['duration'] ?? 'N/A';
                        final thumbnail = service['thumbnail'] ?? null;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: thumbnail != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      thumbnail,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.broken_image),
                                    ),
                                  )
                                : const Icon(Icons.photo, size: 60),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text("₱$price • $duration mins"),
                                const SizedBox(height: 4),
                                Text(description),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                ...List.generate(services.length, (i) {
                  final service = services[i];
                  return ListTile(
                    title: Text(service['name'] ?? 'Service ${i + 1}'),
                    subtitle: Text("₱${(service['price'] ?? 0).toString()}"),
                  );
                }),
                const Divider(),
                ListTile(
                  title: const Text("Total Price"),
                  trailing: Text("₱${total.toStringAsFixed(2)}"),
                ),
                ListTile(
                  title: const Text("Partial Paid"),
                  trailing: Text("₱${partial.toStringAsFixed(2)}"),
                ),
                ListTile(
                  title: const Text("Payment Status"),
                  trailing: Text(isPaid ? "Fully Paid" : "Pending"),
                ),
                const SizedBox(height: 20),

                // Action buttons
                if (!isPaid)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.payment),
                    label: const Text("Make Payment"),
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/makePayment',
                        arguments: bookingId,
                      );
                    },
                  ),
                if (status != 'cancelled' && status != 'completed')
                  TextButton.icon(
                    icon: const Icon(Icons.cancel),
                    label: const Text("Cancel Booking"),
                    onPressed: () {
                      _confirmCancel(context, bookingId);
                    },
                  ),
                if (status == 'completed')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.reviews),
                    label: const Text("Leave a Review"),
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/leaveReview',
                        arguments: bookingId,
                      );
                    },
                  ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.chat),
                  label: const Text("Chat with Photographer"),
                  onPressed: () {
                    final chatId = getChatId(
                      data['userId'],
                      data['photographerId'],
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          chatId: chatId,
                          receiverId: data['photographerId'],
                          receiverName: data['photographerName'],
                          receiverAvatar: '',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmCancel(BuildContext context, String bookingId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Booking"),
        content: const Text("Are you sure you want to cancel this booking?"),
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

    if (result == true) {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({'status': 'cancelled'});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Booking cancelled")));
    }
  }
}
