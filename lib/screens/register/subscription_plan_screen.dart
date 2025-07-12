import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'terms_conditions_screen.dart';

class SubscriptionPlanScreen extends StatefulWidget {
  final String email;
  final String password;
  final String name;
  final bool isPhotographer;

  const SubscriptionPlanScreen({
    super.key,
    required this.email,
    required this.password,
    required this.name,
    required this.isPhotographer,
  });

  @override
  State<SubscriptionPlanScreen> createState() => _SubscriptionPlanScreenState();
}

class _SubscriptionPlanScreenState extends State<SubscriptionPlanScreen> {
  String selectedPlan = 'Basic';
  Map<String, dynamic> planDetails = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('subscription_plans')
          .get();

      final data = {
        for (var doc in snapshot.docs)
          doc.id: {'price': doc['price'], 'description': doc['description']},
      };

      setState(() {
        planDetails = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load plans: $e')));
    }
  }

  void _nextStep() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TermsConditionsScreen(
          email: widget.email,
          password: widget.password,
          name: widget.name,
          isPhotographer: widget.isPhotographer,
          subscriptionPlan: widget.isPhotographer ? selectedPlan : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPhotographer = widget.isPhotographer;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1D3557), Color(0xFF457B9D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: isLoading
              ? const CircularProgressIndicator()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.subscriptions,
                            size: 60,
                            color: Colors.deepPurple,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isPhotographer
                                ? "Step 4: Choose Your Plan"
                                : "Step 4: Confirm Details",
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (isPhotographer) ...[
                            DropdownButtonFormField<String>(
                              value: selectedPlan,
                              decoration: const InputDecoration(
                                labelText: "Subscription Plan",
                                border: OutlineInputBorder(),
                              ),
                              items: planDetails.keys.map((plan) {
                                return DropdownMenuItem<String>(
                                  value: plan,
                                  child: Text(plan),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => selectedPlan = val);
                                }
                              },
                            ),
                            const SizedBox(height: 15),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                border: Border.all(color: Colors.blue),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                planDetails[selectedPlan] != null
                                    ? '₱${planDetails[selectedPlan]['price']}/month\n${planDetails[selectedPlan]['description']}'
                                    : '',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            const SizedBox(height: 25),
                          ],
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _nextStep,
                              icon: const Icon(Icons.navigate_next),
                              label: const Text("Next"),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                textStyle: const TextStyle(fontSize: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
