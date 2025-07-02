import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'photographer_dashboard.dart';

class SignUpPhotographerScreen extends StatefulWidget {
  @override
  _SignUpPhotographerScreenState createState() =>
      _SignUpPhotographerScreenState();
}

class _SignUpPhotographerScreenState extends State<SignUpPhotographerScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController specialtyController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;

  Future<void> registerPhotographer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

      final uid = userCredential.user!.uid;

      await FirebaseFirestore.instance
          .collection('photographers')
          .doc(uid)
          .set({
            'uid': uid,
            'name': nameController.text.trim(),
            'email': emailController.text.trim(),
            'location': locationController.text.trim(),
            'specialty': specialtyController.text.trim(),
            'profileImageUrl': '',
            'availability': [],
            'createdAt': Timestamp.now(),
          });

      Fluttertoast.showToast(msg: 'Photographer account created!');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => PhotographerDashboardScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      Fluttertoast.showToast(msg: e.message ?? "Error during sign-up.");
    } catch (e) {
      Fluttertoast.showToast(msg: "Unexpected error occurred.");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Photographer Sign Up"),
        backgroundColor: Colors.indigo,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text(
                "Join as a photographer",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 24),

              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Full Name",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter name' : null,
              ),
              SizedBox(height: 16),

              TextFormField(
                controller: locationController,
                decoration: InputDecoration(
                  labelText: "Location",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter location' : null,
              ),
              SizedBox(height: 16),

              TextFormField(
                controller: specialtyController,
                decoration: InputDecoration(
                  labelText: "Specialty (e.g., Weddings, Portraits)",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter specialty' : null,
              ),
              SizedBox(height: 16),

              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || !value.contains('@')
                    ? 'Enter valid email'
                    : null,
              ),
              SizedBox(height: 16),

              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.length < 6
                    ? 'Password must be at least 6 characters'
                    : null,
              ),
              SizedBox(height: 24),

              isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: registerPhotographer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        minimumSize: Size(double.infinity, 48),
                      ),
                      child: Text("Register"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
