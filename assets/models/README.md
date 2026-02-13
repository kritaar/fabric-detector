# NOTA IMPORTANTE: Modelos Faltantes

Los modelos TFLite no están incluidos porque la conversión ONNX → TFLite
es compleja para modelos UNet.

## Solución Temporal

Para compilar el APK ahora, se crearon modelos placeholder vacíos.
La app compilará pero NO funcionará hasta que agregues modelos reales.

## Cómo Agregar Modelos Reales

### Opción 1: Convertir ONNX → TFLite (Recomendada)

Usa `ai_edge_torch` (Google):

```bash
pip install ai-edge-torch
python convert_onnx_to_tflite_v2.py
```

### Opción 2: Re-entrenar Directamente a TFLite

Modifica `train.py` para exportar a TFLite en lugar de ONNX:

```python
import tensorflow as tf

# Después de entrenar
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
tflite_model = converter.convert()

with open('model.tflite', 'wb') as f:
    f.write(tflite_model)
```

### Opción 3: Usar ONNX Runtime Mobile (Alternativa)

Si la conversión es muy difícil, usa el modelo ONNX directamente con
un plugin Flutter personalizado o cambia a una web app progresiva (PWA).

## Archivos a Reemplazar

Una vez tengas modelo TFLite:

1. Copia a `assets/models/model_general.tflite`
2. Opcional: `model_algod.tflite`, `model_polyester.tflite`
3. Recompila: `flutter build apk --release`
