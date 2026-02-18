import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:camera/camera.dart';

class InferenceService {
  OrtSession? _session;
  bool _isReady = false;
  Function(String)? onLog; // Callback para logs en pantalla

  Future<void> loadModel(String path) async {
    _isReady = false;
    _session?.release();
    try {
      final sessionOptions = OrtSessionOptions();
      // ACTIVAR NNAPI (NPU) PARA POCO X6 PRO
      try {
        sessionOptions.addDelegate(OrtEnv.instance.createNnapiDelegate());
        _log("NNAPI Delegate activado (NPU).");
      } catch (e) {
        _log("Error activando NNAPI: $e. Usando CPU.");
      }

      _session = OrtSession.fromFile(File(path), sessionOptions);
      _isReady = true;
      _log("Modelo cargado OK: $path");
    } catch (e) {
      _log("Error cargando modelo: $e");
      _isReady = false;
      rethrow; 
    }
  }

  bool get isReady => _isReady;

  void _log(String msg) {
    if (onLog != null) {
      onLog!(msg);
    } else {
      print(msg);
    }
  }

  Future<List<double>?> runInference(CameraImage cameraImage) async {
    if (!_isReady || _session == null) return null;

    // 1. Extraer datos para el Isolate 
    final yuvData = YUVData.fromCameraImage(cameraImage);
    if (yuvData == null) {
       // _log("Error: Imagen vacía (<512px)"); // Demasiado spam si falla continuo
       return null;
    }

    // 2. Preprocesamiento en SEGUNDO PLANO (Isolate)
    // _log("[YUV] Start Compute..."); 
    final List<double> inputFloats;
    try {
      inputFloats = await compute(_convertYuvIsolate, yuvData);
      // _log("[YUV] End Compute. Size: ${inputFloats.length}");
    } catch (e) {
      _log("Error YUV Compute: $e");
      return null;
    }
    
    // 3. Crear tensor
    final inputOrt = OrtValueTensor.createTensorWithDataList(inputFloats, [1, 3, 512, 512]);
    final runOptions = OrtRunOptions();
    final inputs = {'input': inputOrt}; 
    
    try {
      // 4. Inferencia ONNX 
      // _log("[ORT] Start RunAsync...");
      final outputs = await _session!.runAsync(runOptions, inputs);
      // _log("[ORT] End RunAsync. Output valid: ${outputs?.isNotEmpty}");
      
      final outputTensor = outputs?[0];
      if (outputTensor == null) return null;
      final outputData = outputTensor.value as List<List<List<List<double>>>>;
      
      inputOrt.release();
      runOptions.release();
      
      return outputData[0][0].expand((i) => i).toList(); 
      
    } catch (e) {
      _log("Error Inferencia: $e");
      return null;
    }
  }
}

// Clase DTO para pasar datos al Isolate
class YUVData {
  final int width;
  final int height;
  final Uint8List planeY;
  final Uint8List planeU;
  final Uint8List planeV;
  final int yRowStride;
  final int uvRowStride;
  final int uvPixelStride;

  YUVData({
    required this.width,
    required this.height,
    required this.planeY,
    required this.planeU,
    required this.planeV,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
  });

  static YUVData? fromCameraImage(CameraImage image) {
    if (image.planes.isEmpty) return null;
    if (image.width < 512 || image.height < 512) return null;

    return YUVData(
      width: image.width,
      height: image.height,
      planeY: image.planes[0].bytes,
      planeU: image.planes[1].bytes,
      planeV: image.planes[2].bytes,
      yRowStride: image.planes[0].bytesPerRow,
      uvRowStride: image.planes[1].bytesPerRow,
      uvPixelStride: image.planes[1].bytesPerPixel ?? 1,
    );
  }
}

// Función Top-Level para compute()
List<double> _convertYuvIsolate(YUVData data) {
  // Buffer plano [1, 3, 512, 512] -> planar order RRR...GGG...BBB...
  final floats = List<double>.filled(3 * 512 * 512, 0.0);

  // Calcular offset para center crop
  final int startX = (data.width - 512) ~/ 2;
  final int startY = (data.height - 512) ~/ 2;

  // Recorrer 512x512
  for (int y = 0; y < 512; y++) {
    for (int x = 0; x < 512; x++) {
      // Coordenadas en imagen original
      final int imgX = startX + x;
      final int imgY = startY + y;
      
      // Índice Y
      final int indexY = imgY * data.yRowStride + imgX;
      final int yp = data.planeY[indexY];

      // Índice UV (submuestreado 2x2)
      final int uvIndex = (imgY >> 1) * data.uvRowStride + (imgX >> 1) * data.uvPixelStride;
      final int up = data.planeU[uvIndex];
      final int vp = data.planeV[uvIndex];

      // YUV a RGB
      int r = (yp + 1.402 * (vp - 128)).toInt();
      int g = (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128)).toInt();
      int b = (yp + 1.772 * (up - 128)).toInt();

      // Clamp y Normalizar
      final double rf = r.clamp(0, 255) / 255.0;
      final double gf = g.clamp(0, 255) / 255.0;
      final double bf = b.clamp(0, 255) / 255.0;

      // Escribir en buffer planar (CHW)
      floats[y * 512 + x] = rf;
      floats[262144 + y * 512 + x] = gf; // 262144 = 512*512
      floats[524288 + y * 512 + x] = bf; // 524288 = 2*512*512
    }
  }
  return floats;
}
