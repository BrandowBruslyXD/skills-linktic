#!/usr/bin/env bash
# skills-linktic — instalador one-liner para macOS/Linux.
#
# Uso (remoto):
#   bash <(curl -fsSL https://raw.githubusercontent.com/BrandowBruslyXD/skills-linktic/main/install.sh)
#
# Uso (local, desde un checkout):
#   bash install.sh

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/BrandowBruslyXD/skills-linktic.git}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/skills-linktic}"

color()  { printf '\033[%sm%s\033[0m\n' "$1" "$2"; }
info()   { color "1;36" "ℹ  $1"; }
ok()     { color "1;32" "✓  $1"; }
warn()   { color "1;33" "⚠  $1"; }
die()    { color "1;31" "✗  $1" >&2; exit 1; }

require() {
    local cmd="$1" hint="$2"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        warn "Falta '$cmd' en el sistema."
        echo "   $hint" >&2
        die "Prerrequisito no satisfecho: $cmd"
    fi
}

echo
color "1;35" "════ skills-linktic — instalador ════"
echo

OS="$(uname -s)"
case "$OS" in
    Darwin)
        require git    "Instálalo con: xcode-select --install   (o)   brew install git"
        require python3 "Instálalo con: brew install python@3.12   (necesitas Python 3.10+)"
        ;;
    Linux)
        require git    "Instálalo con: sudo apt install git   (Debian/Ubuntu)   o   sudo dnf install git   (Fedora/RHEL)"
        require python3 "Instálalo con: sudo apt install python3 python3-venv   (necesitas Python 3.10+)"
        ;;
    *)
        die "SO no soportado: $OS. Usa macOS o Linux. Para Windows ejecuta install.ps1 o install.bat."
        ;;
esac

# Validar versión de Python (3.10+)
PY_VER="$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
PY_OK="$(python3 -c 'import sys; print(int(sys.version_info >= (3,10)))')"
if [ "$PY_OK" != "1" ]; then
    die "Se requiere Python 3.10+; encontrado: $PY_VER"
fi
ok "Python $PY_VER detectado"

# Modo "checkout local"
if [ -f "./setup.sh" ] && [ -f "./skills/_common.py" ]; then
    info "Detectado checkout local en $(pwd)"
    TARGET="$(pwd)"
else
    if [ -d "$INSTALL_DIR" ] && [ ! -d "$INSTALL_DIR/.git" ]; then
        die "$INSTALL_DIR existe pero no es un repositorio git. Renómbralo o bórralo."
    fi

    if [ -d "$INSTALL_DIR" ]; then
        info "Actualizando repositorio existente en $INSTALL_DIR..."
        cd "$INSTALL_DIR"
        if ! git pull --ff-only; then
            die "git pull --ff-only falló. Resuelve manualmente con: cd $INSTALL_DIR && git status"
        fi
    else
        info "Clonando $REPO_URL en $INSTALL_DIR..."
        git clone --depth=1 "$REPO_URL" "$INSTALL_DIR"
    fi
    TARGET="$INSTALL_DIR"
fi

ok "Repositorio en: $TARGET"
echo

info "Ejecutando setup..."
bash "$TARGET/setup.sh" "$@"

echo
ok "Instalación finalizada."
echo

cat <<EOF
🚀 Para empezar a usar 'skills' AHORA en esta terminal:

   source "$TARGET/skills.sh"

   o recarga tu shell:

   exec \$SHELL -l

📌 En terminales nuevas el comando 'skills' se cargará automáticamente
   (se agregó a ~/.zshrc o ~/.bashrc).

Comandos:
   skills ripor   --descripcion "..." --evidencia "..."
   skills ticket  --asunto "..." --descripcion "..."
   skills login
   skills help
EOF
