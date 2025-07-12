import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PaymentReceiptScreen extends StatelessWidget {
  final String bookingId;
  final int index;

  const PaymentReceiptScreen({
    super.key,
    required this.bookingId,
    required this.index,
  });

  Future<Map<String, dynamic>> _loadEntry() async {
    final snap = await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .get();
    final data = snap.data()!;
    return List.from(data['partialPayment'])[index] as Map<String, dynamic>;
  }

  Future<pw.Document> _generatePdf(
    Map<String, dynamic> entry,
    Map<String, dynamic> booking,
  ) async {
    final pdf = pw.Document();
    final payDate = (entry['date'] as Timestamp).toDate();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "Payment Receipt",
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text("Booking Ref: ${booking['refId']}"),
              pw.Text("Client: ${booking['clientName']}"),
              pw.Text("Photographer: ${booking['photographerName']}"),
              pw.SizedBox(height: 20),
              pw.Text(
                "Amount Paid: ₱${(entry['price'] as num).toStringAsFixed(2)}",
              ),
              pw.Text("Method: ${entry['method'] ?? ''}"),
              pw.Text("Date: ${payDate.toLocal()}"),
              if (entry['note'] != null && (entry['note'] as String).isNotEmpty)
                pw.Text("Note: ${entry['note']}"),
            ],
          );
        },
      ),
    );
    return pdf;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Payment Receipt"),
        backgroundColor: Colors.deepPurple,
      ),
      body: FutureBuilder(
        future: Future.wait([
          _loadEntry(),
          FirebaseFirestore.instance
              .collection('bookings')
              .doc(bookingId)
              .get()
              .then((d) => d.data()!),
        ]),
        builder: (ctx, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final entry = snap.data![0] as Map<String, dynamic>;
          final booking = snap.data![1] as Map<String, dynamic>;
          final payDate = (entry['date'] as Timestamp).toDate();

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Receipt",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text("Booking Ref: ${booking['refId']}"),
                Text(
                  "Amount Paid: ₱${(entry['price'] as num).toStringAsFixed(2)}",
                ),
                Text("Method: ${entry['method'] ?? ''}"),
                Text("Date: ${payDate.toLocal()}"),
                if ((entry['note'] as String).isNotEmpty)
                  Text("Note: ${entry['note']}"),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text("Download PDF"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                    ),
                    onPressed: () async {
                      final pdf = await _generatePdf(entry, booking);
                      await Printing.sharePdf(
                        bytes: await pdf.save(),
                        filename: 'receipt.pdf',
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
