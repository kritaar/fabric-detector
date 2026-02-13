# Cómo Compilar el APK - 3 Opciones

El proyecto Flutter está completamente listo. Solo necesitas generar el APK.

## Opción 1: GitHub Actions (RECOMENDADA - Sin Instalación)

**No necesitas instalar nada más**. GitHub compila por ti:

### Pasos:
1. Crear repo en GitHub
2. Subir proyecto
3. GitHub Actions automáticamente compila
4. Descargar APK desde Actions → Artifacts

### Comandos:
```bash
cd /home/n0la/Escritorio/new_margin/fabric_detector_app
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/TU_USUARIO/fabric-detector.git
git push -u origin main
```

**Resultado**: APK listo en ~10 minutos

---

## Opción 2: Instalar Android SDK (Local - Más Control)

### Requisitos:
- Android Studio (incluye SDK)
- ~8GB de espacio

### Pasos:
```bash
# 1. Instalar Android Studio
sudo snap install android-studio --classic

# 2. Abrir Android Studio
android-studio

# 3. En el wizard inicial:
#    - Install type: Standard
#    - Descargar Android SDK

# 4. Configurar variables de entorno
echo 'export ANDROID_HOME=$HOME/Android/Sdk' >> ~/.bashrc
echo 'export PATH=$PATH:$ANDROID_HOME/tools/bin' >> ~/.bashrc
echo 'export PATH=$PATH:$ANDROID_HOME/platform-tools' >> ~/.bashrc
source ~/.bashrc

# 5. Aceptar licencias
flutter doctor --android-licenses

# 6. Compilar APK
cd /home/n0la/Escritorio/new_margin/fabric_detector_app
flutter build apk --release
```

**Resultado**: APK en `build/app/outputs/flutter-apk/app-release.apk`

---

## Opción 3: Usar Web App (Evitar APK)

Si la compilación APK es muy complicada, sigue usando la web actual:

### Ventajas:
- Ya funciona (`https://ca3a4090b28a12e614.gradio.live`)
- No requiere instalación
- Funciona en cualquier dispositivo

### Convertir a PWA (Instalable):
Puedo convertir el inspector web actual en una Progressive Web App que se "instala" como app nativa sin necesitar Google Play.

---

## Mi Recomendación

**Para tesis rápida**: Opción 1 (GitHub Actions)  
**Para producción**: Opción 2 (Android SDK)  
**Para demostración**: Opción 3 (Web PWA)

---

## Estado Actual del Proyecto

✅ **Código Flutter**: 100% completo  
✅ **Dependencias**: Instaladas  
✅ **Estructura Android**: Configurada  
✅ **Selector multi-modelo**: Implementado  
✅ **Cámara + Galería**: Ready  

⚠️ **Falta**:
- Android SDK (para build local)
- Modelos TFLite (conversión ONNX → TFLite)

¿Con cuál opción quieres continuar?
