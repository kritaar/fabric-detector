import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:camera/camera.dart';

enum _Backend { onnx, tflite }

class InferenceService {
  OrtSession? _onnxSession;
  Interpreter? _tfliteInterpreter;

  _Backend _backend = _Backend.onnx;
  bool _isReady = false;
  bool _npuActive = false;
  int? detectedResolution;

  Function(String)? onLog;

  bool get isReady => _isReady;
  bool get npuActive => _npuActive;

  // ── Carga ─────────────────────────────────────────────────────────────────

  Future<void> loadModel(String path, {bool useNpu = false}) async {
    _isReady = false;
    _npuActive = false;
    detectedResolution = null;
    _onnxSession?.release();
    _tfliteInterpreter?.close();

    _backend = path.endsWith('.tflite') ? _Backend.tflite : _Backend.onnx;
    if (_backend == _Backend.tflite) {
      await _loadTflite(path);
    } else {
      await _loadOnnx(path, useNpu: useNpu);
    }
  }

  Future<void> _loadTflite(String path) async {
    try {
      final options = InterpreterOptions()..threads = 4;
      _tfliteInterpreter = Interpreter.fromFile(File(path), options: options);
      _tfliteInterpreter!.allocateTensors();

      final inTensor  = _tfliteInterpreter!.getInputTensor(0);
      final outTensor = _tfliteInterpreter!.getOutputTensor(0);

      // NHWC: [1, H, W, 3] → H es la resolución
      if (inTensor.shape.length >= 3) {
        detectedResolution = inTensor.shape[1];
      }

      _isReady = true;
      _log("TFLite OK → entrada: ${inTensor.shape} (${inTensor.type})"
          "  salida: ${outTensor.shape} (${outTensor.type})");
      _log("Resolución detectada: ${detectedResolution}px");
    } catch (e) {
      _log("Error cargando TFLite: $e");
      _isReady = false;
      rethrow;
    }
  }

  Future<void> _loadOnnx(String path, {bool useNpu = false}) async {
    try {
      final opts = OrtSessionOptions();
      if (useNpu) {
        try {
          (opts as dynamic).appendExecutionProvider_Nnapi(0);
          _npuActive = true;
          _log("✓ NNAPI activado");
        } catch (_) {
          _log("NNAPI no disponible → CPU");
        }
      }
      _onnxSession = OrtSession.fromFile(File(path), opts);
      _isReady = true;
      _log("ONNX OK: $path");
    } catch (e) {
      _log("Error cargando ONNX: $e");
      _isReady = false;
      rethrow;
    }
  }

  // ── Inferencia ─────────────────────────────────────────────────────────────

  Future<List<double>?> runInference(CameraImage image,
      {int resolution = 256}) async {
    if (!_isReady) return null;

    final yuvData = YUVData.fromCameraImage(image);
    if (yuvData == null) return null;

    final effectiveRes = detectedResolution ?? resolution;

    if (_backend == _Backend.tflite) {
      return _runTflite(yuvData, effectiveRes);
    } else {
      return _runOnnx(yuvData, effectiveRes);
    }
  }

  Future<List<double>?> _runTflite(YUVData yuvData, int res) async {
    if (_tfliteInterpreter == null) return null;

    final inputFloats = await compute(
      _convertYuvIsolate,
      InferenceParams(yuv: yuvData, resolution: res, nhwc: true),
    );

    try {
      final inTensor  = _tfliteInterpreter!.getInputTensor(0);
      final outTensor = _tfliteInterpreter!.getOutputTensor(0);

      // ── Escribir entrada según tipo del tensor ──────────────────────────
      switch (inTensor.type) {
        case TensorType.float32:
          final bytes = Float32List.fromList(inputFloats).buffer.asUint8List();
          inTensor.data.setRange(0, bytes.length, bytes);
          break;
        case TensorType.uint8:
          final p = _quantParams(inTensor);
          final buf = Uint8List(inputFloats.length);
          for (int i = 0; i < inputFloats.length; i++) {
            buf[i] = (inputFloats[i] / p.$1 + p.$2).round().clamp(0, 255);
          }
          inTensor.data.setRange(0, buf.length, buf);
          break;
        case TensorType.int8:
          final p = _quantParams(inTensor);
          final buf = Int8List(inputFloats.length);
          for (int i = 0; i < inputFloats.length; i++) {
            buf[i] = (inputFloats[i] / p.$1 + p.$2).round().clamp(-128, 127);
          }
          inTensor.data.setRange(0, buf.buffer.asUint8List().length,
              buf.buffer.asUint8List());
          break;
        default:
          _log("Tipo de entrada no soportado: ${inTensor.type}");
          return null;
      }

      _tfliteInterpreter!.invoke();

      // ── Leer salida según tipo del tensor ───────────────────────────────
      switch (outTensor.type) {
        case TensorType.float32:
          // Modelo float32 → salida son logits → aplicar sigmoid
          return outTensor.data.buffer
              .asFloat32List()
              .map((v) => 1.0 / (1.0 + exp(-v)))
              .toList();
        case TensorType.uint8:
          final p = _quantParams(outTensor);
          return outTensor.data.buffer
              .asUint8List()
              .map((q) => ((q - p.$2) * p.$1).clamp(0.0, 1.0))
              .toList();
        case TensorType.int8:
          final p = _quantParams(outTensor);
          return outTensor.data.buffer
              .asInt8List()
              .map((q) => ((q - p.$2) * p.$1).clamp(0.0, 1.0))
              .toList();
        default:
          _log("Tipo de salida no soportado: ${outTensor.type}");
          return null;
      }
    } catch (e) {
      _log("Error TFLite inferencia: $e");
      return null;
    }
  }

