import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPendingCases extends StatefulWidget {
  const AdminPendingCases({super.key});

  @override
  State<AdminPendingCases> createState() => _AdminPendingCasesState();
}

class _AdminPendingCasesState extends State<AdminPendingCases> {
  String statusFilter = 'pending';

  Stream<QuerySnapshot> _casesStream() {
    final collection = FirebaseFirestore.instance.collection('pending_cases');
    if (statusFilter == 'all') {
      return collection.orderBy('assignedAt', descending: true).snapshots();
    }
    return collection
        .where('status', isEqualTo: statusFilter)
        .orderBy('assignedAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cases'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const Text('Filter:'),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: statusFilter,
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'ongoing', child: Text('Ongoing')),
                    DropdownMenuItem(
                        value: 'completed', child: Text('Completed')),
                    DropdownMenuItem(value: 'all', child: Text('All')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => statusFilter = v);
                  },
                ),
                const Spacer(),
                Text('Showing: ${statusFilter.toUpperCase()}')
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _casesStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No cases found'));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: ListTile(
                        title: Text('Alert: ${data['alertId']}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Officer: ${data['officerId']}'),
                            if (data['userId'] != null)
                              Text('User: ${data['userId']}'),
                            if (data['assignedAt'] != null)
                              Text('Assigned: ${data['assignedAt']}'),
                            if (data['status'] != null)
                              Text('Status: ${data['status']}'),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // optionally navigate to alert detail or open actions for admin
                        },
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
