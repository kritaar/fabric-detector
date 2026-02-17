import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
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
  String _fpsText = "Iniciando...";
  List<double>? _currentDefectMap; // 512x512 flattened

  @override
  void initState() {
    super.initState();
    _initCamera();
    if (selectedModelPath != null) {
      _loadModel();
    }
  }

  Future<void> _loadModel() async {
    try {
      await _inferenceService.loadModel(selectedModelPath!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Modelo cargado correctamente")),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Error de Modelo"),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK"),
              )
            ],
          ),
        );
      }
    }
  }

  Future<void> _initCamera() async {
    _controller = CameraController(
      cameras[0],
      ResolutionPreset.medium, 
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
        
        // Ejecutar inferencia
        _inferenceService.runInference(image).then((result) {
          final endTime = DateTime.now();
          final ms = endTime.difference(startTime).inMilliseconds;
          
          if (mounted) {
             setState(() {
                _fpsText = "Inferencia: ${ms}ms";
                _currentDefectMap = result; // Actualizar mapa para dibujado
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

    // Calcular escala para el overlay
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Cámara
          CameraPreview(_controller!),
          
          // 2. Overlay de Defectos (CustomPainter)
          if (_currentDefectMap != null)
             Positioned.fill(
               child: CustomPaint(
                 painter: DefectPainter(
                   heatmap: _currentDefectMap!,
                   sensitivity: sensitivity.value,
                 ),
               ),
             ),
          
          // 3. UI Info
          Positioned(
            top: 40,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8)
              ),
              child: Text(_fpsText, style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          
          // 4. Controles
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Sensibilidad", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ValueListenableBuilder<double>(
                  valueListenable: sensitivity,
                  builder: (context, value, child) {
                    return Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: value,
                            min: 0.0,
                            max: 1.0,
                            activeColor: Colors.redAccent,
                            onChanged: (v) {
                               sensitivity.value = v;
                               setState((){}); // Redibujar painter
                            },
                          ),
                        ),
                        Text(value.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                      ],
                    );
                  },
                ),
                Center(
                  child: FloatingActionButton(
                    backgroundColor: Colors.red,
                    mini: true,
                    child: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

// Pintor de Defectos
class DefectPainter extends CustomPainter {
  final List<double> heatmap;
  final double sensitivity;

  DefectPainter({required this.heatmap, required this.sensitivity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    // El heatmap es 512x512. La pantalla puede ser diferente.
    // Dibujamos "pixeles" rojos donde heatmap[i] > sensitivity
    // Optimización: Dibujar rects agrupados sería mejor, pero punto a punto es más fácil de implementar ahora.
    
    // Factor de escala (asumiendo que la cámara llena la pantalla o aspect ratio similar)
    final double scaleX = size.width / 512;
    final double scaleY = size.height / 512;

    // Umbral
    final double threshold = sensitivity; 
    
    // Paso de renderizado (para no matar la UI, dibujamos cada 4 pixeles o similar si es muy lento)
    // Pero intentemos dibujar todo o bloques 2x2.
    
    for (int y = 0; y < 512; y += 4) {
      for (int x = 0; x < 512; x += 4) {
        final int index = y * 512 + x;
        if (index < heatmap.length) {
          final double val = heatmap[index];
          if (val > threshold) {
            // Dibujar bloque rojo 4x4
            canvas.drawRect(
              Rect.fromLTWH(x * scaleX, y * scaleY, 4 * scaleX, 4 * scaleY),
              paint
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant DefectPainter oldDelegate) {
     return oldDelegate.heatmap != heatmap || oldDelegate.sensitivity != sensitivity;
  }
}
