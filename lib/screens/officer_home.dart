import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'officer_dashboard.dart';

class OfficerHome extends StatefulWidget {
  const OfficerHome({super.key});

  @override
  State<OfficerHome> createState() => _OfficerHomeState();
}

class _OfficerHomeState extends State<OfficerHome> {
  int? officerPincode;
  bool _pincodeFetched = false;
  String? currentUid;
  Map<String, dynamic>? officerDocData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_pincodeFetched) {
      _pincodeFetched = true;
      fetchOfficerPincode();
    }
  }

  Future fetchOfficerPincode() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final officerId = args?["officerId"] ?? "";

    try {
      currentUid = FirebaseAuth.instance.currentUser?.uid;

      if (currentUid != null) {
        var doc = await FirebaseFirestore.instance
            .collection('officers')
            .doc(currentUid)
            .get();

        if (doc.exists) {
          officerDocData = doc.data();

          if (officerDocData != null &&
              officerDocData!['pincode'] != null &&
              officerPincode == null) {
            dynamic pincodeData = officerDocData!['pincode'];

            if (pincodeData is int) {
              officerPincode = pincodeData;
            } else if (pincodeData is String) {
              officerPincode = int.tryParse(pincodeData);
            }
          }
        }
      }
    } catch (e) {
      print("Error fetching officer doc: $e");
    }

    if (officerId.isNotEmpty) {
      QuerySnapshot snap = await FirebaseFirestore.instance
          .collection("officers")
          .where("officerId", isEqualTo: officerId)
          .get();

      if (snap.docs.isNotEmpty) {
        var data = snap.docs.first.data() as Map<String, dynamic>;

        dynamic pincodeData = data["pincode"];

        int? pin;
        if (pincodeData is int) {
          pin = pincodeData;
        } else if (pincodeData is String) {
          pin = int.tryParse(pincodeData);
        }

        setState(() {
          officerPincode = pin;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final name = args?['name'] ?? 'Officer';
    final officerId = args?['officerId'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Officer Home"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  "Welcome $name",
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  "Officer ID: $officerId",
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                if (currentUid != null)
                  Text('UID: $currentUid',
                      style: const TextStyle(fontSize: 12)),
                if (officerDocData != null)
                  Text('Status: ${officerDocData!['status'] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Active Alerts:",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: officerPincode != null
                  ? FirebaseFirestore.instance
                      .collection("alerts")
                      .where("pincode", isEqualTo: officerPincode)
                      .snapshots()
                  : const Stream.empty(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No active alerts"));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var alert = snapshot.data!.docs[index];
                    var data = alert.data() as Map<String, dynamic>;

                    String? assigned = data["assignedOfficer"];
                    String status = data["status"] ?? "";

                    if (status != "active" &&
                        !(status == "assigned" && assigned == officerId)) {
                      return const SizedBox.shrink();
                    }

                    if (assigned != null && assigned != officerId) {
                      return const SizedBox.shrink();
                    }

                    return ListTile(
                      title: Text("Alert from ${data['userId']}"),
                      subtitle:
                          Text("Lat: ${data['lat']}, Lng: ${data['lng']}"),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          try {
                            final uid = FirebaseAuth.instance.currentUser?.uid;

                            if (uid == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("Please login first")),
                              );
                              return;
                            }

                            // ✅ FIXED: using SET instead of UPDATE
                            await FirebaseFirestore.instance
                                .collection("alerts")
                                .doc(alert.id)
                                .set({
                              "assignedOfficer": officerId,
                              "assignedOfficerUid": uid,
                              "status": "assigned",
                              "assignedAt": FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));

                            // Navigate
                            if (mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => OfficerDashboard(
                                    alertId: alert.id,
                                    alertData: data,
                                    officerId: uid,
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error: $e")),
                            );
                          }
                        },
                        child: const Text("Accept"),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
