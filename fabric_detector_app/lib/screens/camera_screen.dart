import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../globals.dart';
import '../services/inference_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  final InferenceService _inferenceService = InferenceService();
  bool _isDetecting = false;
  String _fpsText = "FPS: -";

  @override
  void initState() {
    super.initState();
    _initCamera();
    if (selectedModelPath != null) {
      _inferenceService.loadModel(selectedModelPath!);
    }
  }

  Future<void> _initCamera() async {
    _controller = CameraController(
      cameras[0], // Cámara trasera
      ResolutionPreset.medium, // 480p/720p es suficiente para IA y más rápido (30ms)
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _controller!.initialize();
      if (!mounted) return;
      setState(() {});

      _controller!.startImageStream((image) {
        if (_isDetecting) return;
        _isDetecting = true;
        
        final startTime = DateTime.now();
        
        _inferenceService.runInference(image).then((result) {
          final endTime = DateTime.now();
          final ms = endTime.difference(startTime).inMilliseconds;
          
          if (mounted) {
             setState(() {
                _fpsText = "Inferencia: ${ms}ms";
                // TODO: Actualizar overlay con 'result'
             });
          }
          _isDetecting = false;
        });
      });
      
    } catch (e) {
      print("Error cámara: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Vista de Cámara
          CameraPreview(_controller!),
          
          // 2. Overlay de Defectos (Rojo)
          // CustomPaint(painter: DefectPainter(...)),
          
          // 3. UI Controles
          Positioned(
            top: 40,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black54,
              child: Text(_fpsText, style: const TextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              children: [
                const Text("Sensibilidad", style: TextStyle(color: Colors.white)),
                ValueListenableBuilder<double>(
                  valueListenable: sensitivity,
                  builder: (context, value, child) {
                    return Slider(
                      value: value,
                      min: 0.0,
                      max: 1.0,
                      activeColor: Colors.redAccent,
                      onChanged: (v) => sensitivity.value = v,
                    );
                  },
                ),
                FloatingActionButton(
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
