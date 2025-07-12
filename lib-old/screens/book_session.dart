import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'payment_screen.dart';

class BookSessionPage extends StatefulWidget {
  final String photographerId;
  const BookSessionPage({super.key, required this.photographerId});

  @override
  State<BookSessionPage> createState() => _BookSessionPageState();
}

class _BookSessionPageState extends State<BookSessionPage> {
  DateTime? selectedDate;
  String? selectedTimeSlot;
  String? selectedService;
  Map<String, dynamic>? selectedPackage;
  String? selectedPackageName;
  String? selectedPaymentMethod;
  String? notes;
  bool isSubmitting = false;

  final TextEditingController _promoController = TextEditingController();
  String? promoStatus;
  double promoDiscount = 0.0;
  String? promoType;

  final timeSlots = ["9:00 AM", "11:00 AM", "1:00 PM", "3:00 PM", "5:00 PM"];
  final paymentMethods = ["GCash", "PayPal"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple[50],
      appBar: AppBar(
        title: const Text('Book a Session'),
        backgroundColor: Colors.deepPurple,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('tblusers')
            .doc(widget.photographerId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final photographerName = data['fullName'] ?? 'Photographer';
          final services = List<String>.from(data['services'] ?? []);
          final packages = List<Map<String, dynamic>>.from(
            data['packages'] ?? [],
          );

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Text(
                  'Photographer: $photographerName',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Select a Service:'),
                DropdownButton<String>(
                  value: selectedService,
                  hint: const Text('Choose service'),
                  isExpanded: true,
                  items: services
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (value) => setState(() => selectedService = value),
                ),
                const SizedBox(height: 16),

                const Text('Select a Package:'),
                DropdownButton<String>(
                  value: selectedPackageName,
                  hint: const Text('Choose package'),
                  isExpanded: true,
                  items: packages.map((pkg) {
                    final name = pkg['name'] ?? 'Package';
                    final price = pkg['price'] ?? 0;
                    return DropdownMenuItem<String>(
                      value: name,
                      child: Text('$name (₱$price)'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedPackageName = value;
                      selectedPackage = packages.firstWhere(
                        (pkg) => pkg['name'] == value,
                      );
                    });
                  },
                ),
                if (selectedPackage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    selectedPackage!['description'] ?? 'No description.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  Text(
                    'Price: ₱${selectedPackage!['price'] ?? '0'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
                const SizedBox(height: 16),

                const Text('Select a Date:'),
                ElevatedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (picked != null) {
                      setState(() => selectedDate = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    selectedDate == null
                        ? 'Pick Date'
                        : DateFormat.yMMMMd().format(selectedDate!),
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Select a Time Slot:'),
                Wrap(
                  spacing: 8,
                  children: timeSlots.map((slot) {
                    return ChoiceChip(
                      label: Text(slot),
                      selected: selectedTimeSlot == slot,
                      onSelected: (_) =>
                          setState(() => selectedTimeSlot = slot),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                const Text('Select Payment Method:'),
                DropdownButton<String>(
                  value: selectedPaymentMethod,
                  hint: const Text('Choose payment method'),
                  isExpanded: true,
                  items: paymentMethods.map((method) {
                    return DropdownMenuItem(
                      value: method.toLowerCase().replaceAll(' ', '_'),
                      child: Text(method),
                    );
                  }).toList(),
                  onChanged: (value) =>
                      setState(() => selectedPaymentMethod = value),
                ),
                const SizedBox(height: 16),

                const Text('Add Notes (optional):'),
                TextField(
                  onChanged: (value) => notes = value,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter any additional details here',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Promo Code (optional):'),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _promoController,
                        decoration: const InputDecoration(
                          hintText: 'Enter promocode',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _applyPromo,
                      child: const Text('Apply'),
                    ),
                  ],
                ),
                if (promoStatus != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      promoStatus!,
                      style: TextStyle(
                        color: promoDiscount > 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
                if (selectedPackage != null)
                  Text(
                    'Total: ₱${((selectedPackage!['price'] ?? 0) - promoDiscount).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(height: 12),

                ElevatedButton.icon(
                  onPressed: _canSubmit() ? _submitBooking : null,
                  icon: const Icon(Icons.send),
                  label: isSubmitting
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('Confirm Booking'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.deepPurple,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _applyPromo() async {
    final code = _promoController.text.trim();
    if (code.isEmpty || selectedPackage == null) {
      setState(() {
        promoStatus = 'Enter a valid promocode.';
        promoDiscount = 0.0;
        promoType = null;
      });
      return;
    }

    final promoSnap = await FirebaseFirestore.instance
        .collection('tblpromocodes')
        .doc(code.toLowerCase())
        .get();

    if (promoSnap.exists) {
      final data = promoSnap.data()!;
      final discountType = data['type'] ?? 'flat';
      final value = data['value'] ?? 0;

      setState(() {
        if (discountType == 'percent') {
          promoDiscount = (selectedPackage!['price'] ?? 0) * (value / 100);
        } else {
          promoDiscount = value * 1.0;
        }
        promoStatus =
            'Promo applied: $value ${discountType == 'percent' ? '% off' : '₱ off'}';
        promoType = discountType;
      });
    } else {
      setState(() {
        promoDiscount = 0.0;
        promoStatus = 'Invalid promocode.';
        promoType = null;
      });
    }
  }

  bool _canSubmit() {
    return !isSubmitting &&
        selectedDate != null &&
        selectedTimeSlot != null &&
        selectedService != null &&
        selectedPackage != null &&
        selectedPaymentMethod != null;
  }

  Future<void> _submitBooking() async {
    setState(() => isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Not authenticated.");

      final photographerDoc = await FirebaseFirestore.instance
          .collection('tblusers')
          .doc(widget.photographerId)
          .get();

      final photographerName =
          photographerDoc.data()?['fullName'] ?? 'Photographer';

      final booking = {
        'created_at': Timestamp.now(),
        'credit': 0,
        'date_cancelled': '0000-00-00 00:00:00',
        'date_refunded': '0000-00-00 00:00:00',
        'datepaid': '0000-00-00 00:00:00',
        'id': user.uid,
        'invoicenum': null,
        'last_capture_attempt': '0000-00-00 00:00:00',
        'notes': notes ?? '',
        'paymentmethod': selectedPaymentMethod,
        'paymethodid': 1,
        'promocode': _promoController.text.trim().isEmpty
            ? null
            : _promoController.text.trim(),
        'promotype': promoType,
        'promovalue': promoDiscount,
        'total': ((selectedPackage!['price'] ?? 0) - promoDiscount)
            .toStringAsFixed(2),
        'status': 'pending_payment',
        'subtotal': 0,
        'updated_at': Timestamp.now(),
        'photographer_id': widget.photographerId,
        'service': selectedService,
        'package': selectedPackage,
        'service_date': selectedDate,
        'timeSlot': selectedTimeSlot,
      };

      final bookingRef = await FirebaseFirestore.instance
          .collection('tblinvoices')
          .add(booking);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            userId: FirebaseAuth.instance.currentUser!.uid,
            contextMode: 'booking',
            bookingId: bookingRef.id,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => isSubmitting = false);
    }
  }
}
