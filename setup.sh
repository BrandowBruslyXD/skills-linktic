#!/usr/bin/env bash
# skills-linktic — setup local (crea venv, instala deps, pide credenciales).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

# --- Lectura interactiva ---------------------------------------------------
# Cuando setup.sh se invoca desde install.sh (que a su vez puede correr vía
# `bash <(curl ...)` o `curl ... | bash`), stdin del script puede estar
# conectado al pipe de curl. Reasignamos stdin (FD 0) a /dev/tty para que
# `read` bloquee de verdad y reciba las teclas del usuario.
if ! [ -t 0 ]; then
  if [ -e /dev/tty ]; then
    exec </dev/tty
  fi
fi

if ! [ -t 0 ]; then
  echo "❌ Sin TTY interactiva. El setup necesita preguntarte credenciales." >&2
  echo "   Ejecuta directamente en una terminal:" >&2
  echo "     git clone https://github.com/BrandowBruslyXD/skills-linktic.git" >&2
  echo "     cd skills-linktic && bash setup.sh" >&2
  exit 1
fi

ask() {
  local var="$1" prompt="$2" silent="${3:-0}"
  local val=""
  if [ "$silent" = "1" ]; then
    printf '%s' "$prompt" >&2
    if ! IFS= read -rs val; then
      echo >&2
      echo "❌ Lectura interrumpida (EOF). Aborto." >&2
      exit 1
    fi
    echo >&2
  else
    printf '%s' "$prompt" >&2
    if ! IFS= read -r val; then
      echo >&2
      echo "❌ Lectura interrumpida (EOF). Aborto." >&2
      exit 1
    fi
  fi
  printf -v "$var" '%s' "$val"
}

# --- Args ------------------------------------------------------------------
SKIP_LOGIN=0
SKIP_CONFIG=0
for arg in "$@"; do
  case "$arg" in
    --skip-login)  SKIP_LOGIN=1 ;;
    --skip-config) SKIP_CONFIG=1 ;;
    -h|--help)
      cat <<EOF
Uso: bash setup.sh [--skip-login] [--skip-config]

  --skip-login    No abre Chrome para login Ripor.
  --skip-config   No pregunta proyecto/centro de costo (lo dejas para después).
EOF
      exit 0
      ;;
    *) echo "⚠️  Argumento desconocido: $arg" >&2 ;;
  esac
done

cat <<'EOF'

═══════════════════════════════════════════════════════════════════════════
  skills-linktic — instalación
═══════════════════════════════════════════════════════════════════════════

Esta herramienta automatiza DOS servicios DIFERENTES, cada uno con SUS
propias credenciales. Te las pediré por separado más adelante:

  1) Ripor (https://ripor.co)        → registro de horas
       · Login con Google. Solo te abro Chrome y haces login UNA vez.
       · NO te pido contraseña aquí: la ingresas tú directamente en Google.
       · La sesión queda guardada en skills/registro-horas/state.json.

  2) Confiani (https://erp.confiani.com)  → tickets de infraestructura
       · Login con email + contraseña del HELPDESK (Odoo).
       · NO es la misma cuenta que Ripor, NI tu Google corporativo.
       · Te las pido aquí y se guardan en .env (chmod 600, gitignored).

  3) Tu proyecto / centro de costo (config personal)
       · Texto exacto del proyecto en Ripor (ej: "005 - PROYECTO X 2026 - 3T").
       · Proceso, servicio y centro de costo en Confiani.
       · Estos cambian por persona y se guardan en config.local.toml
         (también gitignored).

═══════════════════════════════════════════════════════════════════════════

EOF

echo "🐍 Verificando Python..."
PYTHON_CMD="${PYTHON_CMD:-python3}"
if ! command -v "$PYTHON_CMD" >/dev/null 2>&1; then
  echo "❌ No se encontró $PYTHON_CMD. Instala Python 3.10+ y vuelve a intentar." >&2
  exit 1
fi

if ! "$PYTHON_CMD" -c 'import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)'; then
  PY_VER="$("$PYTHON_CMD" -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
  echo "❌ Se requiere Python 3.10+. Encontrado: $PY_VER" >&2
  exit 1
