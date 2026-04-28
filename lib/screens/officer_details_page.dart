// lib/screens/officer_details_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:safeheaven/services/email_service.dart';

/// Expects arguments when pushed:
/// Navigator.pushNamed(context, '/officer/details', arguments: {
///   'docId': '<firestore-doc-id>',
///   'data': <Map<String, dynamic>>
/// });
class OfficerDetailsPage extends StatefulWidget {
  const OfficerDetailsPage({super.key});

  @override
  State<OfficerDetailsPage> createState() => _OfficerDetailsPageState();
}

class _OfficerDetailsPageState extends State<OfficerDetailsPage>
    with SingleTickerProviderStateMixin {
  bool _processing = false;
  final TextEditingController _commentController = TextEditingController();
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _commentController.dispose();
    super.dispose();
  }

  String _generateOfficerId() {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    return 'OF-${ts.substring(ts.length - 6)}';
  }

  Future<int> _generateBadgeNumber() async {
    try {
      DocumentSnapshot counterDoc = await FirebaseFirestore.instance
          .collection("admin")
          .doc("badge_counter")
          .get();

      int nextBadgeNumber = 1;
      if (counterDoc.exists) {
        nextBadgeNumber = (counterDoc.data() as Map)["lastBadgeNumber"] ?? 0;
        nextBadgeNumber++;
      }

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

  Future<void> _approveOfficer(String docId, Map data) async {
    setState(() => _processing = true);

    try {
      final officerId = _generateOfficerId();
      final badgeNumber = await _generateBadgeNumber();
      String officerEmail = data['email'] ?? '';
      String officerName = data['name'] ?? 'Officer';

      await FirebaseFirestore.instance
          .collection('officers')
          .doc(docId)
          .update({
        'status': 'approved',
        'officerId': officerId,
        'badgeNumber': badgeNumber,
        'admin_comment': '',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      // Send approval email to officer
      bool emailSent = false;
      if (officerEmail.isNotEmpty) {
        emailSent = await EmailService.sendApprovalEmail(
          to: officerEmail,
          officerId: officerId,
          badgeNumber: badgeNumber,
        );
      }

      // Record email send status on officer document for debugging
      try {
        await FirebaseFirestore.instance.collection('officers').doc(docId).set({
          'approval_email_sent': emailSent,
          'approval_email_sent_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        print('Failed to write approval email status to Firestore: $e');
      }

      setState(() => _processing = false);
      _animCtrl.forward();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            emailSent
                ? 'Approved — Officer ID: $officerId (Email sent to $officerEmail)'
                : 'Approved — Officer ID: $officerId',
          ),
        ),
      );

      // small delay to let the animation show
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error approving application: $e')),
      );
    }
  }

  Future<void> _rejectOfficer(String docId, Map data, String reason) async {
    setState(() => _processing = true);

    try {
      // Soft Rejection: Update status and save admin comment
      // Data is NOT deleted, officer can resubmit
      await FirebaseFirestore.instance
          .collection('officers')
          .doc(docId)
          .update({
        'status': 'rejected',
        'officerId': '',
        'admin_comment': reason,
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      // Send rejection email to officer with retry
      String officerEmail = data['email'] ?? '';
      String officerName = data['name'] ?? 'Officer';
      bool emailSent = false;
      if (officerEmail.isNotEmpty) {
        const int maxAttempts = 3;
        for (int attempt = 1; attempt <= maxAttempts; attempt++) {
          print('Attempt $attempt to send rejection email to $officerEmail');
          try {
            emailSent = await EmailService.sendRejectionEmail(
              to: officerEmail,
              officerName: officerName,
              rejectionReason: reason,
            );
            if (emailSent) {
              print('Rejection email delivered on attempt $attempt');
              break;
            } else {
              print('Rejection email returned false on attempt $attempt');
            }
          } catch (e) {
            print(
                'Exception while sending rejection email on attempt $attempt: $e');
          }

          // small backoff before retrying
          await Future.delayed(Duration(seconds: 2 * attempt));
        }
      }

      // Record rejection email send status on officer document for debugging
      try {
        await FirebaseFirestore.instance.collection('officers').doc(docId).set({
          'rejection_email_sent': emailSent,
          'rejection_email_sent_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        print('Failed to write rejection email status to Firestore: $e');
      }

      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            emailSent
                ? 'Rejected — Rejection email sent to $officerEmail. Officer can resubmit after fixing issues.'
                : 'Rejected — Officer can resubmit after fixing issues.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting application: $e')),
      );
    }
  }

  void _showRejectDialog(String docId, Map data) {
    _commentController.text = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Application'),
        content: TextField(
          controller: _commentController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter rejection reason (visible to applicant)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: _processing
                ? null
                : () {
                    final reason = _commentController.text.trim();
                    if (reason.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a reason')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    _rejectOfficer(docId, data, reason);
                  },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Widget _imageTile(String? url, String label) {
    return Column(
      children: [
        Container(
          width: 140,
          height: 160,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
            image: url != null && url.isNotEmpty
                ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
                : null,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: url == null || url.isEmpty
              ? Center(
                  child: Text(label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54)))
              : null,
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args == null || args['docId'] == null || args['data'] == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Officer Details')),
        body: const Center(child: Text('No data supplied')),
      );
    }

    final String docId = args['docId'] as String;
    final Map data = Map<String, dynamic>.from(args['data'] as Map);

    return Scaffold(
      appBar: AppBar(title: const Text('Officer Details')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.pink,
                        child: Text(
                            data['name'] != null
                                ? data['name'][0].toString().toUpperCase()
                                : 'O',
                            style: const TextStyle(
                                fontSize: 28, color: Colors.white))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['name'] ?? 'No name',
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(data['email'] ?? '',
                                style: const TextStyle(color: Colors.black54)),
                            const SizedBox(height: 4),
                            Text(data['phone'] ?? '',
                                style: const TextStyle(color: Colors.black54)),
                          ]),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Status badge
                Row(
                  children: [
                    Chip(
                      label: Text((data['status'] ?? 'pending')
                          .toString()
                          .toUpperCase()),
                      backgroundColor: (data['status'] == 'approved')
                          ? Colors.green.shade50
                          : (data['status'] == 'rejected'
                              ? Colors.red.shade50
                              : Colors.orange.shade50),
                      avatar: Icon(
                        data['status'] == 'approved'
                            ? Icons.check_circle
                            : data['status'] == 'rejected'
                                ? Icons.cancel
                                : Icons.hourglass_top,
                        color: data['status'] == 'approved'
                            ? Colors.green
                            : data['status'] == 'rejected'
                                ? Colors.red
                                : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if ((data['officerId'] ?? '').toString().isNotEmpty)
                      Text('ID: ${data['officerId']}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),

                const SizedBox(height: 18),

                // Photos
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _imageTile(data['photo'] as String? ?? '', 'Real Photo'),
                    _imageTile(data['govt_proof'] as String? ?? '', 'ID Proof'),
                  ],
                ),

                const SizedBox(height: 18),

                // Additional info
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Application Details',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (data['address'] != null)
                            Text('Address: ${data['address']}'),
                          if (data['createdAt'] != null)
                            Text('Submitted: ${data['createdAt'].toString()}'),
                          if (data['admin_comment'] != null &&
                              (data['admin_comment'] as String).isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 12),
                                const Text('Admin Comment:',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                Text(data['admin_comment']),
                              ],
                            ),
                        ]),
                  ),
                ),

                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.verified_user),
                        label: const Text('Approve'),
                        onPressed: _processing
                            ? null
                            : () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Approve Officer'),
                                    content: const Text(
                                        'Are you sure you want to approve this application? An Officer ID will be generated.'),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(_, false),
                                          child: const Text('Cancel')),
                                      ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(_, true),
                                          child: const Text('Approve')),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  await _approveOfficer(docId, data);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.block),
                        label: const Text('Reject'),
                        onPressed: _processing
                            ? null
                            : () => _showRejectDialog(docId, data),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),

          // Processing overlay
          if (_processing)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),

          // Success animated banner
          Positioned(
            top: 18,
            right: 18,
            child: SizeTransition(
              sizeFactor:
                  CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
              axisAlignment: 1.0,
              child: Material(
                elevation: 4,
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Approved', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
