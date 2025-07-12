import 'package:flutter/material.dart';

class PhotographerListScreen extends StatelessWidget {
  const PhotographerListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Available Photographers")),
      body: const Center(child: Text("List of Photographers")),
    );
  }
}
