import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'gcash_webview_payment.dart';

class BookSessionScreen extends StatefulWidget {
  final String photographerId;
  final String photographerName;
  final String serviceName;
  final double price;

  const BookSessionScreen({
    super.key,
    required this.photographerId,
    required this.photographerName,
    required this.serviceName,
    required this.price,
  });

  @override
  State<BookSessionScreen> createState() => _BookSessionScreenState();
}

class _BookSessionScreenState extends State<BookSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController locationController = TextEditingController();
  DateTime? selectedDate;
  String selectedPayment = 'GCash';

  Future<void> submitBooking() async {
    if (!_formKey.currentState!.validate() || selectedDate == null) return;

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final docRef = await FirebaseFirestore.instance
          .collection('bookings')
          .add({
            'clientId': user.uid,
            'clientName': user.displayName ?? 'Client',
            'photographerId': widget.photographerId,
            'photographerName': widget.photographerName,
            'serviceName': widget.serviceName,
            'price': widget.price,
            'location': locationController.text.trim(),
            'date': Timestamp.fromDate(selectedDate!),
            'status': 'Pending',
            'isPaid': false,
            'paymentMethod': selectedPayment,
            'createdAt': Timestamp.now(),
          });

      if (selectedPayment == 'GCash') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GCashWebViewPaymentScreen(
              paymentUrl: 'https://your-paymongo-checkout-link.com',
              contextType: 'booking',
              referenceId: docRef.id,
            ),
          ),
        );
      } else {
        Fluttertoast.showToast(msg: "PayPal payment simulated (success)");
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(docRef.id)
            .update({
              'isPaid': true,
              'paymentMethod': 'PayPal',
              'paidAt': Timestamp.now(),
            });
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BookingSuccessScreen()),
        );
      }
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book a Session')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text('Photographer: ${widget.photographerName}'),
              Text('Service: ${widget.serviceName}'),
              Text('Price: ₱${widget.price.toStringAsFixed(2)}'),
              const SizedBox(height: 12),
              TextFormField(
                controller: locationController,
                decoration: const InputDecoration(labelText: 'Location'),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter location' : null,
              ),
              const SizedBox(height: 12),
              ListTile(
                title: Text(
                  selectedDate == null
                      ? 'Choose a Date'
                      : 'Date: ${selectedDate!.toLocal().toString().split(" ")[0]}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => selectedDate = picked);
                  }
                },
              ),
              DropdownButtonFormField<String>(
                value: selectedPayment,
                items: ['GCash', 'PayPal']
                    .map(
                      (method) =>
                          DropdownMenuItem(value: method, child: Text(method)),
                    )
                    .toList(),
                onChanged: (val) => setState(() => selectedPayment = val!),
                decoration: const InputDecoration(labelText: 'Payment Method'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: submitBooking,
                child: const Text('Book and Pay'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BookingSuccessScreen extends StatelessWidget {
  const BookingSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 100),
              const SizedBox(height: 20),
              const Text(
                'Booking Confirmed!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your booking was successful. You will receive a confirmation soon.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/dashboard_client',
                    (route) => false,
                  );
                },
                child: const Text('Go to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
