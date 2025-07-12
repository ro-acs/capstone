import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  /// Redirect user based on role after login
  static Future<void> handleRedirectAfterLogin(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists || doc.data() == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User profile not found.")),
        );
        return;
      }

      final data = doc.data()!;
      final role = data['role'];

      if (role == 'client') {
        Navigator.pushReplacementNamed(context, '/dashboard_client');
      } else if (role == 'photographer') {
        Navigator.pushReplacementNamed(context, '/dashboard_photographer');
      } else if (role == 'admin') {
        Navigator.pushReplacementNamed(context, '/dashboard_admin');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid role specified.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error during redirect: ${e.toString()}")),
      );
    }
  }

  /// Logout and return to login screen
  static Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }
}

class AuthTokenProvider with ChangeNotifier {
  String? _token;

  String? get token => _token;

  Future<void> fetchToken({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _token = await user.getIdToken(forceRefresh);
      notifyListeners();
    }
  }
}
