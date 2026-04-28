import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_map_dashboard.dart';
import 'package:geocoding/geocoding.dart';

// Helper: backfill missing pincodes in alerts using reverse geocoding
Future<void> backfillMissingPincodes(BuildContext context) async {
  final scaffold = ScaffoldMessenger.of(context);

  // Confirm action with the admin
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirm backfill'),
      content: const Text(
          'This will update all alerts missing pincodes. This action cannot be undone. Proceed?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel')),
        ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Proceed')),
      ],
    ),
  );

  if (confirm != true) return;

  scaffold.showSnackBar(const SnackBar(content: Text('Preparing backfill...')));

  final col = FirebaseFirestore.instance.collection('alerts');
  final snapshot = await col.get();

  // Collect docs that are missing pincode
  final List<QueryDocumentSnapshot> missing = [];
  for (var doc in snapshot.docs) {
    final data = doc.data();
    final pincode = data['pincode'];
    if (pincode == null || pincode.toString().trim().isEmpty) {
      missing.add(doc);
    }
  }

  final int total = missing.length;
  if (total == 0) {
    scaffold.showSnackBar(
        const SnackBar(content: Text('No alerts need backfilling.')));
    return;
  }

  // Show progress dialog and run migration in batches
  int processed = 0;
  int updated = 0;
  bool started = false;
  const int batchSize = 30; // tune as needed

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(builder: (context, setState) {
        // Start processing once the dialog is built
        if (!started) {
          started = true;
          Future.microtask(() async {
            for (int i = 0; i < total; i += batchSize) {
              final end = (i + batchSize < total) ? i + batchSize : total;
              final batch = missing.sublist(i, end);
              for (var doc in batch) {
                final data = doc.data() as Map<String, dynamic>;
                final lat = (data['lat'] as num?)?.toDouble();
                final lng = (data['lng'] as num?)?.toDouble();
                if (lat == null || lng == null) {
                  processed++;
                  setState(() {});
                  continue;
                }
                try {
                  final placemarks = await placemarkFromCoordinates(lat, lng,
                      localeIdentifier: "en");
                  if (placemarks.isNotEmpty) {
                    final postal = placemarks.first.postalCode;
                    final int? postalInt =
                        postal != null ? int.tryParse(postal) : null;
                    if (postalInt != null) {
                      await doc.reference.update({'pincode': postalInt});
                      updated++;
                    }
                  }
                } catch (e) {
                  // ignore failures for this doc
                }
                processed++;
                setState(() {});
              }

              // small pause to avoid hammering geocoding service
              await Future.delayed(const Duration(milliseconds: 300));
            }

            // done
            Navigator.of(context).pop();
          });
        }

        final double progress = total > 0 ? processed / total : 0.0;
        return AlertDialog(
          title: const Text('Backfilling pincodes'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 12),
              Text('Processed: $processed / $total'),
              const SizedBox(height: 6),
              Text('Updated: $updated'),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () {
                  // Prevent closing while running; allow close only when done
                  if (processed >= total) Navigator.of(context).pop();
                },
                child: const Text('Close')),
          ],
        );
      });
    },
  );

  scaffold.showSnackBar(SnackBar(
      content:
          Text('Backfill completed: $updated updated of $total processed')));
}

