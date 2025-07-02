import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'client_dashboard.dart';
import 'photographer_dashboard.dart';
import 'signup_client_screen.dart';
import 'signup_photographer_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;

  Future<void> loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

      final uid = userCredential.user!.uid;

      // Check if user is Client or Photographer
      final clientDoc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(uid)
          .get();
      final photographerDoc = await FirebaseFirestore.instance
          .collection('photographers')
          .doc(uid)
          .get();

      if (clientDoc.exists) {
        Fluttertoast.showToast(msg: 'Welcome, Client!');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ClientDashboardScreen()),
        );
      } else if (photographerDoc.exists) {
        Fluttertoast.showToast(msg: 'Welcome, Photographer!');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => PhotographerDashboardScreen()),
        );
      } else {
        Fluttertoast.showToast(msg: 'No user role found.');
      }
    } on FirebaseAuthException catch (e) {
      Fluttertoast.showToast(msg: e.message ?? "Login failed.");
    } catch (e) {
      Fluttertoast.showToast(msg: "Something went wrong.");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Text(
                    'SnapSpot Login',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  SizedBox(height: 40),

                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.isEmpty ||
                          !value.contains('@')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 24),

                  isLoading
                      ? CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: loginUser,
                          child: Text('Login'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(double.infinity, 48),
                            backgroundColor: Colors.indigo,
                          ),
                        ),

                  SizedBox(height: 20),

                  Text('Don\'t have an account?'),
                  SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        child: Text('Sign up as Client'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SignUpClientScreen(),
                            ),
                          );
                        },
                      ),
                      Text('|'),
                      TextButton(
                        child: Text('Photographer'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SignUpPhotographerScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
