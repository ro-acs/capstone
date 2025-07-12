// File: lib/screens/withdrawal_history_photographer.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class WithdrawalHistoryPhotographer extends StatefulWidget {
  const WithdrawalHistoryPhotographer({super.key});

  @override
  State<WithdrawalHistoryPhotographer> createState() =>
      _WithdrawalHistoryPhotographerState();
}

class _WithdrawalHistoryPhotographerState
    extends State<WithdrawalHistoryPhotographer> {
  final user = FirebaseAuth.instance.currentUser!;
  double withdrawableEarnings = 0.0;
  bool isRequesting = false;

  @override
  void initState() {
    super.initState();
    _fetchWithdrawableEarnings();
  }

  Future<void> _fetchWithdrawableEarnings() async {
    final bookings = await FirebaseFirestore.instance
        .collection('bookings')
        .where('photographerId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'Completed')
        .get();

    final withdrawals = await FirebaseFirestore.instance
        .collection('withdrawals')
        .where('photographerId', isEqualTo: user.uid)
        .get();

    double totalEarnings = bookings.docs.fold(0.0, (sum, doc) {
      return sum + ((doc['price'] as num?)?.toDouble() ?? 0.0);
    });

    double totalWithdrawn = withdrawals.docs.fold(0.0, (sum, doc) {
      final status = doc['status'];
      if (status == 'Approved' || status == 'Processing') {
        return sum + ((doc['amount'] as num?)?.toDouble() ?? 0.0);
      }
      return sum;
    });

    setState(() {
      withdrawableEarnings = totalEarnings - totalWithdrawn;
    });
  }

  Future<void> _requestWithdrawal() async {
    if (withdrawableEarnings <= 0 || isRequesting) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final gcashNumber = userDoc['gcashNumber'] ?? '';
    final paypalEmail = userDoc['paypalEmail'] ?? '';

    if (gcashNumber.isEmpty && paypalEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add your GCash or PayPal info to request withdrawal.'),
        ),
      );
      return;
    }

    setState(() => isRequesting = true);

    await FirebaseFirestore.instance.collection('withdrawals').add({
      'photographerId': user.uid,
      'amount': withdrawableEarnings,
      'status': 'Processing',
      'requestedAt': FieldValue.serverTimestamp(),
      'gcashNumber': gcashNumber,
      'paypalEmail': paypalEmail,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Withdrawal request submitted.')),
    );

    await _fetchWithdrawableEarnings();
    setState(() => isRequesting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Withdrawal History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Withdrawable: ₱${withdrawableEarnings.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton(
                  onPressed: withdrawableEarnings > 0 && !isRequesting
                      ? _requestWithdrawal
                      : null,
                  child: isRequesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Withdraw Now'),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('withdrawals')
                  .where('photographerId', isEqualTo: user.uid)
                  .orderBy('requestedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No withdrawal requests yet.'),
                  );
                }

                final withdrawals = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: withdrawals.length,
                  itemBuilder: (context, index) {
                    final data =
                        withdrawals[index].data() as Map<String, dynamic>;
                    return ListTile(
                      leading: const Icon(Icons.money),
                      title: Text(
                        '₱${(data['amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                      ),
                      subtitle: Text('Status: ${data['status']}'),
                      trailing: Text(
                        data['requestedAt'] != null
                            ? (data['requestedAt'] as Timestamp)
                                  .toDate()
                                  .toString()
                            : 'Pending',
                        style: const TextStyle(fontSize: 12),
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
