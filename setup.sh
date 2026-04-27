#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

SKIP_LOGIN=0
for arg in "$@"; do
  case "$arg" in
    --skip-login) SKIP_LOGIN=1 ;;
    -h|--help)
      cat <<EOF
Uso: bash setup.sh [--skip-login]

Opciones:
  --skip-login   No ejecuta el login manual de Ripor (útil en CI o reinstalaciones).
EOF
      exit 0
      ;;
    *) echo "⚠️  Argumento desconocido: $arg" >&2 ;;
  esac
done

echo "🐍 Verificando Python..."
PYTHON_CMD="${PYTHON_CMD:-python3}"
if ! command -v "$PYTHON_CMD" >/dev/null 2>&1; then
  echo "❌ ERROR: No se encontró $PYTHON_CMD. Instala Python 3.10+ y vuelve a intentar." >&2
  exit 1
fi

PY_VER="$("$PYTHON_CMD" -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
PY_MAJOR="${PY_VER%.*}"
PY_MINOR="${PY_VER#*.}"
if [ "$PY_MAJOR" -lt 3 ] || { [ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -lt 10 ]; }; then
  echo "❌ ERROR: Se requiere Python 3.10+. Encontrado: $PY_VER" >&2
  exit 1
fi

echo "📦 Creando entorno virtual..."
VENV_DIR="$ROOT/.venv"
if [ ! -d "$VENV_DIR" ]; then
  "$PYTHON_CMD" -m venv "$VENV_DIR"
fi

echo "🔧 Activando entorno y actualizando pip..."
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"
python -m pip install --upgrade pip setuptools wheel

echo "📚 Instalando dependencias..."
if [ -f "skills/registro-horas/requirements.txt" ]; then
  python -m pip install -r skills/registro-horas/requirements.txt
fi
if [ -f "skills/ticket-infra/requirements.txt" ]; then
  python -m pip install -r skills/ticket-infra/requirements.txt
fi

echo "🌐 Instalando Chromium para Playwright..."
python -m playwright install chromium

echo "🔐 Configurando credenciales de Confiani..."
ENV_FILE="$ROOT/.env"
if [ -f "$ENV_FILE" ]; then
  echo "✅ Usando credenciales existentes en .env"
else
  printf "📧 Correo de Confiani: "
  read -r CONFIANI_USER
  printf "🔑 Contraseña de Confiani: "
  read -rs CONFIANI_PASSWORD
  echo

  # Escribimos clave=valor en plano vía Python para evitar interpolación de
  # bash en valores con $, backticks, comillas o backslashes.
  umask 077
  CONFIANI_USER="$CONFIANI_USER" CONFIANI_PASSWORD="$CONFIANI_PASSWORD" \
    python - "$ENV_FILE" <<'PY'
import os, sys
path = sys.argv[1]
user = os.environ["CONFIANI_USER"]
pwd  = os.environ["CONFIANI_PASSWORD"]
with open(path, "w", encoding="utf-8") as f:
    f.write(f"CONFIANI_USER={user}\n")
    f.write(f"CONFIANI_PASSWORD={pwd}\n")
PY
  chmod 600 "$ENV_FILE"
  unset CONFIANI_USER CONFIANI_PASSWORD
  echo "✅ Credenciales guardadas en .env (permisos 600)"
fi

if [ "$SKIP_LOGIN" -eq 1 ]; then
  echo "⏭️  --skip-login: omitiendo login Ripor."
elif [ -f "$ROOT/skills/registro-horas/state.json" ]; then
  echo "✅ Sesión de Ripor ya existe (state.json). Si expiró, ejecuta: skills login"
else
  echo "🔑 Configurando sesión de Ripor (Google OAuth)..."
  echo "   Se abrirá Chrome para que hagas login con Google."
  echo "   Completa el login y cierra la ventana cuando termines."
  printf "   Presiona Enter para continuar... "
  read -r _
  python skills/registro-horas/registrar_horas.py --login-manual
fi

echo ""
echo "🔧 Configurando comando global 'skills'..."

SHELL_RC=""
case "${SHELL:-}" in
  *zsh*)  SHELL_RC="$HOME/.zshrc" ;;
  *bash*) SHELL_RC="$HOME/.bashrc" ;;
esac

SOURCE_LINE="source \"$ROOT/skills.sh\""
if [ -n "$SHELL_RC" ]; then
  [ -f "$SHELL_RC" ] || touch "$SHELL_RC"
  if grep -qF "$SOURCE_LINE" "$SHELL_RC"; then
    echo "✅ Comando 'skills' ya configurado en $SHELL_RC"
  else
    {
      echo ""
      echo "# skills-linktic"
      echo "$SOURCE_LINE"
    } >> "$SHELL_RC"
    echo "✅ Agregado a $SHELL_RC"
    echo "   Recarga con: source $SHELL_RC"
  fi
else
  echo "⚠️  Shell no detectada. Agrega manualmente a tu rc file:"
  echo "   $SOURCE_LINE"
fi

cat <<EOF

🎉 ¡Instalación completa!

Para usar 'skills' en esta misma terminal sin reiniciar:
   source "$ROOT/skills.sh"

Comandos disponibles:
   skills ripor   --descripcion "..." --evidencia "..."
   skills ticket  --asunto "..." --descripcion "..."
   skills login
   skills help

💡 Abre skills-linktic.code-workspace en VS Code para desarrollo integrado.
EOF
