import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';

class OfficerDashboard extends StatefulWidget {
  final String alertId;
  final Map<String, dynamic> alertData;
  final String officerId;

  const OfficerDashboard({
    super.key,
    required this.alertId,
    required this.alertData,
    required this.officerId,
  });

  @override
  State<OfficerDashboard> createState() => _OfficerDashboardState();
}

class _OfficerDashboardState extends State<OfficerDashboard> {
  late MapController mapController;
  LatLng? userLocation;
  LatLng? officerLocation;
  double? distance;
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      // User alert location
      final userLat = widget.alertData['lat'] ?? 0.0;
      final userLng = widget.alertData['lng'] ?? 0.0;
      userLocation = LatLng(userLat, userLng);

      // Get officer's current location
      Location location = Location();
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
      }

      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
      }

      if (permissionGranted == PermissionStatus.granted &&
          userLocation != null) {
        LocationData currentLocation = await location.getLocation();
        officerLocation = LatLng(
            currentLocation.latitude ?? 0.0, currentLocation.longitude ?? 0.0);

        // Attempt to save officer's current coordinates to Firestore.
        // Handle both cases: document ID == uid, or officer document uses a separate docId with a 'uid' field.
        try {
          final String uid = widget.officerId;
          final latVal = currentLocation.latitude;
          final lngVal = currentLocation.longitude;

          if (latVal != null && lngVal != null) {
            // First try update by docId == uid
            final docRef =
                FirebaseFirestore.instance.collection('officers').doc(uid);
            final docSnap = await docRef.get();
            if (docSnap.exists) {
              await docRef.update({
                'latitude': latVal,
                'longitude': lngVal,
                'updatedAt': FieldValue.serverTimestamp(),
              });
              print(
                  'Updated officer document by uid docId: $uid -> [$latVal,$lngVal]');
            } else {
              // Fallback: find document where 'uid' field equals uid
              final QuerySnapshot q = await FirebaseFirestore.instance
                  .collection('officers')
                  .where('uid', isEqualTo: uid)
                  .get();
              if (q.docs.isNotEmpty) {
                final r = q.docs.first.reference;
                await r.update({
                  'latitude': latVal,
                  'longitude': lngVal,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                print(
                    'Updated officer document by uid field (docId: ${r.id}) -> [$latVal,$lngVal]');
              } else {
                print(
                    'No officer document found for uid: $uid (cannot save location)');
              }
            }
          } else {
            print('Current location lat/lng null; skipping save');
          }
        } catch (e) {
          print('Error saving officer location: $e');
        }

        // Calculate distance
        distance = _calculateDistance(officerLocation!, userLocation!);
      }

      setState(() => loading = false);
    } catch (e) {
      print("Error initializing map: $e");
      setState(() => loading = false);
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const Distance distanceCalculator = Distance();
    return distanceCalculator(point1, point2) / 1000; // Convert to km
  }

  Future<void> _saveUser() async {
    setState(() => saving = true);

    try {
      // Update alert status to "resolved"
      await FirebaseFirestore.instance
          .collection("alerts")
          .doc(widget.alertId)
          .update({
        "status": "resolved",
        "resolvedBy": widget.officerId,
        "resolvedAt": DateTime.now(),
      });

      // Update pending_cases entry (if exists) and mark resolved
      try {
        var pendingSnap = await FirebaseFirestore.instance
            .collection('pending_cases')
            .where('alertId', isEqualTo: widget.alertId)
            .get();
        for (var doc in pendingSnap.docs) {
          await FirebaseFirestore.instance
              .collection('pending_cases')
              .doc(doc.id)
              .update({
            'status': 'resolved',
            'resolvedAt': DateTime.now(),
            'resolvedBy': widget.officerId,
          });
        }
      } catch (e) {
        // ignore pending update errors
      }

      // Create a case_history document for audit
      try {
        var caseDoc = {
          ...widget.alertData,
          'alertId': widget.alertId,
          'resolvedBy': widget.officerId,
          'resolvedAt': DateTime.now(),
          'caseCreatedAt': DateTime.now(),
        };
        await FirebaseFirestore.instance
            .collection('case_history')
            .add(caseDoc);
      } catch (e) {
        // ignore case history creation errors
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("✓ User saved! Other officers notified.")),
        );

        // Go back to home after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving user: $e")),
        );
      }
    }

    setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Officer Dashboard")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Officer Dashboard"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Map
          Expanded(
            flex: 2,
            child: userLocation != null
                ? FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      initialCenter: officerLocation != null
                          ? LatLng(
                              (userLocation!.latitude +
                                      officerLocation!.latitude) /
                                  2,
                              (userLocation!.longitude +
                                      officerLocation!.longitude) /
                                  2,
                            )
                          : userLocation!,
                      initialZoom: 14,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c', 'd'],
                        userAgentPackageName: 'com.safeheaven.app',
                        maxZoom: 19,
                      ),
                      // Polyline connecting user and officer
                      if (officerLocation != null)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: [userLocation!, officerLocation!],
                              color: Colors.blue,
                              strokeWidth: 4,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          // User's location (red marker)
                          Marker(
                            point: userLocation!,
                            width: 50,
                            height: 50,
                            child: Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.red,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.5),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  height: 50,
                                  width: 50,
                                  child: const Icon(
                                    Icons.emergency,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Officer's location (green marker)
                          if (officerLocation != null)
                            Marker(
                              point: officerLocation!,
                              width: 50,
                              height: 50,
                              child: Column(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.green,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green.withOpacity(0.5),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    height: 50,
                                    width: 50,
                                    child: const Icon(
                                      Icons.shield,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  )
                : const Center(child: Text("Unable to load map")),
          ),
          // Details Section
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Distance info
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              distance != null
                                  ? "${distance!.toStringAsFixed(1)} km away"
                                  : "Calculating distance...",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "User: ${widget.alertData['userId'] ?? 'Unknown'}",
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Lat: ${widget.alertData['lat']?.toStringAsFixed(4) ?? 'N/A'}",
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Lng: ${widget.alertData['lng']?.toStringAsFixed(4) ?? 'N/A'}",
                              style: const TextStyle(fontSize: 13),
                            ),
                            if (widget.alertData['description'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  "Description: ${widget.alertData['description']}",
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Save User Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: saving ? null : _saveUser,
                        child: Text(
                          saving ? "Saving..." : "✓ User be saved",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }
}
