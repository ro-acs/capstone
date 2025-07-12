import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_client.dart';
import 'dashboard_photographer.dart';
import 'dashboard_admin.dart';
import 'login_screen.dart';
import 'photographer_pending_dashboard.dart';

class DashboardSelector extends StatelessWidget {
  const DashboardSelector({super.key});

  void _logout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      return const LoginScreen();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final currentUser = snapshot.data;
        if (currentUser == null) return const LoginScreen();

        return FutureBuilder(
          future: currentUser.reload(),
          builder: (context, _) {
            final refreshedUser = FirebaseAuth.instance.currentUser;

            if (!refreshedUser!.emailVerified) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Email Verification'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.logout),
                      onPressed: () => _logout(context),
                    ),
                  ],
                ),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Please verify your email address.'),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () async {
                          await refreshedUser.sendEmailVerification();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Verification email sent'),
                            ),
                          );
                        },
                        child: const Text('Resend Verification Email'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(refreshedUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Scaffold(
                    appBar: AppBar(
                      title: const Text('Welcome to SnapSpot'),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.logout),
                          onPressed: () => _logout(context),
                        ),
                      ],
                    ),
                    body: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Welcome to SnapSpot! Before using the platform, please review and accept our Terms & Conditions.',
                            style: TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          const Expanded(
                            child: SingleChildScrollView(
                              child: Text(
                                'Terms & Conditions:\n\n'
                                '1. You must provide accurate and truthful information during registration.\n'
                                '2. Photographers must submit valid proof of identity and payment.\n'
                                '3. Users agree to communicate respectfully and professionally.\n'
                                '4. Any form of abuse, fraud, or misuse of the platform will result in account termination.\n'
                                '5. SnapSpot reserves the right to verify, suspend, or remove accounts at its discretion.\n'
                                '6. All bookings and payments are subject to review and approval by the admin.\n'
                                '7. You agree to receive notifications and emails related to your activity.\n'
                                '8. By using this platform, you agree to all policies outlined in this agreement.',
                                textAlign: TextAlign.justify,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/register'),
                            child: const Text(
                              'Agree and Continue to Registration',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final role = data['role'] ?? 'Client';

                Widget dashboard;
                if (role == 'Photographer') {
                  final isVerified = data['isVerified'] ?? false;
                  final isPaid = data['isPaid'] ?? false;
                  final isDemo = data['isDemo'] ?? false;

                  if (isDemo) {
                    dashboard = const DashboardPhotographer();
                  } else if (!isVerified || !isPaid) {
                    FirebaseFirestore.instance
                        .collection('admin_notifications')
                        .add({
                          'userId': refreshedUser.uid,
                          'reason': !isVerified
                              ? 'Pending verification'
                              : 'Pending payment verification',
                          'timestamp': Timestamp.now(),
                        });
                    dashboard = const PhotographerPendingDashboard();
                  } else {
                    dashboard = const DashboardPhotographer();
                  }
                } else if (role == 'Admin') {
                  dashboard = const DashboardAdmin();
                } else {
                  dashboard = const DashboardClient();
                }

                return Scaffold(
                  appBar: AppBar(
                    title: const Text('SnapSpot'),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.logout),
                        onPressed: () => _logout(context),
                      ),
                    ],
                  ),
                  body: dashboard,
                );
              },
            );
          },
        );
      },
    );
  }
}