// Normalize officer `status` fields (one-time migration)
Future<void> normalizeOfficerStatuses(BuildContext context) async {
  final scaffold = ScaffoldMessenger.of(context);

  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Normalize officer statuses'),
      content: const Text(
          'This will normalize all officer status values (trim + lowercase). This action will update many documents. Proceed?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel')),
        ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Proceed')),
      ],
    ),
  );
  if (confirm != true) return;

  scaffold.showSnackBar(const SnackBar(
      content: Text('Preparing officer status normalization...')));

  final col = FirebaseFirestore.instance.collection('officers');
  final snapshot = await col.get();
  final List<QueryDocumentSnapshot> docs = snapshot.docs;
  final int total = docs.length;
  if (total == 0) {
    scaffold.showSnackBar(const SnackBar(content: Text('No officers found')));
    return;
  }

  int processed = 0;
  int updated = 0;
  bool started = false;
  const int batchSize = 50;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(builder: (context, setState) {
        if (!started) {
          started = true;
          Future.microtask(() async {
            for (int i = 0; i < total; i += batchSize) {
              final end = (i + batchSize < total) ? i + batchSize : total;
              final batch = docs.sublist(i, end);
              for (var doc in batch) {
                try {
                  final data = doc.data() as Map<String, dynamic>;
                  final raw = (data['status'] ?? '');
                  final normalized = raw.toString().trim().toLowerCase();
                  if (normalized != raw) {
                    await doc.reference.update({'status': normalized});
                    updated++;
                  }
                } catch (_) {
                  // ignore
                }
                processed++;
                setState(() {});
              }
              await Future.delayed(const Duration(milliseconds: 200));
            }
            Navigator.of(context).pop();
          });
        }

        final double progress = total > 0 ? processed / total : 0.0;
        return AlertDialog(
          title: const Text('Normalizing statuses'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 12),
            Text('Processed: $processed / $total'),
            const SizedBox(height: 6),
            Text('Updated: $updated'),
          ]),
          actions: [
            TextButton(
                onPressed: () {
                  if (processed >= total) Navigator.of(context).pop();
                },
                child: const Text('Close'))
          ],
        );
      });
    },
  );

  scaffold.showSnackBar(
      SnackBar(content: Text('Normalization complete: $updated updated')));
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Welcome, Admin 👋",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            // ---- LIVE MAP DASHBOARD BUTTON ----
            _menuButton(
              context,
              title: "Live Map Dashboard",
              icon: Icons.map,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminMapDashboard(),
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            // ---- APPROVE OFFICERS BUTTON with Badge ----
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("officers")
                  .where("status", isEqualTo: "pending")
                  .snapshots(),
              builder: (context, snapshot) {
                int pendingCount =
                    snapshot.hasData ? snapshot.data!.docs.length : 0;
                return _menuButtonWithBadge(
                  context,
                  title: "Approve Officers",
                  icon: Icons.verified_user,
                  route: '/officer/approval',
                  badgeCount: pendingCount,
                );
              },
            ),

            const SizedBox(height: 10),

            // ---- ALERTS BUTTON with live badge ----
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("alerts")
                  .where("status", whereIn: ["active", "assigned"]).snapshots(),
              builder: (context, snapshot) {
                int activeCount =
                    snapshot.hasData ? snapshot.data!.docs.length : 0;
                return _menuButtonWithBadge(
                  context,
                  title: "View Active Alerts",
                  icon: Icons.warning,
                  route: '/admin/alerts',
                  badgeCount: activeCount,
                );
              },
            ),

            // Case History removed per request

            // Pending Cases button removed per request (manage from Cases view)

            const SizedBox(height: 10),
            // ---- VIEW ALL USERS BUTTON ----
            _menuButton(
              context,
              title: "View All Users",
              icon: Icons.people,
              route: '/admin/users',
            ),

            const SizedBox(height: 10),

            // ---- VIEW ALL OFFICERS BUTTON ----
            _menuButton(
              context,
              title: "View All Officers",
              icon: Icons.local_police,
              route: '/admin/officers',
            ),
            const SizedBox(height: 10),

            // ---- BACKFILL PINCODES BUTTON (ADMIN) ----
            _menuButton(
              context,
              title: "Backfill Missing Pincodes",
              icon: Icons.update,
              onTap: () async {
                await backfillMissingPincodes(context);
              },
            ),
            const SizedBox(height: 10),
            _menuButton(
              context,
              title: "Normalize Officer Statuses",
              icon: Icons.sync,
              onTap: () async {
                await normalizeOfficerStatuses(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------
  // MENU BUTTON WIDGET with Badge
  // ---------------------------
  Widget _menuButtonWithBadge(BuildContext context,
      {required String title,
      required IconData icon,
      String? route,
      required int badgeCount}) {
    return InkWell(
      onTap: route == null
          ? null
          : () {
              Navigator.pushNamed(context, route);
            },
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(icon, size: 30, color: Colors.blue),
                const SizedBox(width: 15),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18),
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios, size: 18),
              ],
            ),
          ),
          // Badge
          if (badgeCount > 0)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  badgeCount.toString(),
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
  }

  // ---------------------------
  // MENU BUTTON WIDGET
  // ---------------------------
  Widget _menuButton(BuildContext context,
      {required String title,
      required IconData icon,
      String? route,
      VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ??
          (route == null
              ? null
              : () {
                  Navigator.pushNamed(context, route);
                }),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 30, color: Colors.blue),
            const SizedBox(width: 15),
            Text(
              title,
              style: const TextStyle(fontSize: 18),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 18),
          ],
        ),
      ),
    );
  }
}
