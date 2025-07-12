import 'package:flutter/material.dart';

class BookingRequestsPhotographer extends StatelessWidget {
  const BookingRequestsPhotographer({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Incoming Booking Requests")),
      body: const Center(child: Text("Photographer's booking requests")),
    );
  }
}
