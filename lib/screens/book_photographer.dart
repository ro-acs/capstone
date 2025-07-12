import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BookPhotographerScreen extends StatefulWidget {
  final String photographerId;

  const BookPhotographerScreen({super.key, required this.photographerId});

  @override
  State<BookPhotographerScreen> createState() => _BookPhotographerScreenState();
}

class _BookPhotographerScreenState extends State<BookPhotographerScreen> {
  List<Map<String, dynamic>> _services = [];
  Set<String> _selectedServiceIds = {};
  double _totalPrice = 0.0;

  final _promoController = TextEditingController();
  String? _promoMessage;
  double _discountAmount = 0.0;
  String _appliedPromoCode = '';

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('services')
        .where('photographerId', isEqualTo: widget.photographerId)
        .get();

    setState(() {
      _services = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  void _toggleService(String serviceId, double price) {
    setState(() {
      if (_selectedServiceIds.contains(serviceId)) {
        _selectedServiceIds.remove(serviceId);
        _totalPrice -= price;
      } else {
        _selectedServiceIds.add(serviceId);
        _totalPrice += price;
      }
      _discountAmount = 0;
      _promoMessage = null;
      _appliedPromoCode = '';
    });
  }

  Future<void> _applyPromoCode() async {
    final code = _promoController.text.trim().toUpperCase();
    final userId = FirebaseAuth.instance.currentUser!.uid;

    final query = await FirebaseFirestore.instance
        .collection('promotions')
        .where('code', isEqualTo: code)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      setState(() {
        _promoMessage = "Promo code not valid";
        _discountAmount = 0;
        _appliedPromoCode = '';
      });
      return;
    }

    final promoSnap = query.docs.first;
    final promoRef = promoSnap.reference;
    final data = promoSnap.data();
    final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
    final usageLimit = data['usageLimit'] ?? 0;

    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      setState(() {
        _promoMessage = "Promo code has expired";
        _discountAmount = 0;
        _appliedPromoCode = '';
      });
      return;
    }

    final usageSnap = await promoRef.collection('usages').get();
    if (usageLimit > 0 && usageSnap.size >= usageLimit) {
      setState(() {
        _promoMessage = "Promo code usage limit reached";
        _discountAmount = 0;
        _appliedPromoCode = '';
      });
      return;
    }

    final userUsage = await promoRef.collection('usages').doc(userId).get();
    if (userUsage.exists) {
      setState(() {
        _promoMessage = "You have already used this promo code";
        _discountAmount = 0;
        _appliedPromoCode = '';
      });
      return;
    }

    final type = data['type'];
    final dynamic rawValue = data['value'];
    double value;
    if (rawValue is String) {
      value = double.tryParse(rawValue) ?? 0;
    } else if (rawValue is int) {
      value = rawValue.toDouble();
    } else if (rawValue is double) {
      value = rawValue;
    } else {
      value = 0;
    }

    setState(() {
      _appliedPromoCode = code;
      if (type == 'flat') {
        _discountAmount = value;
        _promoMessage = '₱$value off';
      } else if (type == 'percent') {
        _discountAmount = _totalPrice * (value / 100);
        _promoMessage = '$value% off';
      } else {
        _promoMessage = "Invalid promo type";
        _discountAmount = 0;
        _appliedPromoCode = '';
      }
    });
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay(hour: 9, minute: 0),
    );

    if (time != null) {
      setState(() {
        _selectedDate = date;
        _selectedTime = time;
      });
    }
  }

  void _bookNow() async {
    if (_selectedServiceIds.isEmpty ||
        _selectedDate == null ||
        _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete all fields.")),
      );
      return;
    }

    final userId = FirebaseAuth.instance.currentUser!.uid;
    final finalPrice = (_totalPrice - _discountAmount).clamp(
      0,
      double.infinity,
    );

    // ✅ Fetch photographer name
    final photographerDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.photographerId)
        .get();
    final photographerName = photographerDoc.data()?['name'] ?? 'Photographer';

    final doc = await FirebaseFirestore.instance.collection('bookings').add({
      'photographerId': widget.photographerId,
      'photographerName': photographerName, // ✅ REQUIRED FOR DASHBOARD
      'clientId': userId,
      'serviceIds': _selectedServiceIds.toList(),
      'basePrice': _totalPrice,
      'discountAmount': _discountAmount,
      'finalPrice': finalPrice,
      'promoCode': _appliedPromoCode,
      'bookingDate': _selectedDate,
      'bookingTime': _selectedTime?.format(context),
      'note': _noteController.text.trim(),
      'status': 'Pending', // optional: set default booking status
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (_appliedPromoCode.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('promotions')
          .doc(_appliedPromoCode)
          .collection('usages')
          .doc(userId)
          .set({'usedAt': FieldValue.serverTimestamp(), 'bookingId': doc.id});
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Booking confirmed!")));
  }

  @override
  Widget build(BuildContext context) {
    final finalPrice = (_totalPrice - _discountAmount).clamp(
      0,
      double.infinity,
    );
    final selectedDateTime = (_selectedDate != null && _selectedTime != null)
        ? DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            _selectedTime!.hour,
            _selectedTime!.minute,
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Book Photographer"),
        backgroundColor: const Color(0xFF7F00FF),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select Services",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._services.map((s) {
              final selected = _selectedServiceIds.contains(s['id']);
              return CheckboxListTile(
                value: selected,
                onChanged: (_) =>
                    _toggleService(s['id'], (s['price'] ?? 0).toDouble()),
                title: Text(s['serviceName'] ?? 'Service'),
                subtitle: Text(s['description'] ?? ''),
                secondary: Text('₱${s['price']}'),
              );
            }),
            const SizedBox(height: 12),
            TextField(
              controller: _promoController,
              decoration: InputDecoration(
                labelText: "Promotion Code",
                suffixIcon: TextButton(
                  child: const Text("Apply"),
                  onPressed: _applyPromoCode,
                ),
              ),
            ),
            if (_promoMessage != null) ...[
              const SizedBox(height: 8),
              Text(_promoMessage!, style: const TextStyle(color: Colors.green)),
            ],
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text(
                selectedDateTime != null
                    ? DateFormat(
                        'MMMM d, yyyy – hh:mm a',
                      ).format(selectedDateTime)
                    : 'Choose date and time',
              ),
              onPressed: _selectDateTime,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Additional Notes (optional)",
                border: OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            Text(
              _discountAmount > 0
                  ? "Discount: -₱${_discountAmount.toStringAsFixed(2)}"
                  : "",
              style: const TextStyle(fontSize: 16, color: Colors.green),
            ),
            Text(
              "Total: ₱${finalPrice.toStringAsFixed(2)}",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _bookNow,
              child: const Text("Book Now"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepPurple,
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
