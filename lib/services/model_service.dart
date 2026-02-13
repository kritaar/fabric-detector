import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class ModelService {
  Interpreter? _interpreter;
  String? _currentModel;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  String? get currentModel => _currentModel;

  Future<void> loadModel(String modelFileName) async {
    try {
      print('Loading model: $modelFileName');
      
      // Release previous interpreter
      _interpreter?.close();
      
      // Load new model from assets
      // Note: Use .tflite extension instead of .onnx
      final tfliteFileName = modelFileName.replaceAll('.onnx', '.tflite');
      _interpreter = await Interpreter.fromAsset('models/$tfliteFileName');
      
      _currentModel = modelFileName;
      _isLoaded = true;
      
      print('✓ Model loaded successfully: $tfliteFileName');
      print('  Input shape: ${_interpreter!.getInputTensor(0).shape}');
      print('  Output shape: ${_interpreter!.getOutputTensor(0).shape}');
    } catch (e) {
      print('✗ Error loading model: $e');
      _isLoaded = false;
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> detectDefects(
    List<List<List<List<double>>>> inputData
  ) async {
    if (!_isLoaded || _interpreter == null) {
      throw Exception('Model not loaded');
    }

    try {
      // Prepare output buffer
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final output = List.generate(
        outputShape[0],
        (_) => List.generate(
          outputShape[1],
          (_) => List.generate(
            outputShape[2],
            (_) => List.filled(outputShape[3], 0.0),
          ),
        ),
      );

      // Run inference
      _interpreter!.run(inputData, output);

      // TODO: Process outputs to extract bounding boxes
      // This will depend on your model's output format
      final List<Map<String, dynamic>> detections = [];
      
      return detections;
    } catch (e) {
      print('Error during inference: $e');
      return [];
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }
}
