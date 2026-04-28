import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAlertDetail extends StatefulWidget {
  final String alertId;
  final Map<String, dynamic> alertData;

  const AdminAlertDetail({
    super.key,
    required this.alertId,
    required this.alertData,
  });

  @override
  State<AdminAlertDetail> createState() => _AdminAlertDetailState();
}

class _AdminAlertDetailState extends State<AdminAlertDetail> {
  late final MapController mapController;

  @override
  void initState() {
    super.initState();
    mapController = MapController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Alert Details"),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('alerts')
            .doc(widget.alertId)
            .snapshots(),
        builder: (context, alertSnap) {
          if (alertSnap.hasError) {
            return Center(child: Text('Error: ${alertSnap.error}'));
          }
          if (!alertSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final alertData = alertSnap.data!.data() as Map<String, dynamic>;
          final double userLat = (alertData['lat'] as num?)?.toDouble() ?? 0.0;
          final double userLng = (alertData['lng'] as num?)?.toDouble() ?? 0.0;
          final dynamic userPincode = alertData['pincode'];
          // Debug: print alert pincode to help diagnose missing/empty values
          // (Remove or guard these prints in production)
          // ignore: avoid_print
          print('ALERT PINCODE: $userPincode');

          return StreamBuilder<QuerySnapshot>(
            // Query all officers, we'll normalize & filter status in-code
            stream:
                FirebaseFirestore.instance.collection('officers').snapshots(),
            builder: (context, officerSnap) {
              if (officerSnap.hasError) {
                return Center(child: Text('Error: ${officerSnap.error}'));
              }
              if (!officerSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              const Distance distanceCalculator = Distance();
              const double nearbyKm = 25.0;

              final List<Map<String, dynamic>> nearbyOfficers = [];
              final List<Map<String, dynamic>> notifiedOfficers = [];
              final List<Marker> markers = [];

              // User marker always present
              markers.add(
                Marker(
                  point: LatLng(userLat, userLng),
                  width: 50,
                  height: 50,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.red.withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 2),
                      ],
                    ),
                    child: const Icon(Icons.emergency,
                        color: Colors.white, size: 28),
                  ),
                ),
              );

              for (var doc in officerSnap.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                // Accept either 'latitude'/'longitude' or 'lat'/'lng' field names
                final officerLatRaw = data['latitude'] ?? data['lat'];
                final officerLngRaw = data['longitude'] ?? data['lng'];
                final officerPincode = data['pincode'];
                // Debug: print officer pincode and raw status
                // ignore: avoid_print
                print('OFFICER PINCODE: $officerPincode');
                // Debug: officer status raw
                // ignore: avoid_print
                print('OFFICER STATUS: ${data['status']}');

                // Prepare string forms for comparison
                final String userPinStr = userPincode?.toString().trim() ?? '';
                final String officerPinStr =
                    officerPincode?.toString().trim() ?? '';

                // Normalize status and skip if not approved
                final String statusNormalized =
                    (data['status'] ?? '').toString().trim().toLowerCase();
                if (statusNormalized != 'approved') {
                  // ignore: avoid_print
                  print(
                      'SKIPPING OFFICER (status != approved): ${data['status']}');
                  continue;
                }

                final double? officerLat = (officerLatRaw is num)
                    ? officerLatRaw.toDouble()
                    : double.tryParse(officerLatRaw?.toString() ?? '');
                final double? officerLng = (officerLngRaw is num)
                    ? officerLngRaw.toDouble()
                    : double.tryParse(officerLngRaw?.toString() ?? '');

                final bool hasCoords = officerLat != null && officerLng != null;
                double? distanceInKm;
                if (hasCoords) {
                  final double distanceMeters = distanceCalculator(
                      LatLng(userLat, userLng),
                      LatLng(officerLat, officerLng));
                  distanceInKm = distanceMeters / 1000.0;
                }

                // Debug compare pin values (force string compare)
                // ignore: avoid_print
                print(
                    "COMPARE: '$userPinStr' == '$officerPinStr' -> ${userPinStr == officerPinStr}");

                // If user pincode exists and matches officer pincode -> notified (independent of coords)
                if (userPinStr.isNotEmpty &&
                    officerPinStr.isNotEmpty &&
                    userPinStr.toString().trim() ==
                        officerPinStr.toString().trim()) {
                  // ignore: avoid_print
                  print(
                      'MATCH FOUND ✅ for officer ${data['officerId'] ?? data['uid'] ?? 'unknown'}');
                  notifiedOfficers.add({
                    ...data,
                    'distance': distanceInKm,
                    'lat': officerLat,
                    'lng': officerLng,
                  });
                }

                // Fallback: if alert has no pincode, notify nearby officers within 5 km (requires coords)
                else if (userPinStr.isEmpty &&
                    hasCoords &&
                    (distanceInKm ?? double.infinity) <= 5.0) {
                  notifiedOfficers.add({
                    ...data,
                    'distance': distanceInKm,
                    'lat': officerLat,
                    'lng': officerLng,
                  });
                }

                // Nearby (distance-based) - only when coords present
                if (hasCoords &&
                    (distanceInKm ?? double.infinity) <= nearbyKm) {
                  nearbyOfficers.add({
                    ...data,
                    'distance': distanceInKm,
                    'lat': officerLat,
                    'lng': officerLng,
                  });

                  // Add marker for nearby officer
                  markers.add(
                    Marker(
                      point: LatLng(officerLat, officerLng),
                      width: 50,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.green.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 2),
                          ],
                        ),
                        child: const Icon(Icons.shield,
                            color: Colors.white, size: 28),
                      ),
                    ),
                  );
                }
              }

              int compareDistance(Map a, Map b) {
                final doubleA = a['distance'] as double?;
                final doubleB = b['distance'] as double?;
                if (doubleA == null && doubleB == null) return 0;
                if (doubleA == null) return 1; // nulls go last
                if (doubleB == null) return -1;
                return doubleA.compareTo(doubleB);
              }

              nearbyOfficers.sort((a, b) => compareDistance(a, b));
              notifiedOfficers.sort((a, b) => compareDistance(a, b));

              // Debug: final count before rendering
              // ignore: avoid_print
              print('FINAL NOTIFIED COUNT: ${notifiedOfficers.length}');
              // UI-level debug: ensure the widget sees the same list length
              // ignore: avoid_print
              print('UI COUNT: ${notifiedOfficers.length}');
              return Column(
                children: [
                  Expanded(
                    flex: 2,
                    child: FlutterMap(
                      mapController: mapController,
                      options: MapOptions(
                          center: LatLng(userLat, userLng), zoom: 14),
                      children: [
                        TileLayer(
                            urlTemplate:
                                'https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c', 'd'],
                            userAgentPackageName: 'com.safeheaven.app',
                            maxZoom: 19),
                        CircleLayer(circles: [
                          CircleMarker(
                              point: LatLng(userLat, userLng),
                              color: Colors.red.withOpacity(0.1),
                              borderColor: Colors.red,
                              borderStrokeWidth: 2,
                              radius: 5000),
                        ]),
                        MarkerLayer(markers: markers),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20))),
                      child: SingleChildScrollView(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Card(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('🚨 User in Emergency',
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red)),
                                        const SizedBox(height: 8),
                                        Text(
                                            'User ID: ${alertData['userId'] ?? 'N/A'}'),
                                        const SizedBox(height: 4),
                                        Text(
                                            'Location: ${userLat.toStringAsFixed(4)}, ${userLng.toStringAsFixed(4)}'),
                                        const SizedBox(height: 4),
                                        Text(
                                            'Status: ${alertData['status']?.toUpperCase() ?? 'N/A'}'),
                                        if (alertData['description'] != null)
                                          Text(
                                              'Description: ${alertData['description']}'),
                                      ]),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Notified officers (same pincode)
                              Container(
                                padding: const EdgeInsets.all(10),
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.blueGrey.shade100,
                                        width: 1)),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          '🔔 Notified Officers (${notifiedOfficers.isEmpty ? 0 : notifiedOfficers.length})',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blueGrey)),
                                      if (notifiedOfficers.isEmpty)
                                        const Padding(
                                            padding: EdgeInsets.only(top: 8),
                                            child:
                                                Text('No officers to notify'))
                                      else
                                        Column(
                                            children: notifiedOfficers
                                                .take(5)
                                                .map((officer) {
                                          return Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8),
                                            child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Expanded(
                                                      child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                        Text(
                                                            officer['name'] ??
                                                                'Officer',
                                                            style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 13)),
                                                        Text(
                                                            'ID: ${officer['officerId'] ?? 'N/A'}',
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        11))
                                                      ])),
                                                  Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8,
                                                          vertical: 4),
                                                      decoration: BoxDecoration(
                                                          color:
                                                              Colors.blueGrey,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(6)),
                                                      child: Text(
                                                          officer['distance'] !=
                                                                  null
                                                              ? '${(officer['distance'] as double).toStringAsFixed(1)} km'
                                                              : 'N/A',
                                                          style: const TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)))
                                                ]),
                                          );
                                        }).toList())
                                    ]),
                              ),

                              // Nearby officers (within radius)
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.green.shade300,
                                        width: 2)),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          '🛡️ Nearby Officers (${nearbyOfficers.length})',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green)),
                                      if (nearbyOfficers.isEmpty)
                                        const Padding(
                                            padding: EdgeInsets.only(top: 8),
                                            child: Text('No officers nearby'))
                                      else
                                        Column(
                                            children: nearbyOfficers
                                                .take(3)
                                                .map((officer) {
                                          return Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8),
                                            child: Container(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                    color: Colors.green
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8)),
                                                child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Expanded(
                                                          child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                            Text(
                                                                officer['name'] ??
                                                                    'Officer',
                                                                style: const TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        13)),
                                                            Text(
                                                                'ID: ${officer['officerId'] ?? 'N/A'}',
                                                                style:
                                                                    const TextStyle(
                                                                        fontSize:
                                                                            11))
                                                          ])),
                                                      Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4),
                                                          decoration: BoxDecoration(
                                                              color:
                                                                  Colors.green,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          6)),
                                                          child: Text(
                                                              officer['distance'] !=
                                                                      null
                                                                  ? '${(officer['distance'] as double).toStringAsFixed(1)} km'
                                                                  : 'N/A',
                                                              style: const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold)))
                                                    ])),
                                          );
                                        }).toList())
                                    ]),
                              ),
                            ]),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }
}
