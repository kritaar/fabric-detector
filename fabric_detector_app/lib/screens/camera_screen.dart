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
  String _fpsText = "Iniciando...";
  List<double>? _currentDefectMap;
  final StringBuffer _logs = StringBuffer();

  // Snapshot de la config activa (la que se usó al cargar el modelo)
  int _activeResolution = selectedResolution.value;
  bool _activeNpu = useNpu.value;

  @override
  void initState() {
    super.initState();
    _inferenceService.onLog = _log;
    _log("Iniciando cámara...");
    _initCamera();
    if (selectedModelPath != null) {
      _loadModel();
    } else {
      _log("Advertencia: no hay modelo seleccionado.");
    }
  }

  void _log(String msg) {
    print(msg);
    if (mounted) {
      setState(() {
        _logs.writeln(
          "${DateTime.now().hour.toString().padLeft(2, '0')}:"
          "${DateTime.now().minute.toString().padLeft(2, '0')}:"
          "${DateTime.now().second.toString().padLeft(2, '0')} — $msg",
        );
      });
    }
  }

  Future<void> _loadModel() async {
    _log("Cargando modelo [res=${selectedResolution.value}px, "
        "npu=${useNpu.value}]...");
    try {
      await _inferenceService.loadModel(
        selectedModelPath!,
        useNpu: useNpu.value,
      );

      // Auto-ajustar resolución si el modelo la reportó
      final detected = _inferenceService.detectedResolution;
      if (detected != null && detected != selectedResolution.value) {
        selectedResolution.value = detected;
        _log("⚠ Resolución ajustada a ${detected}px para coincidir con el modelo");
      }

      _activeResolution = selectedResolution.value;
      _activeNpu = useNpu.value;
      if (mounted) setState(() {});
      _log("Listo. Dispositivo activo: ${_inferenceService.npuActive ? 'GPU (Mali-G615)' : 'CPU'}");
    } catch (e) {
      _log("Error fatal cargando modelo: $e");
    }
  }

  Future<void> _initCamera() async {
    if (cameras.isEmpty) {
      _log("Error: no hay cámaras disponibles.");
      return;
    }

    _controller = CameraController(
      cameras[0],
      ResolutionPreset.high,
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
        final int res = _activeResolution;

        _inferenceService.runInference(image, resolution: res).then((result) {
          final ms = DateTime.now().difference(startTime).inMilliseconds;
          if (mounted) {
            setState(() {
              if (result != null) {
                _fpsText =
                    "${ms}ms  |  ${res}px  |  ${_inferenceService.npuActive ? 'NPU' : 'CPU'}";
                _currentDefectMap = result;
              } else if (!_inferenceService.isReady) {
                _fpsText = "Esperando modelo...";
              }
            });
          }
          _isDetecting = false;
        }).catchError((e) {
          _log("Error en stream: $e");
          _isDetecting = false;
        });
      });
    } catch (e) {
      _log("Error inicializando cámara: $e");
    }
  }

  void _showLogs() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Logs"),
        content: SingleChildScrollView(
          child: Text(_logs.toString(), style: const TextStyle(fontSize: 11)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cerrar")),
          TextButton(
            onPressed: () {
              setState(() => _logs.clear());
              Navigator.pop(ctx);
            },
            child: const Text("Limpiar"),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    // Valores temporales dentro del sheet
    int tempRes = selectedResolution.value;
    bool tempNpu = useNpu.value;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Configuración de inferencia",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 20),

              // Resolución
              const Text("Resolución del modelo",
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 4),
              const Text(
                "Debe coincidir con la entrada del .onnx cargado",
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 10),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 128, label: Text("128 px")),
                  ButtonSegment(value: 256, label: Text("256 px")),
                  ButtonSegment(value: 512, label: Text("512 px")),
                ],
                selected: {tempRes},
                onSelectionChanged: (s) =>
                    setSheetState(() => tempRes = s.first),
              ),
              const SizedBox(height: 20),

              // NPU toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Aceleración GPU/NPU"),
                subtitle: Text(
                  tempNpu
                      ? "GPU Delegate activo (Mali-G615)"
                      : "CPU — compatible con todos los modelos",
                  style: TextStyle(
                    color: tempNpu ? Colors.tealAccent : Colors.white38,
                    fontSize: 12,
                  ),
                ),
                value: tempNpu,
                activeColor: Colors.tealAccent,
                onChanged: (v) => setSheetState(() => tempNpu = v),
              ),
              const SizedBox(height: 8),

              // Advertencia si cambió NPU/res
              if (tempRes != _activeResolution || tempNpu != _activeNpu)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.4)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Se recargará el modelo al aplicar",
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                  ]),
                ),
              const SizedBox(height: 16),

              // Botones
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancelar"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      // Aplicar cambios globales
                      selectedResolution.value = tempRes;
                      useNpu.value = tempNpu;
                      // Recargar modelo si algo cambió
                      if (tempRes != _activeResolution ||
                          tempNpu != _activeNpu) {
                        _currentDefectMap = null;
                        _loadModel();
                      }
                    },
                    child: const Text("Aplicar"),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _inferenceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── VISTA SUPERIOR: CÁMARA REAL ──────────────────────
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(_controller!),
                  Positioned(
                    top: 10, left: 10,
                    child: _Chip(text: "Cámara Real"),
                  ),
                  // Botón configuración
                  Positioned(
                    top: 6, right: 52,
                    child: IconButton(
                      icon: const Icon(Icons.tune, color: Colors.white70),
                      tooltip: "Configuración",
                      onPressed: _showSettings,
                    ),
                  ),
                  // Botón logs
                  Positioned(
                    top: 6, right: 6,
                    child: IconButton(
                      icon: const Icon(Icons.bug_report,
                          color: Colors.greenAccent),
                      tooltip: "Logs",
                      onPressed: _showLogs,
                    ),
                  ),
                ],
              ),
            ),

            Container(height: 2, color: Colors.white24),

            // ── VISTA INFERIOR: MAPA DE DEFECTOS ─────────────────
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: Colors.grey[900]),
                  if (_currentDefectMap != null)
                    CustomPaint(
                      painter: DefectPainter(
                        heatmap: _currentDefectMap!,
                        sensitivity: sensitivity.value,
                        resolution: _activeResolution,
                      ),
                    )
                  else
                    Center(
                      child: Text(
                        _fpsText,
                        style: const TextStyle(color: Colors.white38),
                      ),
                    ),
                  Positioned(
                    top: 10, left: 10,
                    child: _Chip(
                      text: "Mapa de Defectos (IA)",
                      color: Colors.redAccent,
                    ),
                  ),
                  if (_currentDefectMap != null)
                    Positioned(
                      bottom: 8, right: 10,
                      child: Text(
                        _fpsText,
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── CONTROLES INFERIORES ──────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: Colors.black,
              child: Column(
                children: [
                  Row(children: [
                    const Text("Sensibilidad",
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const Spacer(),
                    ValueListenableBuilder<double>(
                      valueListenable: sensitivity,
                      builder: (_, v, __) => Text(
                        v.toStringAsFixed(2),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ]),
                  ValueListenableBuilder<double>(
                    valueListenable: sensitivity,
                    builder: (_, v, __) => Slider(
                      value: v,
                      min: 0.0,
                      max: 1.0,
                      activeColor: Colors.redAccent,
                      onChanged: (val) {
                        sensitivity.value = val;
                        setState(() {});
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Info del modo activo
                      Text(
                        "${_activeResolution}px · ${_inferenceService.npuActive ? 'NPU' : 'CPU'}",
                        style: TextStyle(
                          color: _inferenceService.npuActive
                              ? Colors.tealAccent
                              : Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                      FloatingActionButton.small(
                        backgroundColor: Colors.red,
                        onPressed: () => Navigator.pop(context),
                        child: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widget auxiliar para etiquetas de overlay ────────────────────────────────

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip({required this.text, this.color = Colors.white70});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 12)),
      );
}

// ── Painter del heatmap ──────────────────────────────────────────────────────

class DefectPainter extends CustomPainter {
  final List<double> heatmap;
  final double sensitivity;
  final int resolution;

  const DefectPainter({
    required this.heatmap,
    required this.sensitivity,
    required this.resolution,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final double scaleX = size.width / resolution;
    final double scaleY = size.height / resolution;
    // Paso de pixel: más detalle a 128/256, optimización de render a 512
    final int step = resolution <= 256 ? 2 : 4;

    for (int y = 0; y < resolution; y += step) {
      for (int x = 0; x < resolution; x += step) {
        final int index = y * resolution + x;
        if (index < heatmap.length && heatmap[index] > sensitivity) {
          canvas.drawRect(
            Rect.fromLTWH(
              x * scaleX,
              y * scaleY,
              step * scaleX + 1,
              step * scaleY + 1,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant DefectPainter old) =>
      old.heatmap != heatmap ||
      old.sensitivity != sensitivity ||
      old.resolution != resolution;
}
