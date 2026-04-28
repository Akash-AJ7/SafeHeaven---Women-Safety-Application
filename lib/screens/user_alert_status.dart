import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserAlertStatus extends StatelessWidget {
  final String userId;

  const UserAlertStatus({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Alert Status")),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection("alerts")
            .where("userId", isEqualTo: userId)
            .orderBy("createdAt", descending: true)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No alert found"));
          }

          var data = snapshot.data!.docs.first.data();

          if (data["status"] == "accepted") {
            return Center(
              child: Text(
                "Officer is coming!\nOfficer ID: ${data["assignedOfficer"]}",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, color: Colors.green),
              ),
            );
          }

          return const Center(
            child: Text("Waiting for officer response…"),
          );
        },
      ),
    );
  }
}
