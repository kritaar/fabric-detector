import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/model_service.dart';
import '../main.dart';

class CameraScreen extends StatefulWidget {
  final ModelService modelService;

  const CameraScreen({super.key, required this.modelService});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isDetecting = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras[0],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller!.initialize();
    if (mounted) setState(() {});

    // Start live detection
    _controller!.startImageStream((image) {
      if (!_isDetecting) {
        _isDetecting = true;
        _processImage(image).then((_) {
          _isDetecting = false;
        });
      }
    });
  }

  Future<void> _processImage(CameraImage image) async {
    // TODO: Implement ONNX inference
    // Convert CameraImage to format compatible with ONNX
    // Run inference
    // Draw bounding boxes
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cámara en Vivo'),
        backgroundColor: Colors.black87,
      ),
      body: Stack(
        children: [
          CameraPreview(_controller!),
          // TODO: Add bounding box overlay
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton.extended(
                onPressed: () async {
                  final image = await _controller!.takePicture();
                  if (mounted) {
                    // TODO: Show result screen
                  }
                },
                label: const Text('CAPTURAR'),
                icon: const Icon(Icons.camera),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
