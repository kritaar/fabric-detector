import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:camera/camera.dart';

class InferenceService {
  OrtSession? _session;
  bool _isReady = false;

  Future<void> loadModel(String path) async {
    _isReady = false;
    _session?.release();
    try {
      final sessionOptions = OrtSessionOptions();
      // Intenta usar NNAPI (NPU) en Android si es posible
      // sessionOptions.addDelegate(OrtEnv.instance.createNnapiDelegate()); 
      // Nota: NnapiDelegate requiere configuración extra, por defecto CPU/Int8 es rápido

      _session = OrtSession.fromFile(File(path), sessionOptions);
      _isReady = true;
      print("Modelo cargado OK: $path");
    } catch (e) {
      print("Error cargando modelo: $e");
      _isReady = false;
      rethrow; // Propagate error to UI
    }
  }

  bool get isReady => _isReady;

  Future<List<double>?> runInference(CameraImage cameraImage) async {
    if (!_isReady || _session == null) return null;

    // 1. Preprocesamiento: YUV420 -> Float32 [1, 3, 512, 512]
    // NOTA: Esto es LENTO en Dart puro. Se incluye solo para demo.
    // En producción usar Isolate + FFI C++ o Compute Shader.
    final inputFloats = _cameraImageToFloat32List(cameraImage);
    
    // Crear tensor de entrada (Batch=1, Ch=3, H=512, W=512)
    final inputOrt = OrtValueTensor.createTensorWithDataList(
      inputFloats, 
      [1, 3, 512, 512]
    );

    final runOptions = OrtRunOptions();
    final inputs = {'input': inputOrt}; 
    
    try {
      // 2. Inferencia ONNX
      final outputs = await _session!.runAsync(runOptions, inputs);
      
      // 3. Postprocesamiento (Obtener máscara)
      // La salida es [1, 1, 512, 512] float (mapa de calor)
      final outputTensor = outputs?[0];
      if (outputTensor == null) return null;
      final outputData = outputTensor.value as List<List<List<List<double>>>>;
      
      inputOrt.release();
      runOptions.release();
      // outputTensor.release(); // Cuidado con liberar si usamos datos
      
      // Retornar solo la lista plana de la máscara para dibujar
      // Simplificación: retornamos primera fila
      return outputData[0][0].expand((i) => i).toList(); 
      
    } catch (e) {
      print("Error Inferencia: $e");
      return null;
    }
  }

  // Conversión LENTA (Solo prototipo) - Asume imagen 512x512
  List<double> _cameraImageToFloat32List(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final uvRowStride = image.planes[1].bytesPerRow;
    final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    // Buffer plano RGB planar [R, G, B]
    var floats = List<double>.filled(1 * 3 * 512 * 512, 0.0);
    
    // Recorrer y convertir solo zona central 512x512 (Crop)
    // ... Implementación simplificada ...
    return floats; 
  }
}
