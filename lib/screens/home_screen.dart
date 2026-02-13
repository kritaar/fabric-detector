import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/model_service.dart';
import 'camera_screen.dart';
import 'dart:io';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ModelService _modelService = ModelService();
  String _selectedModel = 'model_general.onnx';
  final ImagePicker _picker = ImagePicker();

  final List<Map<String, String>> _models = [
    {'name': 'General', 'file': 'model_general.onnx', 'desc': 'Todo tipo de telas'},
    {'name': 'Algodón', 'file': 'model_algod.onnx', 'desc': 'Especializado en algodón'},
    {'name': 'Poliéster', 'file': 'model_polyester.onnx', 'desc': 'Especializado en poliéster'},
  ];

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    await _modelService.loadModel(_selectedModel);
    setState(() {});
  }

  Future<void> _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(imagePath: image.path, modelService: _modelService),
        ),
      );
    }
  }

  void _openCamera() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(modelService: _modelService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detector de Defectos'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Model selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Modelo Activo',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    DropdownButton<String>(
                      value: _selectedModel,
                      isExpanded: true,
                      items: _models.map((model) {
                        return DropdownMenuItem<String>(
                          value: model['file']!,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(model['name']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(model['desc']!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedModel = value;
                          });
                          _loadModel();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Camera button
            ElevatedButton.icon(
              onPressed: _openCamera,
              icon: const Icon(Icons.camera_alt, size: 32),
              label: const Text('Cámara en Vivo', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Gallery button
            ElevatedButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library, size: 32),
              label: const Text('Seleccionar de Galería', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),

            const Spacer(),

            // Info
            const Text(
              'Instrucciones:\n'
              '1. Selecciona el modelo para tu tipo de tela\n'
              '2. Usa la cámara o galería\n'
              '3. Analiza los defectos detectados',
              style: TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Result screen placeholder
class ResultScreen extends StatelessWidget {
  final String imagePath;
  final ModelService modelService;

  const ResultScreen({super.key, required this.imagePath, required this.modelService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resultado')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.file(File(imagePath), height: 300),
            const SizedBox(height: 20),
            const Text('Análisis en progreso...'),
          ],
        ),
      ),
    );
  }
}
