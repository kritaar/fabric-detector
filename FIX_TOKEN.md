# Error al Subir a GitHub - Solución

## Problema
El token no tiene permiso `workflow` necesario para GitHub Actions.

## Opción A: Actualizar Token (Recomendada)

1. Ve a: https://github.com/settings/tokens
2. Click en tu token `ghp_mvq3...`
3. Marca checkbox **`workflow`** (además de `repo`)
4. Click "Update token" (abajo)
5. Ejecuta:
   ```bash
   git push -u origin main
   ```

## Opción B: Subir Sin Workflow (Temporal)

```bash
# Mover archivo de GitHub Actions temporalmente
mv .github/workflows/build.yml ../build.yml.backup

# Subir código
git add .
git commit -m "Update: removed workflow temporarily"
git push -u origin main

# Restaurar workflow después
mv ../build.yml.backup .github/workflows/build.yml
```

Luego actualizas el token y haces otro push.

---

**Recomendación**: Opción A es más simple. Solo toma 1 minuto.
