import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'admin_alert_detail.dart';

class AdminAlertsScreen extends StatefulWidget {
  const AdminAlertsScreen({super.key});

  @override
  State<AdminAlertsScreen> createState() => _AdminAlertsScreenState();
}

class _AdminAlertsScreenState extends State<AdminAlertsScreen> {
  MapController? mapController;

  // Count nearby officers based on geographic distance (<= 25 km)
  Future<int> _countNearbyOfficers(dynamic alertLat, dynamic alertLng) async {
    try {
      // Normalize alert lat/lng to doubles
      double? aLat;
      double? aLng;
      if (alertLat is num) {
        aLat = alertLat.toDouble();
      } else {
        aLat = double.tryParse(alertLat?.toString() ?? '');
      }
      if (alertLng is num) {
        aLng = alertLng.toDouble();
      } else {
        aLng = double.tryParse(alertLng?.toString() ?? '');
      }

      if (aLat == null || aLng == null) return 0;

      const Distance distanceCalculator = Distance();
      const double nearbyKm = 25.0;

      // Fetch approved officers
      QuerySnapshot officersSnapshot = await FirebaseFirestore.instance
          .collection("officers")
          .where("status", isEqualTo: "approved")
          .get();

      int count = 0;
      for (var doc in officersSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;

        // Officer latitude/longitude fields may be stored as 'latitude'/'longitude' or 'lat'/'lng'
        final officerLatRaw = data['latitude'] ?? data['lat'];
        final officerLngRaw = data['longitude'] ?? data['lng'];

        double? oLat;
        double? oLng;
        if (officerLatRaw is num) {
          oLat = officerLatRaw.toDouble();
        } else {
          oLat = double.tryParse(officerLatRaw?.toString() ?? '');
        }
        if (officerLngRaw is num) {
          oLng = officerLngRaw.toDouble();
        } else {
          oLng = double.tryParse(officerLngRaw?.toString() ?? '');
        }

        if (oLat == null || oLng == null) continue;

        final meters =
            distanceCalculator(LatLng(aLat, aLng), LatLng(oLat, oLng));
        final km = meters / 1000.0;
        if (km <= nearbyKm) count++;
      }

      return count;
    } catch (e) {
      print("Error counting nearby officers (distance): $e");
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Active Alerts"),
        centerTitle: true,
        actions: [
          // Live badge showing number of active/assigned alerts
          StreamBuilder<QuerySnapshot>(
            // Stream all alerts (ordered) and filter client-side to avoid composite index requirement
            stream: FirebaseFirestore.instance
                .collection("alerts")
                .orderBy("createdAt", descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              int count = 0;
              if (snapshot.hasData) {
                count = snapshot.data!.docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final status = data['status'] ?? '';
                  return status == 'active' || status == 'assigned';
                }).length;
              }
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Stream all alerts ordered by createdAt, then filter client-side.
        stream: FirebaseFirestore.instance
            .collection("alerts")
            .orderBy("createdAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // Show a friendly error and allow retry
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      'Error loading alerts:\n${"${snapshot.error}"}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No active alerts"));
          }

          // Filter alerts client-side to only active/assigned
          final filteredDocs = snapshot.data!.docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final status = data['status'] ?? '';
            return status == 'active' || status == 'assigned';
          }).toList();

          if (filteredDocs.isEmpty) {
            return const Center(child: Text("No active alerts"));
          }

          // Build markers from filtered alerts
          List<Marker> markers = [];
          for (var doc in filteredDocs) {
            var data = doc.data() as Map<String, dynamic>;
            double? lat = data['lat'];
            double? lng = data['lng'];
            String status = data['status'] ?? 'active';

            if (lat != null && lng != null) {
              Color markerColor = status == 'active'
                  ? Colors.red
                  : status == 'assigned'
                      ? Colors.orange
                      : Colors.green;

              markers.add(
                Marker(
                  point: LatLng(lat, lng),
                  width: 40,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      color: markerColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: markerColor.withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              );
            }
          }

          // Get center of map (first filtered alert location)
          var firstAlert = filteredDocs.first.data() as Map;
          LatLng initialPosition = LatLng(
            firstAlert['lat'] ?? 11.4, // Perambalur, Tamil Nadu
            firstAlert['lng'] ?? 78.9,
          );

          return Column(
            children: [
              // Map View
              Expanded(
                flex: 1,
                child: FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: initialPosition,
                    initialZoom: 13,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.safeheaven.app',
                    ),
                    MarkerLayer(markers: markers),
                  ],
                ),
              ),
              // Alerts List
              Expanded(
                flex: 1,
                child: ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    var alert = filteredDocs[index];
                    var data = alert.data() as Map<String, dynamic>;
                    String status = data["status"] ?? "active";
                    String assigned = data["assignedOfficer"] ?? "Not assigned";
                    double lat = data['lat'] ?? 0.0;
                    double lng = data['lng'] ?? 0.0;

                    Color statusColor = status == 'active'
                        ? Colors.red
                        : status == 'assigned'
                            ? Colors.orange
                            : Colors.green;

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminAlertDetail(
                              alertId: alert.id,
                              alertData: data,
                            ),
                          ),
                        );
                      },
                      child: FutureBuilder<int>(
                        future: _countNearbyOfficers(data['lat'], data['lng']),
                        builder: (context, countSnapshot) {
                          int nearbyOfficersCount = countSnapshot.data ?? 0;

                          return Card(
                            margin: const EdgeInsets.all(8),
                            child: Stack(
                              children: [
                                ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: statusColor,
                                    child: Icon(
                                      status == 'active'
                                          ? Icons.emergency
                                          : status == 'assigned'
                                              ? Icons.assignment
                                              : Icons.check_circle,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text("Alert ID: ${alert.id}"),
                                  subtitle: Text(
                                    "Location: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}\nPincode: ${data['pincode']}\nAssigned: $assigned",
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: status == "active"
                                      ? ElevatedButton(
                                          onPressed: () async {
                                            await FirebaseFirestore.instance
                                                .collection("alerts")
                                                .doc(alert.id)
                                                .update({"status": "resolved"});
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content:
                                                      Text("Alert resolved")),
                                            );
                                          },
                                          child: const Text("Resolve"),
                                        )
                                      : Text(
                                          status.toUpperCase(),
                                          style: TextStyle(
                                            color: statusColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                                // Badge showing nearby officers count
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      nearbyOfficersCount.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    mapController?.dispose();
    super.dispose();
  }
}
