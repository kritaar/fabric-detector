# Fabric Detector App (Mobile)

Aplicación móvil para la detección de defectos en telas utilizando modelos ONNX cuantizados (Int8).

## Características
- **Inferencia en Tiempo Real:** Usa la NPU/GPU del móvil mediante ONNX Runtime.
- **Selector de Cartuchos:** Carga tus propios modelos `.onnx` desde el almacenamiento.
- **Resolución Adaptativa:** Ajusta la calidad de la cámara para maximizar FPS.

## Instalación

### Opción A: Descargar APK (Automático)
Si has subido esto a GitHub, ve a la pestaña "Actions", entra en el último workflow exitoso y descarga `app-release.apk`.

### Opción B: Compilar manual
1. Instala Flutter SDK.
2. Ejecuta:
```bash
flutter pub get
flutter run --release
```

## Uso
1. Copia tus modelos `student_model_int8.onnx` al móvil.
2. Abre la app -> Icono Carpeta -> Selecciona el modelo.
3. Apunta a la tela. ¡Listo!