fi

# Validar que el módulo `venv` está disponible (Debian/Ubuntu lo separan).
if ! "$PYTHON_CMD" -c 'import venv' 2>/dev/null; then
  echo "❌ El módulo 'venv' no está disponible para $PYTHON_CMD." >&2
  echo "   Instala con: sudo apt install python3-venv  (Debian/Ubuntu)" >&2
  echo "   o:          sudo dnf install python3        (Fedora/RHEL)" >&2
  exit 1
fi

# --- Venv ------------------------------------------------------------------
VENV_DIR="$ROOT/.venv"
# Detectar venv corrupto/incompleto (interrumpido en setup previo).
if [ -d "$VENV_DIR" ] && [ ! -x "$VENV_DIR/bin/python" ]; then
  echo "♻️  .venv parece corrupto, recreando..."
  rm -rf "$VENV_DIR"
fi
if [ ! -d "$VENV_DIR" ]; then
  echo "📦 Creando entorno virtual en $VENV_DIR..."
  "$PYTHON_CMD" -m venv "$VENV_DIR"
fi

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"
echo "🔧 Actualizando pip..."
python -m pip install --upgrade --quiet pip setuptools wheel

echo "📚 Instalando dependencias..."
for req in skills/registro-horas/requirements.txt skills/ticket-infra/requirements.txt; do
  [ -f "$req" ] && python -m pip install --quiet -r "$req"
done

# Idempotencia: extraer la ruta de instalación que reporta Playwright y verificar
# que el directorio existe (evita re-descargar 200MB en cada setup).
CHROMIUM_PATH="$(python -m playwright install chromium --dry-run 2>&1 \
  | grep -oE '/[^ ]*chromium-[0-9]+' | head -1)"
if [ -n "$CHROMIUM_PATH" ] && [ -d "$CHROMIUM_PATH" ]; then
  echo "✅ Chromium ya está instalado ($CHROMIUM_PATH)."
else
  echo "🌐 Descargando Chromium para Playwright..."
  python -m playwright install chromium
fi

# --- Credenciales Confiani -------------------------------------------------
echo ""
echo "──────────────────────────────────────────────────────────────────"
echo "  PASO 1/3 — Credenciales de CONFIANI (helpdesk Odoo)"
echo "──────────────────────────────────────────────────────────────────"
echo "  ⚠️  NO confundas con tu cuenta de Google ni con la de Ripor."
echo "      Es la cuenta con la que entras a https://erp.confiani.com/web/login"
echo ""
ENV_FILE="$ROOT/.env"
if [ -f "$ENV_FILE" ]; then
  echo "✅ Usando credenciales existentes en .env"
else
  ask CONFIANI_USER     "📧 Correo Confiani  (ej. nombre.apellido@linktic.com): "
  ask CONFIANI_PASSWORD "🔑 Contraseña Confiani (la del helpdesk, no la de Google): " 1

  umask 077
  CONFIANI_USER="$CONFIANI_USER" CONFIANI_PASSWORD="$CONFIANI_PASSWORD" \
    python - "$ENV_FILE" <<'PY'
import os, sys
path = sys.argv[1]
with open(path, "w", encoding="utf-8") as f:
    f.write(f"CONFIANI_USER={os.environ['CONFIANI_USER']}\n")
    f.write(f"CONFIANI_PASSWORD={os.environ['CONFIANI_PASSWORD']}\n")
PY
  chmod 600 "$ENV_FILE"
  unset CONFIANI_USER CONFIANI_PASSWORD
  echo "✅ Credenciales guardadas en .env (permisos 600)"
fi

# --- Configuración por usuario --------------------------------------------
LOCAL_CFG="$ROOT/config.local.toml"
if [ "$SKIP_CONFIG" -eq 1 ]; then
  echo "⏭️  --skip-config: salto configuración de proyecto/centro de costo."
elif [ -f "$LOCAL_CFG" ]; then
  echo "✅ config.local.toml ya existe."
