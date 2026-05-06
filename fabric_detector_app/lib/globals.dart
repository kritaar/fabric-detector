import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

List<CameraDescription> cameras = [];
String? selectedModelPath;
ValueNotifier<double> sensitivity = ValueNotifier(0.5);
ValueNotifier<int> selectedResolution = ValueNotifier(256);  // 128 | 256 | 512
ValueNotifier<bool> useNpu = ValueNotifier(false);           // NNAPI (NPU) o CPU
