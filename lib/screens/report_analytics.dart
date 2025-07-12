import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportAnalyticsScreen extends StatefulWidget {
  const ReportAnalyticsScreen({super.key});

  @override
  State<ReportAnalyticsScreen> createState() => _ReportAnalyticsScreenState();
}

class _ReportAnalyticsScreenState extends State<ReportAnalyticsScreen> {
  int totalPhotographers = 0;
  int totalClients = 0;
  int totalBookings = 0;
  int totalReviews = 0;

  @override
  void initState() {
    super.initState();
    fetchCounts();
  }

  Future<void> fetchCounts() async {
    final users = await FirebaseFirestore.instance.collection('users').get();
    final photographers = users.docs
        .where((u) => u['role'] == 'Photographer')
        .length;
    final clients = users.docs.where((u) => u['role'] == 'Client').length;

    final bookings = await FirebaseFirestore.instance
        .collection('bookings')
        .get();
    final reviews = await FirebaseFirestore.instance
        .collection('reviews')
        .get();

    setState(() {
      totalPhotographers = photographers;
      totalClients = clients;
      totalBookings = bookings.docs.length;
      totalReviews = reviews.docs.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Analytics Dashboard")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "User Roles",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 150,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: totalPhotographers.toDouble(),
                      title: 'Photographers',
                      color: Colors.blue,
                    ),
                    PieChartSectionData(
                      value: totalClients.toDouble(),
                      title: 'Clients',
                      color: Colors.orange,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Platform Summary",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                title: const Text("Total Bookings"),
                trailing: Text("$totalBookings"),
              ),
            ),
            Card(
              child: ListTile(
                title: const Text("Total Reviews"),
                trailing: Text("$totalReviews"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