  /// Devuelve (scale, zeroPoint) con fallback seguro si el modelo no tiene params.
  (double, int) _quantParams(Tensor tensor) {
    try {
      return (tensor.params.scale, tensor.params.zeroPoint);
    } catch (_) {
      return (1.0 / 255.0, 0);
    }
  }

  Future<List<double>?> _runOnnx(YUVData yuvData, int resolution) async {
    if (_onnxSession == null) return null;

    final inputFloats = await compute(
      _convertYuvIsolate,
      InferenceParams(yuv: yuvData, resolution: resolution, nhwc: false),
    );

    final inputOrt = OrtValueTensor.createTensorWithDataList(
        inputFloats, [1, 3, resolution, resolution]);
    final runOptions = OrtRunOptions();

    try {
      final outputs =
          await _onnxSession!.runAsync(runOptions, {'input': inputOrt});
      final outTensor = outputs?[0];
      if (outTensor == null) return null;

      final data = outTensor.value as List<List<List<List<double>>>>;
      inputOrt.release();
      runOptions.release();
      return data[0][0].expand((row) => row).toList();
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
  final bool nhwc;
  const InferenceParams(
      {required this.yuv, required this.resolution, this.nhwc = false});
}

class YUVData {
  final int width;   // sensor width (landscape), e.g. 1280
  final int height;  // sensor height (landscape), e.g. 720
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

  static YUVData? fromCameraImage(CameraImage image) {
    if (image.planes.isEmpty || image.width < 64 || image.height < 64) {
      return null;
    }
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

// ── Conversión YUV → RGB con corrección de rotación y escala completa ─────────
//
// El sensor Android entrega frames en landscape (width × height, p.ej. 1280×720).
// El CameraPreview rota 90°CW para mostrar portrait.  Nosotros reproducimos
// esa misma transformación para que el heatmap coincida pixel a pixel con la vista.
//
// Transformación portrait→sensor (sensorOrientation=90° CW, back camera):
//   sensor_x = portrait_row
//   sensor_y = sensorH - 1 - portrait_col
//
// Además, en lugar de center-crop fijo, escalamos el encuadre completo de la
// cámara (squareSize × squareSize en portrait) al tamaño del modelo (res × res).
// squareSize = sensorH = portrait_W (el lado corto del portrait).
// El recorte vertical en portrait se centra: portrait_row ∈ [rowOffset, rowOffset+squareSize).

List<double> _convertYuvIsolate(InferenceParams params) {
  final int res  = params.resolution;
  final YUVData d = params.yuv;

  final int sensorW = d.width;   // 1280
  final int sensorH = d.height;  // 720

  // Tamaño del cuadrado en portrait (portrait_W = sensorH)
  final int squareSize  = sensorH;
  // Offset en portrait_row para centrar el crop vertical
  final int rowOffset   = (sensorW - squareSize) ~/ 2;

  final floats = List<double>.filled(3 * res * res, 0.0);

  for (int oy = 0; oy < res; oy++) {
    for (int ox = 0; ox < res; ox++) {
      // Mapear pixel de salida (ox,oy) al cuadrado portrait
      final double pCol = ox * squareSize / res;          // portrait col [0..squareSize)
      final double pRow = oy * squareSize / res + rowOffset; // portrait row + offset

      // Transformar portrait→sensor (rotación 90°CW del sensor)
      final int imgX = pRow.toInt().clamp(0, sensorW - 1);          // sensor col
      final int imgY = (sensorH - 1 - pCol.toInt()).clamp(0, sensorH - 1); // sensor row

      // Leer YUV
      final int yp  = d.planeY[imgY * d.yRowStride + imgX];
      final int uvIdx = (imgY >> 1) * d.uvRowStride + (imgX >> 1) * d.uvPixelStride;
      final int up  = d.planeU[uvIdx];
      final int vp  = d.planeV[uvIdx];

      // BT.601 YUV → RGB normalizado [0,1]
      final double rf = (yp + 1.402   * (vp - 128)).clamp(0, 255) / 255.0;
      final double gf = (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128))
                            .clamp(0, 255) / 255.0;
      final double bf = (yp + 1.772   * (up - 128)).clamp(0, 255) / 255.0;

      if (params.nhwc) {
        floats[oy * res * 3 + ox * 3    ] = rf;
        floats[oy * res * 3 + ox * 3 + 1] = gf;
        floats[oy * res * 3 + ox * 3 + 2] = bf;
      } else {
        floats[            oy * res + ox] = rf;
        floats[res * res + oy * res + ox] = gf;
        floats[2 * res * res + oy * res + ox] = bf;
      }
    }
  }
  return floats;
}
