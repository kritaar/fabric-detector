import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:camera/camera.dart';

/// Detecta el backend según la extensión del archivo.
enum _Backend { onnx, tflite }

class InferenceService {
  // ONNX Runtime
  OrtSession? _onnxSession;

  // TFLite
  Interpreter? _tfliteInterpreter;

  _Backend _backend = _Backend.onnx;
  bool _isReady = false;
  bool _npuActive = false;

  Function(String)? onLog;

  bool get isReady => _isReady;
  bool get npuActive => _npuActive;

  // ── Carga del modelo ───────────────────────────────────────────────────────

  Future<void> loadModel(String path, {bool useNpu = false}) async {
    _isReady = false;
    _npuActive = false;
    _onnxSession?.release();
    _tfliteInterpreter?.close();

    _backend = path.endsWith('.tflite') ? _Backend.tflite : _Backend.onnx;

    if (_backend == _Backend.tflite) {
      await _loadTflite(path, useNpu: useNpu);
    } else {
      await _loadOnnx(path, useNpu: useNpu);
    }
  }

  Future<void> _loadTflite(String path, {bool useNpu = false}) async {
    try {
      final options = InterpreterOptions()..threads = 4;

      if (useNpu) {
        try {
          // NnApiDelegate no está en la API pública de tflite_flutter 0.10.x.
          // GpuDelegateV2 usa el Mali-G615 del Dimensity 8300 Ultra.
          options.addDelegate(GpuDelegateV2());
          _npuActive = true;
          _log("✓ GPU Delegate activado — Mali-G615 (Dimensity 8300 Ultra)");
        } catch (e) {
          _log("✗ GPU Delegate no disponible: $e → CPU");
        }
      } else {
        _log("Modo CPU (4 hilos)");
      }

      _tfliteInterpreter = Interpreter.fromFile(File(path), options: options);
      _tfliteInterpreter!.allocateTensors();

      final inShape = _tfliteInterpreter!.getInputTensor(0).shape;
      final outShape = _tfliteInterpreter!.getOutputTensor(0).shape;
      _isReady = true;
      _log("TFLite cargado OK → entrada: $inShape  salida: $outShape");
      _log("Dispositivo: ${_npuActive ? 'NPU (NNAPI)' : 'CPU'}");
    } catch (e) {
      _log("Error cargando TFLite: $e");
      _isReady = false;
      rethrow;
    }
  }

  Future<void> _loadOnnx(String path, {bool useNpu = false}) async {
    try {
      final sessionOptions = OrtSessionOptions();

      if (useNpu) {
        try {
          (sessionOptions as dynamic).appendExecutionProvider_Nnapi(0);
          _npuActive = true;
          _log("✓ NNAPI activado (ONNX Runtime)");
        } catch (_) {
          try {
            (sessionOptions as dynamic).appendExecutionProvider('nnapi');
            _npuActive = true;
            _log("✓ NNAPI activado (ORT v2 API)");
          } catch (e2) {
            _log("✗ NNAPI no disponible: $e2 → CPU");
          }
        }
      } else {
        _log("Modo CPU seleccionado");
      }

      _onnxSession = OrtSession.fromFile(File(path), sessionOptions);
      _isReady = true;
      _log("ONNX cargado OK: $path");
    } catch (e) {
      _log("Error cargando ONNX: $e");
      _isReady = false;
      rethrow;
    }
  }

  // ── Inferencia ─────────────────────────────────────────────────────────────

  Future<List<double>?> runInference(CameraImage image, {int resolution = 256}) async {
    if (!_isReady) return null;

    final yuvData = YUVData.fromCameraImage(image, resolution);
    if (yuvData == null) return null;

    if (_backend == _Backend.tflite) {
      return _runTflite(yuvData, resolution);
    } else {
      return _runOnnx(yuvData, resolution);
    }
  }

