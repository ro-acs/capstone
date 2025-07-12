import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InvoiceScreen extends StatelessWidget {
  final String bookingId;

  const InvoiceScreen({super.key, required this.bookingId});

  Future<pw.Document> _generateInvoice(Map<String, dynamic> booking) async {
    final pdf = pw.Document();
    final date = (booking['date'] as Timestamp).toDate();

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              "SnapSpot Booking Invoice",
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            pw.Text("Booking ID: $bookingId"),
            pw.Text("Client: ${booking['clientName']}"),
            pw.Text("Photographer: ${booking['photographerName']}"),
            pw.Text("Service: ${booking['serviceName']}"),
            pw.Text("Location: ${booking['location']}"),
            pw.Text("Date: $date"),
            pw.SizedBox(height: 20),
            pw.Text("Payment Method: ${booking['paymentMethod']}"),
            pw.Text("Status: ${booking['isPaid'] ? 'Paid' : 'Unpaid'}"),
            pw.SizedBox(height: 20),
            pw.Text(
              "Total: ₱${booking['price']}",
              style: pw.TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
    return pdf;
  }

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId);

    return Scaffold(
      appBar: AppBar(title: const Text('Booking Invoice')),
      body: FutureBuilder<DocumentSnapshot>(
        future: docRef.get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Booking not found.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          return PdfPreview(
            build: (format) => _generateInvoice(data).then((doc) => doc.save()),
            allowPrinting: true,
            allowSharing: true,
          );
        },
      ),
    );
  }
}
