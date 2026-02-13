# Guía Rápida: Subir a GitHub y Obtener APK

## Paso 1: Crear Repositorio en GitHub

1. Ve a https://github.com/new
2. Nombre: `fabric-detector` (o el que prefieras)
3. **NO** marques "Initialize with README"
4. Haz clic en "Create repository"

## Paso 2: Subir Proyecto

Abre una terminal en `/home/n0la/Escritorio/new_margin/fabric_detector_app` y ejecuta:

```bash
cd /home/n0la/Escritorio/new_margin/fabric_detector_app

# Inicializar Git
git init

# Agregar archivos
git add .

# Primer commit
git commit -m "Initial commit: Flutter fabric detector app"

# Conectar con GitHub (REEMPLAZA con tu usuario y repo)
git remote add origin https://github.com/TU_USUARIO/fabric-detector.git

# Configurar rama principal
git branch -M main

# Subir a GitHub
git push -u origin main
```

## Paso 3: Esperar Compilación Automática

1. Ve a tu repositorio en GitHub
2. Click en la pestaña **"Actions"**
3. Verás un workflow corriendo: "Build Android APK"
4. Espera ~10-15 minutos (primera vez tarda más)
5. Cuando termine (✓ verde), haz clic en el workflow

## Paso 4: Descargar APK

1. En la página del workflow, baja hasta **"Artifacts"**
2. Haz clic en **"fabric-detector-apk"**
3. Se descarga un ZIP
4. Descomprime → `app-release.apk`

## Paso 5: Instalar en Celular

**Opción A: Cable USB**
```bash
adb install app-release.apk
```

**Opción B: Transferir archivo**
1. Copia el APK al celular (cable/email/Drive)
2. Abre el archivo en el celular
3. Habilita "Instalar apps desconocidas" si pregunta
4. Instalar

---

## Si Algo Falla

### Error: "Build failed"
- Ve a Actions → Click en el workflow fallido
- Lee los errores en rojo
- Usualmente es por dependencias

### Error: Git push rechazado
```bash
git pull origin main --allow-unrelated-histories
git push -u origin main
```

### Error: No se genera APK
- Verifica que `.github/workflows/build.yml` existe
- Verifica que el archivo tiene la configuración correcta

---

## Actualizar App Después

Cuando hagas cambios:

```bash
cd /home/n0la/Escritorio/new_margin/fabric_detector_app
git add .
git commit -m "Descripción de cambios"
git push
```

GitHub vuelve a compilar automáticamente.

---

## Notas Importantes

⚠️ **Modelo TFLite faltante**: El APK compilará pero no funcionará hasta que:
1. Conviertas el ONNX a TFLite
2. Lo coloques en `assets/models/model_general.tflite`
3. Hagas push de nuevo

Ver: `assets/models/README.md` para instrucciones de conversión.
