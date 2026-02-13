#!/bin/bash
# Script para subir el proyecto a GitHub
# Usuario: kritaar

echo "======================================"
echo "Subiendo Fabric Detector a GitHub"
echo "======================================"

# Navegar al proyecto
cd /home/n0la/Escritorio/new_margin/fabric_detector_app

# Inicializar Git
echo "1. Inicializando Git..."
git init

# Configurar usuario (si no está configurado)
git config user.name "kritaar" 2>/dev/null || true
git config user.email "kritaar@users.noreply.github.com" 2>/dev/null || true

# Agregar todos los archivos
echo "2. Agregando archivos..."
git add .

# Commit inicial
echo "3. Creando commit inicial..."
git commit -m "Initial commit: Flutter fabric detector app with multi-model support"

# Conectar con GitHub
echo "4. Conectando con GitHub..."
echo "   Nombre del repo sugerido: fabric-detector"
read -p "   Presiona ENTER para usar 'fabric-detector' o escribe otro nombre: " REPO_NAME
REPO_NAME=${REPO_NAME:-fabric-detector}

git remote add origin https://github.com/kritaar/${REPO_NAME}.git

# Configurar rama principal
echo "5. Configurando rama main..."
git branch -M main

# Subir a GitHub
echo "6. Subiendo a GitHub..."
echo "   Si pide credenciales, usa tu Personal Access Token como password"
git push -u origin main

echo ""
echo "======================================"
echo "✅ Proyecto subido a GitHub!"
echo "======================================"
echo "URL: https://github.com/kritaar/${REPO_NAME}"
echo ""
echo "Ahora ve a: https://github.com/kritaar/${REPO_NAME}/actions"
echo "para ver la compilación automática del APK"
echo "======================================"
