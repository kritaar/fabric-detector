# Fabric Defect Detector - Flutter App

App Android nativa para detección de defectos en telas usando CNN.

## Características

✅ **Multi-Modelo**: Soporte para múltiples modelos ONNX especializados  
✅ **Cámara en Vivo**: Detección en tiempo real (1-3 FPS)  
✅ **Galería**: Analiza imágenes guardadas  
✅ **Offline**: Funciona sin internet  

## Estructura

```
fabric_detector_app/
├── lib/
│   ├── main.dart              # Punto de entrada
│   ├── screens/
│   │   ├── home_screen.dart   # Selector de modelo + navegación
│   │   └── camera_screen.dart # Cámara en vivo
│   └── services/
│       └── model_service.dart # Carga/inferencia ONNX
├── assets/models/             # Modelos ONNX
│   ├── model_general.onnx     # Modelo general (actual)
│   ├── model_algod.onnx       # TODO: Entrenar para algodón
│   └── model_polyester.onnx   # TODO: Entrenar para poliéster
└── pubspec.yaml               # Dependencias
```

## Cómo Agregar Nuevos Modelos

1. Entrena un modelo especializado para un tipo de tela
2. Exporta a ONNX (`model_tipo_tela.onnx`)
3. Copia a `assets/models/`
4. Edita `home_screen.dart` línea 17, añade:
   ```dart
   {'name': 'Nombre', 'file': 'model_tipo_tela.onnx', 'desc': 'Descripción'},
   ```
5. Edita `pubspec.yaml` línea 36, añade:
   ```yaml
   - assets/models/model_tipo_tela.onnx
   - assets/models/model_tipo_tela.onnx.data
   ```

## Compilar APK (GitHub Actions)

Como no tienes Flutter instalado, usa GitHub Actions:

1. Sube el proyecto a GitHub
2. Crea `.github/workflows/build.yml` (ver archivo adjunto)
3. Push → GitHub compila automáticamente
4. Descarga APK desde "Artifacts"

## Instalar Localmente (Opcional)

```bash
# Instalar Flutter
snap install flutter --classic

# Navegar al proyecto
cd fabric_detector_app

# Generar APK
flutter build apk --release

# APK en: build/app/outputs/flutter-apk/app-release.apk
```

## Próximos Pasos

- [ ] Implementar post-procesamiento (bounding boxes)
- [ ] Agregar overlay de detecciones en cámara
- [ ] Guardar historial de inspecciones
- [ ] Exportar reportes PDF
- [ ] Feedback del usuario (marcar como correcto/error)
