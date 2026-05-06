import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:camera/camera.dart';

class InferenceService {
  OrtSession? _session;
  bool _isReady = false;
  bool _npuActive = false;
  Function(String)? onLog;

  bool get isReady => _isReady;
  bool get npuActive => _npuActive;

  Future<void> loadModel(String path, {bool useNpu = false}) async {
    _isReady = false;
    _npuActive = false;
    _session?.release();

    try {
      final sessionOptions = OrtSessionOptions();

      if (useNpu) {
        try {
          // Intentar activar NNAPI para MediaTek APU 790.
          // Lanza NoSuchMethodError en versiones que no lo soportan → catch.
          (sessionOptions as dynamic).appendExecutionProvider_Nnapi(0);
          _npuActive = true;
          _log("✓ NNAPI activado — delegando al NPU MediaTek APU");
        } catch (_) {
          try {
            // Fallback: API alternativa según versión del paquete
            (sessionOptions as dynamic).appendExecutionProvider('nnapi');
            _npuActive = true;
            _log("✓ NNAPI activado (API v2)");
          } catch (e2) {
            _npuActive = false;
            _log("✗ NNAPI no disponible en esta versión de onnxruntime: $e2");
            _log("  → Ejecutando en CPU");
          }
        }
      } else {
        _log("Modo CPU seleccionado");
      }

      _session = OrtSession.fromFile(File(path), sessionOptions);
      _isReady = true;
      _log("Modelo cargado OK: $path");
      _log("Dispositivo: ${_npuActive ? 'NPU (NNAPI)' : 'CPU'}");
    } catch (e) {
      _log("Error cargando modelo: $e");
      _isReady = false;
      rethrow;
    }
  }

  void _log(String msg) {
    if (onLog != null) {
      onLog!(msg);
    } else {
      print(msg);
    }
  }

  Future<List<double>?> runInference(CameraImage cameraImage, {int resolution = 256}) async {
    if (!_isReady || _session == null) return null;

    final yuvData = YUVData.fromCameraImage(cameraImage, resolution);
    if (yuvData == null) return null;

    final List<double> inputFloats;
    try {
      inputFloats = await compute(
        _convertYuvIsolate,
        InferenceParams(yuv: yuvData, resolution: resolution),
      );
    } catch (e) {
      _log("Error preprocesamiento YUV: $e");
      return null;
    }

    final inputOrt = OrtValueTensor.createTensorWithDataList(
      inputFloats,
      [1, 3, resolution, resolution],
    );
    final runOptions = OrtRunOptions();
    final inputs = {'input': inputOrt};

    try {
      final outputs = await _session!.runAsync(runOptions, inputs);
      final outputTensor = outputs?[0];
      if (outputTensor == null) return null;

      final outputData = outputTensor.value as List<List<List<List<double>>>>;
      inputOrt.release();
      runOptions.release();

      return outputData[0][0].expand((row) => row).toList();
    } catch (e) {
      _log("Error inferencia: $e");
      return null;
    }
  }

  void dispose() {
    _session?.release();
    _isReady = false;
  }
}

// ── Clases de datos para el Isolate ─────────────────────────────────────────

class InferenceParams {
  final YUVData yuv;
  final int resolution;
  const InferenceParams({required this.yuv, required this.resolution});
}

class YUVData {
  final int width;
  final int height;
  final Uint8List planeY;
  final Uint8List planeU;
  final Uint8List planeV;
  final int yRowStride;
  final int uvRowStride;
  final int uvPixelStride;

  const YUVData({
    required this.width,
    required this.height,
    required this.planeY,
    required this.planeU,
    required this.planeV,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
  });

  static YUVData? fromCameraImage(CameraImage image, int resolution) {
    if (image.planes.isEmpty) return null;
    // La cámara en ResolutionPreset.high es 720p+, siempre mayor a cualquier resolución
    if (image.width < resolution || image.height < resolution) return null;

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

// ── Función top-level para compute() (corre en Isolate separado) ─────────────

List<double> _convertYuvIsolate(InferenceParams params) {
  final int res = params.resolution;
  final YUVData data = params.yuv;

  // Buffer planar [1, 3, res, res] en orden RRR...GGG...BBB...
  final floats = List<double>.filled(3 * res * res, 0.0);

  // Center-crop desde la imagen de cámara
  final int startX = (data.width - res) ~/ 2;
  final int startY = (data.height - res) ~/ 2;

  for (int y = 0; y < res; y++) {
    for (int x = 0; x < res; x++) {
      final int imgX = startX + x;
      final int imgY = startY + y;

      final int indexY = imgY * data.yRowStride + imgX;
      final int yp = data.planeY[indexY];

      final int uvIndex =
          (imgY >> 1) * data.uvRowStride + (imgX >> 1) * data.uvPixelStride;
      final int up = data.planeU[uvIndex];
      final int vp = data.planeV[uvIndex];

      // YUV → RGB estándar BT.601
      int r = (yp + 1.402 * (vp - 128)).toInt();
      int g = (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128)).toInt();
      int b = (yp + 1.772 * (up - 128)).toInt();

      final double rf = r.clamp(0, 255) / 255.0;
      final double gf = g.clamp(0, 255) / 255.0;
      final double bf = b.clamp(0, 255) / 255.0;

      // Orden planar CHW
      floats[y * res + x] = rf;
      floats[res * res + y * res + x] = gf;
      floats[2 * res * res + y * res + x] = bf;
    }
  }
  return floats;
}
