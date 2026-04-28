import 'dart:async';
import 'package:flutter/services.dart';

// Lightweight stub VoiceService used for local testing/builds.
// Emits phrases via `onPhrase` stream. Replace with real
// speech_to_text integration when platform compatibility is resolved.

class VoiceService {
  VoiceService._private();
  static final VoiceService instance = VoiceService._private();

  final StreamController<String> _onPhrase = StreamController.broadcast();
  Stream<String> get onPhrase => _onPhrase.stream;

  static const MethodChannel _controlChannel =
      MethodChannel('safeheaven/voice_service');
  static const MethodChannel _eventChannel =
      MethodChannel('safeheaven/voice_events');

  Future<void> init() async {
    // Hook native event channel so native service can forward voice events.
    _eventChannel.setMethodCallHandler((call) async {
      if (call.method == 'onVoiceEvent') {
        final arg = call.arguments;
        if (arg is String) {
          _onPhrase.add(arg);
        }
      }
    });
    return;
  }

  Future<void> startListening() async {
    // Start native foreground service when available
    try {
      await _controlChannel.invokeMethod('startService');
    } catch (_) {}
  }

  Future<void> stopListening() async {
    try {
      await _controlChannel.invokeMethod('stopService');
    } catch (_) {}
    return;
  }

  /// Helper for tests: simulate a recognized phrase
  void simulatePhrase(String phrase) {
    _onPhrase.add(phrase);
  }

  void dispose() {
    _onPhrase.close();
  }
}
