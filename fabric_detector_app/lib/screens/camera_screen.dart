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
  List<double>? _currentDefectMap;
  final StringBuffer _logs = StringBuffer(); // Log buffer

  @override
  void initState() {
    super.initState();
    _log("Iniciando CameraScreen...");
    _initCamera();
    if (selectedModelPath != null) {
      _loadModel();
    } else {
      _log("Advertencia: No hay modelo seleccionado.");
    }
  }

  void _log(String msg) {
    print(msg);
    _logs.writeln("${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second} - $msg");
  }

  void _showLogs() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Logs de Depuración"),
        content: SingleChildScrollView(
          child: Text(_logs.toString(), style: const TextStyle(fontSize: 12)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cerrar"),
          ),
          TextButton(
            onPressed: () {
              setState(() { _logs.clear(); });
              Navigator.pop(ctx);
            },
            child: const Text("Limpiar"),
          )
        ],
      ),
    );
  }

  Future<void> _loadModel() async {
    _log("Cargando modelo desde: $selectedModelPath");
    try {
      await _inferenceService.loadModel(selectedModelPath!);
      _log("Modelo cargado correctamente.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Modelo cargado correctamente")),
        );
      }
    } catch (e) {
      _log("Error fatal cargando modelo: $e");
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
    _log("Inicializando cámara...");
    if (cameras.isEmpty) {
      _log("Error: Lista de cámaras vacía.");
      return;
    }

    _controller = CameraController(
      cameras[0],
      ResolutionPreset.medium, 
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _controller!.initialize();
      _log("Cámara inicializada.");
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
                if (result == null) {
                   // Si es null, quizás el modelo no está listo o error
                   if (_inferenceService.isReady) {
                      _fpsText = "Error en Inferencia ($ms ms)";
                   } else {
                      _fpsText = "Esperando modelo...";
                   }
                } else {
                   _fpsText = "Inf: ${ms}ms";
                   _currentDefectMap = result;
                }
             });
          }
          _isDetecting = false;
        }).catchError((e) {
           _log("Error en loop de inferencia: $e");
           _isDetecting = false;
           if (mounted) {
             setState(() { _fpsText = "Error: Ver Logs"; });
           }
        });
      });
      _log("Stream de imágenes iniciado.");
      
    } catch (e) {
      _log("Excepción al iniciar cámara: $e");
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
          // 1. Cámara
          CameraPreview(_controller!),
          
          // 2. Overlay de Defectos
          if (_currentDefectMap != null)
             Positioned.fill(
               child: CustomPaint(
                 painter: DefectPainter(
                   heatmap: _currentDefectMap!,
                   sensitivity: sensitivity.value,
                 ),
               ),
             ),
          
          // 3. UI Info (Click para Logs)
          Positioned(
            top: 40,
            left: 20,
            child: GestureDetector(
              onTap: _showLogs,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.greenAccent)
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bug_report, color: Colors.greenAccent, size: 16),
                    const SizedBox(width: 8),
                    Text(_fpsText, style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
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
                               setState((){}); 
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

class DefectPainter extends CustomPainter {
  final List<double> heatmap;
  final double sensitivity;

  DefectPainter({required this.heatmap, required this.sensitivity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    
    // Asumimos salida 512x512
    final double scaleX = size.width / 512;
    final double scaleY = size.height / 512;
    final double threshold = sensitivity; 
    
    // Optimización: Dibujar 1 de cada 4 pixels para rendimiento
    for (int y = 0; y < 512; y += 4) {
      for (int x = 0; x < 512; x += 4) {
        final int index = y * 512 + x;
        if (index < heatmap.length) {
          if (heatmap[index] > threshold) {
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
