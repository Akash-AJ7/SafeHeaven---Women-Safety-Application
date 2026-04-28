import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UploadService {
  UploadService._private();
  static final UploadService instance = UploadService._private();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> uploadVideoFile(File file, String userId) async {
    try {
      final ref = _storage
          .ref()
          .child('sos_videos')
          .child('$userId-${DateTime.now().millisecondsSinceEpoch}.mp4');
      final task = await ref.putFile(file);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      // ignore: avoid_print
      print('Video upload failed: $e');
      return null;
    }
  }

  Future<DocumentReference> createAlertDocument(
      Map<String, dynamic> data) async {
    return await _firestore.collection('alerts').add(data);
  }

  /// Update the most recent alert document for [userId] with a video URL.
  /// This helps associate an uploaded video with an alert created by another flow.
  Future<void> updateLatestAlertWithVideo(
      String userId, String? videoUrl) async {
    if (videoUrl == null) return;
    try {
      final q = await _firestore
          .collection('alerts')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        final doc = q.docs.first;
        await doc.reference.update({'videoUrl': videoUrl});
      }
    } catch (e) {
      // ignore: avoid_print
      print('Failed to attach video to latest alert: $e');
    }
  }
}
