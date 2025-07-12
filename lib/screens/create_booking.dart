import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateBookingScreen extends StatefulWidget {
  final String photographerId;
  final String photographerEmail;

  const CreateBookingScreen({
    required this.photographerId,
    required this.photographerEmail,
  });

  @override
  _CreateBookingScreenState createState() => _CreateBookingScreenState();
}

class _CreateBookingScreenState extends State<CreateBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  DateTime? _selectedDate;

  bool _loading = false;
  String? _error;

  Future<void> _submitBooking() async {
    if (_selectedDate == null || !_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _loading = true;
    });

    try {
      await FirebaseFirestore.instance.collection('bookings').add({
        'clientId': user.uid,
        'clientEmail': user.email,
        'photographerId': widget.photographerId,
        'photographerEmail': widget.photographerEmail,
        'date': _selectedDate,
        'note': _noteController.text,
        'status': 'Pending',
        'createdAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Booking request sent!')));
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = 'Failed to create booking.';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Create Booking")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    Text(
                      "Booking with ${widget.photographerEmail}",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    ListTile(
                      title: Text(
                        _selectedDate == null
                            ? 'Select a date'
                            : 'Selected: ${_selectedDate!.toLocal()}'.split(
                                ' ',
                              )[0],
                      ),
                      trailing: Icon(Icons.calendar_today),
                      onTap: _pickDate,
                    ),
                    TextFormField(
                      controller: _noteController,
                      decoration: InputDecoration(
                        labelText: "Additional Notes (optional)",
                      ),
                      maxLines: 3,
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _submitBooking,
                      child: Text("Submit Booking"),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
