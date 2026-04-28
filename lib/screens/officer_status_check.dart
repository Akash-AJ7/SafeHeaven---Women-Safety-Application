import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OfficerStatusCheck extends StatefulWidget {
  const OfficerStatusCheck({super.key});

  @override
  State<OfficerStatusCheck> createState() => _OfficerStatusCheckState();
}

class _OfficerStatusCheckState extends State<OfficerStatusCheck> {
  final email = TextEditingController();
  final password = TextEditingController();

  String status = "";
  String reason = "";
  String officerId = "";

  checkStatus() async {
    try {
      UserCredential user = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
              email: email.text.trim(), password: password.text.trim());

      DocumentSnapshot snap = await FirebaseFirestore.instance
          .collection("officers")
          .doc(user.user!.uid)
          .get();

      if (!snap.exists) {
        setState(() {
          status = "not_found";
          reason = "No application found";
        });
        return;
      }

      var data = snap.data() as Map<String, dynamic>;
      setState(() {
        status = data["status"];
        reason = data["admin_comment"] ?? "";
        officerId = data["officerId"] ?? "";
      });
    } catch (e) {
      setState(() {
        status = "error";
        reason = "Invalid email or password";
      });
    }
  }

  void _resubmitApplication() async {
    // Navigate to officer register with prefilled data
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login again")),
      );
      return;
    }

    // Get current officer data
    DocumentSnapshot snap = await FirebaseFirestore.instance
        .collection("officers")
        .doc(user.uid)
        .get();

    if (snap.exists) {
      final data = snap.data() as Map<String, dynamic>;

      // Navigate to update form with current data
      Navigator.pushNamed(
        context,
        '/officer/update',
        arguments: {
          'uid': user.uid,
          'email': data['email'] ?? '',
          'phone': data['phone'] ?? '',
          'name': data['name'] ?? '',
          'pincode': data['pincode'] ?? 0,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Officer Status Check")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
                controller: email,
                decoration: const InputDecoration(labelText: "Email")),
            TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Password")),
            const SizedBox(height: 20),
            ElevatedButton(
                onPressed: checkStatus, child: const Text("Check Status")),
            const SizedBox(height: 40),
            if (status == "approved") ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      "Approved",
                      style: TextStyle(
                          color: Colors.green,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Officer ID: $officerId",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
            if (status == "rejected") ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.cancel, color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      "Rejected",
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Reason: $reason",
                      style: const TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _resubmitApplication,
                        icon: const Icon(Icons.edit),
                        label: const Text("Update Application"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (status == "pending") ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.hourglass_top,
                        color: Colors.orange, size: 48),
                    SizedBox(height: 12),
                    Text(
                      "Pending",
                      style: TextStyle(
                          color: Colors.orange,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Your application is under review",
                      style: TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
            if (status == "error") ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.error, color: Colors.grey, size: 48),
                    SizedBox(height: 12),
                    Text(
                      "Invalid Credentials",
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Please check your email and password",
                      style: TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
            if (status == "not_found") ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.search_off, color: Colors.grey, size: 48),
                    SizedBox(height: 12),
                    Text(
                      "Not Found",
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "No application found for this account",
                      style: TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
