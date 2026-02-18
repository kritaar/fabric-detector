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
  final StringBuffer _logs = StringBuffer();

  @override
  void initState() {
    super.initState();
    _inferenceService.onLog = _log; // Conectar logs
    
    _log("Iniciando CameraScreen (Split View)...");
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
      ResolutionPreset.high, // 720p mínimo
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
                   if (_inferenceService.isReady) {
                      // Solo mostrar error si pasa mucho tiempo, para no flasear
                   } else {
                      _fpsText = "Esperando modelo...";
                   }
                } else {
                   _fpsText = "Inferencia: ${ms}ms";
                   _currentDefectMap = result;
                }
             });
          }
          _isDetecting = false;
        }).catchError((e) {
           _log("Error en loop: $e");
           _isDetecting = false;
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
      backgroundColor: Colors.black,
      body: SafeArea( // FIX: Evita que la barra de estado tape botones (Notch/Status Bar)
        child: Column(
          children: [
            // --- VISTA SUPERIOR: CÁMARA REAL ---
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(_controller!), // Se verá recortado por SafeArea, pero seguro
                  Positioned(
                    top: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      color: Colors.black54,
                      child: const Text("Cámara Real", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  // Botón Logs (Más grande y accesible)
                  Positioned(
                    top: 10, right: 10,
                    child: GestureDetector(
                      onTap: _showLogs,
                      child: Container(
                        padding: const EdgeInsets.all(12), // Zona táctil más grande
                        color: Colors.transparent, // Necesario para detectar tap en padding
                        child: const Icon(Icons.bug_report, color: Colors.greenAccent, size: 32),
                      ),
                    ),
                  )
                ],
              ),
            ),
          
          // --- DIVISOR ---
          Container(height: 2, color: Colors.white30),
          
          // --- VISTA INFERIOR: MAPA DE DEFECTOS (HEATMAP) ---
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Fondo negro o gris oscuro para resaltar el rojo
                Container(color: Colors.grey[900]),
                
                if (_currentDefectMap != null)
                   CustomPaint(
                     painter: DefectPainter(
                       heatmap: _currentDefectMap!,
                       sensitivity: sensitivity.value,
                     ),
                   )
                else
                   Center(
                     child: Text(
                       _fpsText,
                       style: const TextStyle(color: Colors.white54),
                     ),
                   ),

                Positioned(
                  top: 10, left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: Colors.black54,
                    child: const Text("Mapa de Defectos (IA)", style: TextStyle(color: Colors.redAccent)),
                  ),
                ),
                
                // Info FPS Overlay en la vista de abajo también
                if (_currentDefectMap != null)
                  Positioned(
                    bottom: 10, right: 10,
                    child: Text(_fpsText, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          
          // --- CONTROLES (ABAJO DEL TODO) ---
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black,
            child: Column(
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
                const SizedBox(height: 10),
                FloatingActionButton(
                  backgroundColor: Colors.red,
                  mini: true,
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

class DefectPainter extends CustomPainter {
  final List<double> heatmap;
  final double sensitivity;

  DefectPainter({required this.heatmap, required this.sensitivity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    
    // Asumimos salida 512x512
    // IMPORTANTE: Escalar al tamaño del widget (Expanded inferior)
    final double scaleX = size.width / 512;
    final double scaleY = size.height / 512;
    final double threshold = sensitivity; 
    
    // Optimización: Dibujar 1 de cada 4 pixels
    for (int y = 0; y < 512; y += 4) {
      for (int x = 0; x < 512; x += 4) {
        final int index = y * 512 + x;
        if (index < heatmap.length) {
          if (heatmap[index] > threshold) {
            // Dibujar rectángulo proporcional
            canvas.drawRect(
              Rect.fromLTWH(x * scaleX, y * scaleY, 4 * scaleX + 1, 4 * scaleY + 1), // +1 para evitar huecos
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