else
  echo ""
  echo "──────────────────────────────────────────────────────────────────"
  echo "  PASO 2/3 — Tu proyecto / centro de costo (config personal)"
  echo "──────────────────────────────────────────────────────────────────"
  echo "  Estos valores varían por persona y por asignación. Si no los"
  echo "  conoces ahora, deja todos en blanco y edita después:"
  echo "      $LOCAL_CFG"
  echo ""
  ask RIPOR_PROYECTO    "📊 [Ripor]   Proyecto exacto del dropdown (ej. '005 - PROYECTO X 2026 - 3T'): "
  ask CONFIANI_PROCESO  "🏷️  [Confiani] Proceso (ej. 'Proceso de Ingeniería Cloud'): "
  ask CONFIANI_SERVICIO "🛠️  [Confiani] Servicio (ej. 'Gestión - GCP'): "
  ask CONFIANI_CC       "💰 [Confiani] Centro de costo prefijo (ej. '[0004008]'): "

  RIPOR_PROYECTO="$RIPOR_PROYECTO" CONFIANI_PROCESO="$CONFIANI_PROCESO" \
  CONFIANI_SERVICIO="$CONFIANI_SERVICIO" CONFIANI_CC="$CONFIANI_CC" \
    python - "$LOCAL_CFG" <<'PY'
import os, sys
path = sys.argv[1]
with open(path, "w", encoding="utf-8") as f:
    f.write("# Generado por setup.sh — edita libremente.\n\n")
    f.write("[ripor]\n")
    if os.environ['RIPOR_PROYECTO']:
        f.write(f'proyecto = "{os.environ["RIPOR_PROYECTO"]}"\n')
    f.write("\n[confiani]\n")
    if os.environ['CONFIANI_PROCESO']:
        f.write(f'proceso              = "{os.environ["CONFIANI_PROCESO"]}"\n')
    if os.environ['CONFIANI_SERVICIO']:
        f.write(f'servicio             = "{os.environ["CONFIANI_SERVICIO"]}"\n')
    if os.environ['CONFIANI_CC']:
        f.write(f'centro_costo_prefijo = "{os.environ["CONFIANI_CC"]}"\n')
PY
  echo "✅ config.local.toml creado."
fi

# --- Login Ripor -----------------------------------------------------------
if [ "$SKIP_LOGIN" -eq 1 ]; then
  echo "⏭️  --skip-login: omitiendo login Ripor."
elif [ -f "$ROOT/skills/registro-horas/state.json" ]; then
  echo "✅ Sesión de Ripor ya existe. Si expira, ejecuta: skills login"
else
  echo ""
  echo "──────────────────────────────────────────────────────────────────"
  echo "  PASO 3/3 — Login de RIPOR (Google OAuth)"
  echo "──────────────────────────────────────────────────────────────────"
  echo "  Voy a abrir Chrome. Inicia sesión con tu Google CORPORATIVO"
  echo "  (la misma cuenta con la que entras normalmente a Ripor)."
  echo "  Cuando veas https://ripor.co/u/horas cargado, puedes cerrar Chrome:"
  echo "  yo guardo la sesión automáticamente."
  echo ""
  ask _ENTER "  Presiona Enter para abrir Chrome... "
  python skills/registro-horas/registrar_horas.py --login-manual
fi

# --- Comando global --------------------------------------------------------
echo ""
echo "🔧 Configurando comando global 'skills'..."

SHELL_RC=""
case "${SHELL:-}" in
  *zsh*)  SHELL_RC="$HOME/.zshrc" ;;
  *bash*) SHELL_RC="$HOME/.bashrc" ;;
  *fish*) SHELL_RC="$HOME/.config/fish/config.fish" ;;
esac

SOURCE_LINE="source \"$ROOT/skills.sh\""
if [ -n "$SHELL_RC" ]; then
  mkdir -p "$(dirname "$SHELL_RC")"
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
  fi
else
  echo "⚠️  Shell no detectada. Agrega manualmente a tu rc file:"
  echo "   $SOURCE_LINE"
fi

cat <<EOF

🎉 ¡Instalación completa!

Para usar 'skills' AHORA en esta terminal:
   source "$ROOT/skills.sh"

Comandos disponibles:
   skills ripor   --descripcion "..." --evidencia "..."
   skills ticket  --asunto "..." --descripcion "..."
   skills login
   skills help
EOF
