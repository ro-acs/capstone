import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VerifyPaymentsAdminScreen extends StatelessWidget {
  final _db = FirebaseFirestore.instance;

  Future<void> _verify(String bookingId, String status) async {
    await _db.collection('bookings').doc(bookingId).update({
      'paymentStatus': status,
      'verifiedAt': Timestamp.now(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Verify Payments')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('bookings')
            .where('paymentStatus', isEqualTo: 'Pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());

          final bookings = snapshot.data!.docs;

          if (bookings.isEmpty)
            return Center(child: Text('No pending payments'));

          return ListView.builder(
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final data = bookings[index].data() as Map<String, dynamic>;
              final id = bookings[index].id;

              return Card(
                margin: EdgeInsets.all(8),
                child: ListTile(
                  title: Text('From: ${data['clientEmail'] ?? ''}'),
                  subtitle: Text(
                    'Method: ${data['paymentMethod'] ?? 'Unknown'}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.check, color: Colors.green),
                        onPressed: () => _verify(id, 'Verified'),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.red),
                        onPressed: () => _verify(id, 'Rejected'),
                      ),
                    ],
                  ),
                  onTap: () {
                    if (data['paymentProofUrl'] != null &&
                        data['paymentProofUrl'].isNotEmpty) {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          content: Image.network(data['paymentProofUrl']),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text("Close"),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
