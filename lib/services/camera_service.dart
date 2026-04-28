import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';

// Camera recording helper (scaffold). Usage:
// await CameraService.instance.init();
// await CameraService.instance.startRecording();
// final file = await CameraService.instance.stopRecording();

class CameraService {
  CameraService._private();
  static final CameraService instance = CameraService._private();

  CameraController? _controller;
  CameraDescription? _camera;

  Future<void> init() async {
    final cameras = await availableCameras();
    // Prefer back camera if available
    _camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    _controller =
        CameraController(_camera!, ResolutionPreset.medium, enableAudio: true);
    await _controller!.initialize();
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }

  Future<void> startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      await init();
    }
    if (!_controller!.value.isRecordingVideo) {
      await _controller!.startVideoRecording();
    }
  }

  Future<File?> stopRecording() async {
    if (_controller == null || !_controller!.value.isRecordingVideo) {
      return null;
    }
    final XFile xf = await _controller!.stopVideoRecording();
    final dir = await getTemporaryDirectory();
    final out =
        File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}.mp4');
    return File(xf.path).copy(out.path);
  }
}
