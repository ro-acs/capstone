import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentScreen extends StatefulWidget {
  final String contextType; // 'registration' or 'booking'
  final String referenceId; // userId or bookingId

  const PaymentScreen({
    required this.contextType,
    required this.referenceId,
    super.key,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedMethod = 'GCash';
  File? _proofImage;
  bool _uploading = false;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _proofImage = File(picked.path);
      });
    }
  }

  Future<void> _submitPayment() async {
    if (_selectedMethod == 'GCash' && _proofImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please upload payment proof')));
      return;
    }

    setState(() => _uploading = true);
    final storageRef = FirebaseStorage.instance.ref().child(
      'payment_proofs/${widget.contextType}_${widget.referenceId}.jpg',
    );

    String? url;
    if (_proofImage != null) {
      await storageRef.putFile(_proofImage!);
      url = await storageRef.getDownloadURL();
    }

    final data = {
      'paymentMethod': _selectedMethod,
      'paymentStatus': 'Pending',
      'paymentSubmittedAt': Timestamp.now(),
      'paymentProofUrl': url ?? '',
    };

    final docRef = FirebaseFirestore.instance
        .collection(
          widget.contextType == 'registration' ? 'subscriptions' : 'bookings',
        )
        .doc(widget.referenceId);

    await docRef.update(data);

    setState(() => _uploading = false);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Payment submitted!')));

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Payment (${widget.contextType})')),
      body: _uploading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedMethod,
                    items: ['GCash', 'PayPal']
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedMethod = value!),
                    decoration: InputDecoration(
                      labelText: 'Select Payment Method',
                    ),
                  ),
                  if (_selectedMethod == 'GCash') ...[
                    SizedBox(height: 16),
                    _proofImage != null
                        ? Image.file(_proofImage!, height: 200)
                        : Text('No proof selected'),
                    TextButton.icon(
                      icon: Icon(Icons.upload),
                      label: Text('Upload GCash Proof'),
                      onPressed: _pickImage,
                    ),
                  ],
                  SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: Icon(Icons.payment),
                    label: Text('Submit Payment'),
                    onPressed: _submitPayment,
                  ),
                ],
              ),
            ),
    );
  }
}
