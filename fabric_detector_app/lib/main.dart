import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'globals.dart';
import 'screens/camera_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error: $e.code\nError Message: $e.message');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Detector de Defectos',
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _status = "Selecciona un modelo (.onnx)";

  Future<void> _pickModel() async {
    if (await Permission.storage.status.isDenied) {
      await Permission.storage.request();
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null) {
        final path = result.files.single.path;
        if (path != null && path.endsWith(".onnx")) {
          setState(() {
            selectedModelPath = path;
            _status = "Modelo listo:\n${result.files.single.name}";
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Por favor selecciona un archivo .onnx")),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al abrir selector: $e")),
        );
      }
    }
  }

  void _startCamera() {
    if (selectedModelPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("¡Primero carga un modelo!")),
      );
      return;
    }
    if (cameras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se detectaron cámaras")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CameraScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Detector de Defectos")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            const Icon(Icons.memory, size: 64, color: Colors.tealAccent),
            const SizedBox(height: 16),

            // Estado del modelo
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 24),

            // Botón cargar modelo
            ElevatedButton.icon(
              onPressed: _pickModel,
              icon: const Icon(Icons.folder_open),
              label: const Text("Cargar Modelo (.onnx)"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 24),

            // ── CONFIGURACIÓN ─────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Configuración de inferencia",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 16),

                    // Resolución
                    const Text(
                      "Resolución del modelo",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Debe coincidir con la entrada del .onnx que cargaste",
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    const SizedBox(height: 10),
                    ValueListenableBuilder<int>(
                      valueListenable: selectedResolution,
                      builder: (_, res, __) => SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 128, label: Text("128 px")),
                          ButtonSegment(value: 256, label: Text("256 px")),
                          ButtonSegment(value: 512, label: Text("512 px")),
                        ],
                        selected: {res},
                        onSelectionChanged: (Set<int> s) =>
                            selectedResolution.value = s.first,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // NPU toggle
                    ValueListenableBuilder<bool>(
                      valueListenable: useNpu,
                      builder: (_, npu, __) => SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Usar NPU (MediaTek APU 790)"),
                        subtitle: Text(
                          npu
                              ? "NNAPI activo — se intentará delegar al APU"
                              : "CPU — compatible con todos los modelos",
                          style: TextStyle(
                            color: npu ? Colors.tealAccent : Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                        value: npu,
                        activeColor: Colors.tealAccent,
                        onChanged: (v) => useNpu.value = v,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Botón iniciar cámara
            FilledButton.icon(
              onPressed: _startCamera,
              icon: const Icon(Icons.camera_alt),
              label: const Text("INICIAR CÁMARA"),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
