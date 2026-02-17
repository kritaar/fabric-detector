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
      title: 'Fabric Detector',
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
    // En Android 13+, Permission.storage suele estar denegado permanentemente.
    // FilePicker usa el selector del sistema que no requiere permiso explícito.
    // Solo pedimos si es estrictamente necesario (versiones antiguas).
    if (await Permission.storage.status.isDenied) {
      await Permission.storage.request();
    }
    
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, // 'any' es más seguro si 'onnx' falla por MIME type
      );

      if (result != null) {
        final path = result.files.single.path;
        if (path != null && path.endsWith(".onnx")) {
             setState(() {
              selectedModelPath = path;
              _status = "Modelo listo:\n${result.files.single.name}";
            });
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Por favor selecciona un archivo .onnx")),
          );
        }
      }
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al abrir selector: $e")),
      );
    }
  }

  void _startCamera() {
    if (selectedModelPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("¡Primero carga un modelo!")),
      );
      return;
    }
// ... existing code ...
    ElevatedButton.icon(
              onPressed: _pickModel,
              icon: const Icon(Icons.folder_open),
              label: const Text("Cargar Modelo (.onnx)"), // RENAMED
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(20)),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _startCamera,
              icon: const Icon(Icons.camera_alt),
              label: const Text("INICIAR CÁMARA"),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                textStyle: const TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
