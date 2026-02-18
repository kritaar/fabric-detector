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
      // sessionOptions.addDelegate(OrtEnv.instance.createNnapiDelegate());
      _session = OrtSession.fromFile(File(path), sessionOptions);
      _isReady = true;
      print("Modelo cargado OK: $path");
    } catch (e) {
      print("Error cargando modelo: $e");
      _isReady = false;
      rethrow; 
    }
  }

  bool get isReady => _isReady;

  Future<List<double>?> runInference(CameraImage cameraImage) async {
    if (!_isReady || _session == null) return null;

    // 1. Preprocesamiento: YUV420 -> Float32 [1, 3, 512, 512]
    final inputFloats = _cameraImageToFloat32List(cameraImage);
    
    // Crear tensor de entrada
    final inputOrt = OrtValueTensor.createTensorWithDataList(
      inputFloats, 
      [1, 3, 512, 512]
    );

    final runOptions = OrtRunOptions();
    final inputs = {'input': inputOrt}; 
    
    try {
      // 2. Inferencia ONNX
      final outputs = await _session!.runAsync(runOptions, inputs);
      
      // 3. Postprocesamiento
      final outputTensor = outputs?[0];
      if (outputTensor == null) return null;
      final outputData = outputTensor.value as List<List<List<List<double>>>>;
      
      inputOrt.release();
      runOptions.release();
      
      // Retornar solo la lista plana
      return outputData[0][0].expand((i) => i).toList(); 
      
    } catch (e) {
      print("Error Inferencia: $e");
      return null;
    }
  }

  // Conversión YUV420 -> RGB Float32 (Normalizado 0-1) - Center Crop 512
  List<double> _cameraImageToFloat32List(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    
    // Validar planos
    if (image.planes.isEmpty) return [];
    
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int? uvPixelStride = image.planes[1].bytesPerPixel;

    // Buffer plano [1, 3, 512, 512] -> planar order RRR...GGG...BBB...
    final floats = List<double>.filled(3 * 512 * 512, 0.0);

    // Calcular offset para center crop
    final int startX = (width - 512) ~/ 2;
    final int startY = (height - 512) ~/ 2;

    final Plane planeY = image.planes[0];
    final Plane planeU = image.planes[1];
    final Plane planeV = image.planes[2];

    // Recorrer 512x512
    for (int y = 0; y < 512; y++) {
      for (int x = 0; x < 512; x++) {
        // Coordenadas en imagen original
        final int imgX = startX + x;
        final int imgY = startY + y;
        
        // Evitar desbordamiento por si acaso
        if (imgX >= width || imgY >= height) continue;

        // Índice Y
        final int indexY = imgY * planeY.bytesPerRow + imgX;
        final int yp = planeY.bytes[indexY];

        // Índice UV (submuestreado 2x2)
        final int uvIndex = (imgY >> 1) * uvRowStride + (imgX >> 1) * (uvPixelStride ?? 1);
        final int up = planeU.bytes[uvIndex];
        final int vp = planeV.bytes[uvIndex];

        // YUV a RGB
        int r = (yp + 1.402 * (vp - 128)).toInt();
        int g = (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128)).toInt();
        int b = (yp + 1.772 * (up - 128)).toInt();

        // Clamp y Normalizar
        final double rf = r.clamp(0, 255) / 255.0;
        final double gf = g.clamp(0, 255) / 255.0;
        final double bf = b.clamp(0, 255) / 255.0;

        // Escribir en buffer planar (CHW)
        // R: offset 0
        floats[y * 512 + x] = rf;
        // G: offset 512*512
        floats[262144 + y * 512 + x] = gf; // 262144 = 512*512
        // B: offset 2*512*512
        floats[524288 + y * 512 + x] = bf; // 524288 = 2*512*512
      }
    }
    return floats;
  }
}
