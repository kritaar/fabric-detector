import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

// Variables globales para acceso rápido (simple state management)
List<CameraDescription> cameras = [];
String? selectedModelPath;
ValueNotifier<double> sensitivity = ValueNotifier(0.5); // 0.0 - 1.0