  Future<List<double>?> _runTflite(YUVData yuvData, int resolution) async {
    if (_tfliteInterpreter == null) return null;

    // Preprocesar en isolate → NHWC [1, H, W, 3]
    final inputFloats = await compute(
      _convertYuvIsolate,
      InferenceParams(yuv: yuvData, resolution: resolution, nhwc: true),
    );

    final inputData = Float32List.fromList(inputFloats);
    final outputData = Float32List(resolution * resolution); // [1, H, W, 1] aplanado

    try {
      _tfliteInterpreter!.run(inputData, outputData);
      // Aplicar sigmoid → valores [0, 1]
      return outputData.map((v) => 1.0 / (1.0 + exp(-v))).toList();
    } catch (e) {
      _log("Error TFLite inferencia: $e");
      return null;
    }
  }

  Future<List<double>?> _runOnnx(YUVData yuvData, int resolution) async {
    if (_onnxSession == null) return null;

    // Preprocesar en isolate → NCHW [1, 3, H, W]
    final inputFloats = await compute(
      _convertYuvIsolate,
      InferenceParams(yuv: yuvData, resolution: resolution, nhwc: false),
    );

    final inputOrt = OrtValueTensor.createTensorWithDataList(
      inputFloats,
      [1, 3, resolution, resolution],
    );
    final runOptions = OrtRunOptions();
    final inputs = {'input': inputOrt};

    try {
      final outputs = await _onnxSession!.runAsync(runOptions, inputs);
      final outputTensor = outputs?[0];
      if (outputTensor == null) return null;

      final outputData = outputTensor.value as List<List<List<List<double>>>>;
      inputOrt.release();
      runOptions.release();

      return outputData[0][0].expand((row) => row).toList();
    } catch (e) {
      _log("Error ONNX inferencia: $e");
      return null;
    }
  }

  void _log(String msg) => onLog != null ? onLog!(msg) : print(msg);

  void dispose() {
    _onnxSession?.release();
    _tfliteInterpreter?.close();
    _isReady = false;
  }
}

// ── Clases de datos para el Isolate ──────────────────────────────────────────

class InferenceParams {
  final YUVData yuv;
  final int resolution;
  final bool nhwc; // true → TFLite [1,H,W,3], false → ONNX [1,3,H,W]
  const InferenceParams({
    required this.yuv,
    required this.resolution,
    this.nhwc = false,
  });
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

// ── Función top-level para compute() ─────────────────────────────────────────

List<double> _convertYuvIsolate(InferenceParams params) {
  final int res = params.resolution;
  final YUVData d = params.yuv;

  final int startX = (d.width - res) ~/ 2;
  final int startY = (d.height - res) ~/ 2;

  final floats = List<double>.filled(3 * res * res, 0.0);

  for (int y = 0; y < res; y++) {
    for (int x = 0; x < res; x++) {
      final int imgX = startX + x;
      final int imgY = startY + y;

      final int indexY = imgY * d.yRowStride + imgX;
      final int yp = d.planeY[indexY];

      final int uvIdx =
          (imgY >> 1) * d.uvRowStride + (imgX >> 1) * d.uvPixelStride;
      final int up = d.planeU[uvIdx];
      final int vp = d.planeV[uvIdx];

      // BT.601 YUV → RGB
      final double rf = (yp + 1.402 * (vp - 128)).clamp(0, 255) / 255.0;
      final double gf = (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128))
              .clamp(0, 255) /
          255.0;
      final double bf = (yp + 1.772 * (up - 128)).clamp(0, 255) / 255.0;

      if (params.nhwc) {
        // NHWC: [y, x, c] → índice = y*res*3 + x*3 + c
        floats[y * res * 3 + x * 3 + 0] = rf;
        floats[y * res * 3 + x * 3 + 1] = gf;
        floats[y * res * 3 + x * 3 + 2] = bf;
      } else {
        // NCHW: [c, y, x] → índice = c*res*res + y*res + x
        floats[0 * res * res + y * res + x] = rf;
        floats[1 * res * res + y * res + x] = gf;
        floats[2 * res * res + y * res + x] = bf;
      }
    }
  }
  return floats;
}
