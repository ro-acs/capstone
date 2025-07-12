import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'gcash_webview_payment.dart';
import '/services/gcash_payment_service.dart';

class MakePaymentScreen extends StatefulWidget {
  final String bookingId;
  final String photographerId;
  final String clientId;
  final double remaining;

  const MakePaymentScreen({
    super.key,
    required this.bookingId,
    required this.remaining,
    required this.photographerId,
    required this.clientId,
  });

  @override
  State<MakePaymentScreen> createState() => _MakePaymentScreenState();
}

class _MakePaymentScreenState extends State<MakePaymentScreen> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  bool isSubmitting = false;
  bool isFullPayment = false;
  bool isPaid = false;

  List<String> paymentMethods = [];
  String? selectedMethod;
  double finalPrice = 0;
  double totalPaid = 0;
  double remaining = 0;

  @override
  void initState() {
    super.initState();
    fetchBookingData();
    fetchPaymentMethods();
  }

  Future<void> fetchBookingData() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .get();

      if (!snap.exists) {
        Fluttertoast.showToast(msg: "Booking not found.");
        return;
      }

      final data = snap.data();
      if (data == null) return;

      finalPrice = (data['finalPrice'] as num?)?.toDouble() ?? 0.0;
      isPaid = data['isPaid'] == true;

      final List<dynamic> history = List.from(data['partialPayment'] ?? []);
      totalPaid = history
          .fold<num>(0, (sum, item) => sum + (item['price'] as num))
          .toDouble();

      remaining = finalPrice - totalPaid;

      if (remaining <= 0) {
        isPaid = true;
      }

      if (isPaid) {
        amountController.text = remaining.toStringAsFixed(2);
      }

      setState(() {});
    } catch (e) {
      Fluttertoast.showToast(msg: "Error fetching booking: $e");
    }
  }

  Future<void> fetchPaymentMethods() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('payment_method')
          .get();
      setState(() {
        paymentMethods = snap.docs
            .map((doc) => doc.data()['name']?.toString() ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
      });
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to load payment methods.");
    }
  }

  void toggleFullPayment(bool value) {
    setState(() {
      isFullPayment = value;
      if (value) {
        amountController.text = remaining.toStringAsFixed(2);
      } else {
        amountController.clear();
      }
    });
  }

  void submitPayment() async {
    final amountText = amountController.text.trim();
    final note = noteController.text.trim();

    if (amountText.isEmpty || double.tryParse(amountText) == null) {
      Fluttertoast.showToast(msg: "Please enter a valid amount.");
      return;
    }

    if (selectedMethod == null) {
      Fluttertoast.showToast(msg: "Please select a payment method.");
      return;
    }

    final amount = double.parse(amountText);
    if (amount <= 0 || amount > remaining) {
      Fluttertoast.showToast(
        msg: "Amount must be between 1 and ₱${remaining.toStringAsFixed(2)}.",
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      if (selectedMethod == 'GCash') {
        final url = await GCashPaymentService.getPaymentUrl(
          uid: widget.clientId,
          amountInCentavos: (amount * 100).round(),
        );

        print('url: $url');

        if (url != null && url.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GCashWebViewPaymentScreen(
                paymentUrl: url,
                contextType: 'booking',
                referenceId: widget.bookingId,
                amount: amount,
                note: note,
              ),
            ),
          );
        } else {
          Fluttertoast.showToast(msg: "❌ Failed to initiate GCash payment.");
        }
      } else {
        Fluttertoast.showToast(msg: "Unsupported payment method.");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: ${e.toString()}");
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentDisabled = isPaid || remaining <= 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Make a Payment"),
        backgroundColor: Colors.deepPurple,
      ),
      body: paymentMethods.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Remaining Balance: ₱${remaining.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!paymentDisabled) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Pay Full Balance?"),
                        Switch(
                          value: isFullPayment,
                          onChanged: toggleFullPayment,
                          activeColor: Colors.deepPurple,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      enabled: !isFullPayment,
                      decoration: const InputDecoration(
                        labelText: "Amount to Pay",
                        prefixText: "₱",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedMethod,
                      items: paymentMethods
                          .map(
                            (method) => DropdownMenuItem(
                              value: method,
                              child: Text(method),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => selectedMethod = value),
                      decoration: const InputDecoration(
                        labelText: "Payment Method",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: "Note (Optional)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.payment),
                        label: isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text("Submit Payment"),
                        onPressed: isSubmitting ? null : submitPayment,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          backgroundColor: Colors.deepPurple,
                        ),
                      ),
                    ),
                  ],
                  if (paymentDisabled)
                    const Expanded(
                      child: Center(
                        child: Text(
                          "This booking is already fully paid.",
                          style: TextStyle(fontSize: 18, color: Colors.green),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
