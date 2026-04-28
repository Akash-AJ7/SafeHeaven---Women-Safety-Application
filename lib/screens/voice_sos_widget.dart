import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/voice_service.dart';
import '../services/camera_service.dart';
import '../services/upload_service.dart';

class VoiceSosWidget extends StatefulWidget {
  final String userId;
  final Future<void> Function()? onSosTriggered;
  const VoiceSosWidget({super.key, required this.userId, this.onSosTriggered});

  @override
  State<VoiceSosWidget> createState() => _VoiceSosWidgetState();
}

class _VoiceSosWidgetState extends State<VoiceSosWidget> {
  StreamSubscription<String>? _phraseSub;
  bool _listening = false;
  bool _sosActive = false;
  int _countdown = 10;
  Timer? _countdownTimer;
  File? _recordedFile;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    await Permission.microphone.request();
    await Permission.camera.request();
    await VoiceService.instance.init();
    _phraseSub = VoiceService.instance.onPhrase.listen(_onPhrase);
    // start listening (scaffold). For continuous/background listening,
    // consider `flutter_foreground_task` and platform specific code.
    await VoiceService.instance.startListening();
    setState(() => _listening = true);
  }

  void _onPhrase(String phrase) {
    final cleaned = phrase.toLowerCase();
    // Trigger phrase
    if (!_sosActive && cleaned.contains('help aj')) {
      _startSosSequence();
    }
    // Cancel phrase
    if (_sosActive && cleaned.contains('cancel')) {
      _cancelSos();
    }
  }

  void _startSosSequence() async {
    setState(() {
      _sosActive = true;
      _countdown = 10;
    });

    // start camera recording immediately but wait to upload until countdown ends
    await CameraService.instance.startRecording();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      setState(() {
        _countdown -= 1;
      });
      if (_countdown <= 0) {
        t.cancel();
        // stop recording
        final file = await CameraService.instance.stopRecording();

        // If a host callback exists, call it to create the alert (e.g., `sendSOS`).
        if (widget.onSosTriggered != null) {
          try {
            await widget.onSosTriggered!();
          } catch (e) {
            // ignore: avoid_print
            print('onSosTriggered callback failed: $e');
          }

          // After alert creation, upload video and attach to latest alert
          if (file != null) {
            _recordedFile = file;
            final url = await UploadService.instance
                .uploadVideoFile(file, widget.userId);
            await UploadService.instance
                .updateLatestAlertWithVideo(widget.userId, url);
          }
        } else {
          // Legacy: create alert and upload video here
          if (file != null) {
            _recordedFile = file;
            final url = await UploadService.instance
                .uploadVideoFile(file, widget.userId);
            await UploadService.instance.createAlertDocument({
              'userId': widget.userId,
              'videoUrl': url,
              'lat': 0.0,
              'lng': 0.0,
              'pincode': null,
              'status': 'active',
              'createdAt': DateTime.now().toUtc(),
            });
          }
        }

        setState(() {
          _sosActive = false;
        });
      }
    });
  }

  void _cancelSos() async {
    _countdownTimer?.cancel();
    // stop recording and discard
    final file = await CameraService.instance.stopRecording();
    if (file != null) {
      try {
        await file.delete();
      } catch (_) {}
    }
    setState(() {
      _sosActive = false;
      _countdown = 10;
    });
  }

  @override
  void dispose() {
    _phraseSub?.cancel();
    _countdownTimer?.cancel();
    VoiceService.instance.dispose();
    CameraService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_sosActive)
          Card(
            color: Colors.red[50],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('🚨 Emergency Detected!',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('Sending alert in $_countdown seconds...'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _cancelSos,
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                    child: const Text('Cancel SOS'),
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Voice SOS: listening'),
                  ElevatedButton(
                    onPressed: () async {
                      if (_sosActive) {
                        _cancelSos();
                      } else {
                        _startSosSequence();
                      }
                    },
                    child: const Text('Simulate SOS'),
                  )
                ],
              ),
            ),
          )
      ],
    );
  }
}
