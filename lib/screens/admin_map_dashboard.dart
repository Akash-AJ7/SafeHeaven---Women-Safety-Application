import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminMapDashboard extends StatefulWidget {
  const AdminMapDashboard({super.key});

  @override
  State<AdminMapDashboard> createState() => _AdminMapDashboardState();
}

class _AdminMapDashboardState extends State<AdminMapDashboard> {
  late MapController mapController;
  List<Marker> markers = [];
  LatLng? mapCenter;

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    _loadMarkersFromFirebase();
  }

  Future<void> _loadMarkersFromFirebase() async {
    try {
      // Fetch all active alerts (users)
      QuerySnapshot alertsSnapshot = await FirebaseFirestore.instance
          .collection("alerts")
          .where("status", whereIn: ["active", "assigned"]).get();

      // Fetch all approved officers
      QuerySnapshot officersSnapshot = await FirebaseFirestore.instance
          .collection("officers")
          .where("status", isEqualTo: "approved")
          .get();

      List<Marker> newMarkers = [];

      // Add user markers (red)
      for (var alert in alertsSnapshot.docs) {
        var data = alert.data() as Map<String, dynamic>;
        final lat = data['lat'] as double?;
        final lng = data['lng'] as double?;
        final userId = data['userId'] ?? 'Unknown User';

        if (lat != null && lng != null) {
          newMarkers.add(
            Marker(
              point: LatLng(lat, lng),
              width: 45,
              height: 45,
              child: GestureDetector(
                onTap: () => _showUserDetails(data, alert.id),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.emergency,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          );
        }
      }

      // Add officer markers (green)
      for (var officer in officersSnapshot.docs) {
        var data = officer.data() as Map<String, dynamic>;
        final lat = data['latitude'] as double?;
        final lng = data['longitude'] as double?;
        final officerName = data['name'] ?? 'Officer';
        final pincode = data['pincode'];

        if (lat != null && lng != null) {
          newMarkers.add(
            Marker(
              point: LatLng(lat, lng),
              width: 45,
              height: 45,
              child: GestureDetector(
                onTap: () => _showOfficerDetails(data),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          );
        }
      }

      // Calculate map center (center of all markers)
      if (newMarkers.isNotEmpty) {
        double avgLat =
            newMarkers.fold(0.0, (sum, m) => sum + m.point.latitude) /
                newMarkers.length;
        double avgLng =
            newMarkers.fold(0.0, (sum, m) => sum + m.point.longitude) /
                newMarkers.length;
        mapCenter = LatLng(avgLat, avgLng);
      } else {
        mapCenter = const LatLng(37.7749, -122.4194); // Default: San Francisco
      }

      setState(() {
        markers = newMarkers;
      });
    } catch (e) {
      print("Error loading markers: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading map: $e")),
      );
    }
  }

  void _showUserDetails(Map<String, dynamic> data, String alertId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "🚨 User Alert Details",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text("User ID: ${data['userId'] ?? 'N/A'}"),
            const SizedBox(height: 8),
            Text("Latitude: ${data['lat']?.toStringAsFixed(4) ?? 'N/A'}"),
            const SizedBox(height: 8),
            Text("Longitude: ${data['lng']?.toStringAsFixed(4) ?? 'N/A'}"),
            const SizedBox(height: 8),
            Text("Status: ${data['status']?.toUpperCase() ?? 'N/A'}"),
            if (data['description'] != null) ...[
              const SizedBox(height: 8),
              Text("Description: ${data['description']}"),
            ],
            if (data['assignedOfficer'] != null) ...[
              const SizedBox(height: 8),
              Text(
                "Assigned to: ${data['assignedOfficer']}",
                style: const TextStyle(color: Colors.green),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showOfficerDetails(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "🛡️ Officer Details",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text("Name: ${data['name'] ?? 'N/A'}"),
            const SizedBox(height: 8),
            Text("Officer ID: ${data['officerId'] ?? 'N/A'}"),
            const SizedBox(height: 8),
            Text("Badge #: ${data['badgeNumber'] ?? 'N/A'}"),
            const SizedBox(height: 8),
            Text("Pincode: ${data['pincode'] ?? 'N/A'}"),
            const SizedBox(height: 8),
            Text("Status: ${data['status']?.toUpperCase() ?? 'N/A'}"),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Map Dashboard"),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                "${markers.length} Markers",
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: mapCenter != null
          ? Stack(
              children: [
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: mapCenter!,
                    initialZoom: 12,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.safeheaven.app',
                      maxZoom: 19,
                    ),
                    MarkerLayer(
                      markers: markers,
                    ),
                  ],
                ),
                // Legend
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red,
                              ),
                              child: const Icon(Icons.emergency,
                                  color: Colors.white, size: 10),
                            ),
                            const SizedBox(width: 8),
                            const Text("Users in Emergency",
                                style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.green,
                              ),
                              child: const Icon(Icons.shield,
                                  color: Colors.white, size: 10),
                            ),
                            const SizedBox(width: 8),
                            const Text("Nearby Officers",
                                style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Refresh Button
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: FloatingActionButton(
                    mini: true,
                    onPressed: _loadMarkersFromFirebase,
                    child: const Icon(Icons.refresh),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }
}
