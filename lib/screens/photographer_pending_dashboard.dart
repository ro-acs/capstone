import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class PhotographerPendingDashboard extends StatelessWidget {
  const PhotographerPendingDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final createdDateStr = createdAt != null
            ? createdAt.toLocal().toString().split(' ')[0]
            : 'unknown';

        final status = data['status'] ?? 'Pending';
        final adminNotes = data['adminNotes'] ?? '';

        return Scaffold(
          appBar: AppBar(title: const Text('Photographer Status')),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.hourglass_top,
                    size: 100,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Status: \{$status}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You have been pending since: $createdDateStr',
                    style: const TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'You will receive an email once approved. Please wait while we process your status.',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  if (adminNotes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Admin Notes:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      adminNotes,
                      style: const TextStyle(fontSize: 14, color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final reasonController = TextEditingController();
                      final result = await showDialog<String>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Appeal Rejection'),
                          content: TextField(
                            controller: reasonController,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              hintText:
                                  'Explain why you believe the rejection should be reviewed...',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(
                                context,
                                reasonController.text.trim(),
                              ),
                              child: const Text('Submit Appeal'),
                            ),
                          ],
                        ),
                      );

                      if (result != null && result.isNotEmpty) {
                        await FirebaseFirestore.instance
                            .collection('admin_notifications')
                            .add({
                              'type': 'appeal',
                              'userId': user.uid,
                              'message': result,
                              'timestamp': Timestamp.now(),
                            });

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Appeal submitted to admin.'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.feedback_outlined),
                    label: const Text('Submit Appeal'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushReplacementNamed(
                      context,
                      '/dashboard_selector',
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Status'),
                  ),
                  TextButton(
                    onPressed: () {
                      launchUrl(
                        Uri.parse(
                          'mailto:snapspot.help@gmail.com?subject=Photographer%20Pending%20Assistance',
                        ),
                      );
                    },
                    child: const Text('Contact Support'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
