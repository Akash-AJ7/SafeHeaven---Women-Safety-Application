// lib/screens/officer_approval_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class OfficerApprovalPage extends StatelessWidget {
  const OfficerApprovalPage({super.key});

  // ---------- GENERATE UNIQUE OFFICER ID ----------
  String generateOfficerId() {
    return "OF-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";
  }

  // ---------- GENERATE NEXT BADGE NUMBER ----------
  Future<int> generateNextBadgeNumber() async {
    try {
      // Get the counter document
      DocumentSnapshot counterDoc = await FirebaseFirestore.instance
          .collection("admin")
          .doc("badge_counter")
          .get();

      int nextBadgeNumber = 1;
      if (counterDoc.exists) {
        nextBadgeNumber = (counterDoc.data() as Map)["lastBadgeNumber"] ?? 0;
        nextBadgeNumber++;
      }

      // Update the counter
      await FirebaseFirestore.instance
          .collection("admin")
          .doc("badge_counter")
          .set({"lastBadgeNumber": nextBadgeNumber}, SetOptions(merge: true));

      return nextBadgeNumber;
    } catch (e) {
      print("Error generating badge number: $e");
      return 1;
    }
  }

  // ---------- SEND EMAIL TO OFFICER ----------
  Future sendMail(String to, String id, int badgeNumber) async {
    const String adminEmail = "akashaj20047@gmail.com"; // CHANGE THIS
    const String appPassword =
        "wkkz gfgq wdab ipmj"; // CHANGE THIS (Gmail App Password)

    final smtpServer = gmail(adminEmail, appPassword);

    final message = Message()
      ..from = const Address(adminEmail, "SafeHeaven Admin")
      ..recipients.add(to)
      ..subject = "Officer Approval"
      ..text = "Congratulations! Your application is approved.\n"
          "Your Officer ID: $id\n"
          "Your Badge Number: $badgeNumber\n\n"
          "Use this Officer ID to login.";

    try {
      await send(message, smtpServer);
      print("Email sent → $to");
    } catch (e) {
      print("Email sending failed: $e");
    }
  }

  // ---------- APPROVE OFFICER ----------
  Future approveOfficer(BuildContext context, String docId, Map data) async {
    String officerId = generateOfficerId();
    int badgeNumber = await generateNextBadgeNumber();

    await FirebaseFirestore.instance.collection("officers").doc(docId).update({
      "status": "approved",
      "officerId": officerId,
      "badgeNumber": badgeNumber,
      "approvedAt": FieldValue.serverTimestamp(),
      "admin_comment": "",
    });

    // send email
    await sendMail(data["email"], officerId, badgeNumber);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text("Approved – Officer ID: $officerId | Badge #$badgeNumber")));
  }

  // ---------- REJECT OFFICER ----------
  void rejectOfficer(BuildContext context, String docId, Map data) {
    TextEditingController reason = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Reject Officer"),
        content: TextField(
          controller: reason,
          decoration: const InputDecoration(
            labelText: "Reason for rejection",
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection("officers")
                  .doc(docId)
                  .update({
                "status": "rejected",
                "officerId": "",
                "admin_comment": reason.text.trim(),
                "rejectedAt": FieldValue.serverTimestamp(),
              });

              Navigator.pop(context);
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text("Rejected")));
            },
            child: const Text("Reject"),
          ),
        ],
      ),
    );
  }

  // ---------- BUILD UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Officer Approval Requests")),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection("officers")
            .where("status", isEqualTo: "pending")
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading requests"));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No pending officer requests"));
          }

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              var data = doc.data();

              return Card(
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data["name"] ?? "",
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(data["email"] ?? ""),
                      Text(data["phone"] ?? ""),
                      const SizedBox(height: 15),

                      // ---------- Approve & Reject Buttons ----------
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: () =>
                                approveOfficer(context, doc.id, data),
                            child: const Text("Approve"),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () =>
                                rejectOfficer(context, doc.id, data),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red),
                            child: const Text("Reject"),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
