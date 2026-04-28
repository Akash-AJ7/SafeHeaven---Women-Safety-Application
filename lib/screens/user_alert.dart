import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserAlertPage extends StatelessWidget {
  final String userId;
  final String userName;
  final String phone;

  const UserAlertPage({
    super.key,
    required this.userId,
    required this.userName,
    required this.phone,
  });

  Future sendAlert() async {
    await FirebaseFirestore.instance.collection("alerts").add({
      "userId": userId,
      "userName": userName,
      "phone": phone,
      "createdAt": DateTime.now(),
      "status": "active",
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Emergency Alert")),
      body: Center(
        child: ElevatedButton(
          style:
              ElevatedButton.styleFrom(minimumSize: const Size(200, 60), backgroundColor: Colors.red),
          onPressed: () async {
            await sendAlert();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Alert sent!")),
            );
          },
          child: const Text("SEND ALERT", style: TextStyle(fontSize: 20)),
        ),
      ),
    );
  }
}
