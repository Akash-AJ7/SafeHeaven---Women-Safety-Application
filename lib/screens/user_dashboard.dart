import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'voice_sos_widget.dart';
import '../services/voice_service.dart';

class UserDashboard extends StatefulWidget {
  final String uid;

  const UserDashboard({super.key, required this.uid});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  LocationData? currentPosition;
  String? alertId;
  bool alertActive = false;

  Future<void> getLocation() async {
    Location location = Location();

    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    currentPosition = await location.getLocation();
  }

  Future<void> sendSOS() async {
    await getLocation();

    if (currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enable GPS")),
      );
      return;
    }

    // Fetch user pincode safely (document may not exist)
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(widget.uid)
        .get();
    int? userPincodeInt;
    try {
      final data = userDoc.data() as Map<String, dynamic>?;
      if (data != null && data['pincode'] != null) {
        final pincodeData = data['pincode'];
        if (pincodeData is int) {
          userPincodeInt = pincodeData;
        } else if (pincodeData is String) {
          userPincodeInt = int.tryParse(pincodeData);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("User data missing; using default pincode")),
        );
      }
    } catch (_) {
      userPincodeInt = null;
    }

    DocumentReference? ref;
    try {
      // If user's pincode is missing, try reverse-geocoding from coordinates
      if (userPincodeInt == null) {
        try {
          final lat = currentPosition!.latitude;
          final lng = currentPosition!.longitude;
          if (lat != null && lng != null) {
            final placemarks = await geocoding
                .placemarkFromCoordinates(lat, lng, localeIdentifier: "en");
            if (placemarks.isNotEmpty) {
              final postal = placemarks.first.postalCode;
              if (postal != null && postal.isNotEmpty) {
                userPincodeInt = int.tryParse(postal);
              }
            }
          }
        } catch (_) {
          // ignore reverse-geocoding failures; we'll save null pincode instead
        }
      }
      ref = await FirebaseFirestore.instance.collection("alerts").add({
        "userId": widget.uid,
        "lat": currentPosition!.latitude,
        "lng": currentPosition!.longitude,
        "pincode": userPincodeInt,
        "createdAt": DateTime.now(),
        "status": "active",
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send SOS: $e")),
      );
      return;
    }

    setState(() {
      alertId = ref!.id;
      alertActive = true;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("SOS alert sent!")));
  }

  Stream<QuerySnapshot> officersResponding() {
    if (alertId == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection("alerts")
        .doc(alertId)
        .collection("responders")
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SafeHeaven User"),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text("Hello User 👋",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size(double.infinity, 100),
                  ),
                  onPressed: sendSOS,
                  child: const Text("SEND SOS", style: TextStyle(fontSize: 28)),
                ),
                const SizedBox(height: 12),
                // Dev/testing helper: simulate voice trigger
                ElevatedButton(
                  onPressed: () {
                    VoiceService.instance.simulatePhrase('help aj');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text('Simulate SOS (voice)',
                      style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 20),
                alertActive
                    ? Expanded(
                        child: StreamBuilder(
                          stream: officersResponding(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            if (snapshot.data!.docs.isEmpty) {
                              return const Center(
                                  child: Text("Waiting for officers…"));
                            }

                            return ListView(
                              children: snapshot.data!.docs.map((doc) {
                                var d = doc.data() as Map;
                                return Card(
                                  child: ListTile(
                                    title: Text(d["name"]),
                                    subtitle:
                                        Text("Distance: ${d['distance']} km"),
                                    trailing: ElevatedButton(
                                      onPressed: () {
                                        // Accept the officer's help
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  "Accepted help from ${d["name"]}")),
                                        );
                                        // Optionally, update alert status or notify officer
                                      },
                                      child: const Text("Accept"),
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      )
                    : const SizedBox(),
              ],
            ),
          ),
          // Voice SOS overlay
          Positioned(
            bottom: 20,
            right: 20,
            child: VoiceSosWidget(
              userId: widget.uid,
              onSosTriggered: sendSOS,
            ),
          ),
        ],
      ),
    );
  }
}
