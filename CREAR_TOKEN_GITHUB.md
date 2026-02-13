# Crear Personal Access Token de GitHub

Como inicias sesión con Google, necesitas un token para usar Git desde la terminal.

## Pasos:

1. **Ve a**: https://github.com/settings/tokens/new

2. **Configura el token**:
   - **Note**: "Fabric Detector App"
   - **Expiration**: 90 days (o más si quieres)
   - **Select scopes**: Marca SOLO estas casillas:
     - ✅ `repo` (acceso completo a repositorios)
     - ✅ `workflow` (para GitHub Actions)

3. **Haz clic en "Generate token"** (abajo de la página)

4. **COPIA EL TOKEN** (empieza con `ghp_...`)
   ⚠️ **MUY IMPORTANTE**: Guárdalo en un lugar seguro
   Solo se muestra UNA VEZ. Si lo pierdes, deberás crear uno nuevo.

5. **Usa el token como contraseña** cuando Git lo pida:
   - Username: `kritaar`
   - Password: `ghp_tu_token_aquí` (pega el token)

---

## Alternativa más fácil: GitHub CLI

Si no quieres crear token, puedo configurar GitHub CLI:

```bash
sudo snap install gh
gh auth login
```

Elige: GitHub.com → HTTPS → Authenticate with browser

Esto abre el navegador donde inicias sesión con Google, ¡sin necesidad de token!

---

¿Prefieres:
A) Crear el token manualmente
B) Usar GitHub CLI (más fácil)
