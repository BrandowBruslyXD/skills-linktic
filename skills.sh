#!/usr/bin/env bash
# skills-linktic — wrapper global. Se sourcea desde ~/.zshrc o ~/.bashrc.

_skills_find_dir() {
    # 1) Variable explícita gana siempre
    if [ -n "${SKILLS_LINKTIC_HOME:-}" ] && [ -f "$SKILLS_LINKTIC_HOME/skills/_common.py" ]; then
        echo "$SKILLS_LINKTIC_HOME"
        return 0
    fi

    # 2) Junto a este script (caso típico tras `source skills.sh`)
    local self_dir=""
    if [ -n "${BASH_SOURCE[0]:-}" ]; then
        self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || self_dir=""
    fi
    if [ -n "$self_dir" ] && [ -f "$self_dir/skills/_common.py" ]; then
        echo "$self_dir"
        return 0
    fi

    # 3) Ubicaciones convencionales
    local dir
    for dir in "$HOME/skills-linktic" "$HOME/.skills-linktic" "/opt/skills-linktic"; do
        if [ -f "$dir/skills/_common.py" ]; then
            echo "$dir"
            return 0
        fi
    done

    echo "❌ No se encontró skills-linktic instalado." >&2
    echo "   Define SKILLS_LINKTIC_HOME o ejecuta install.sh." >&2
    return 1
}

_skills_activate_venv() {
    local skills_dir="$1"
    local activate

    case "${OSTYPE:-}" in
        msys*|win32*|cygwin*) activate="$skills_dir/.venv/Scripts/activate" ;;
        *)                    activate="$skills_dir/.venv/bin/activate"      ;;
    esac

    if [ ! -f "$activate" ]; then
        echo "❌ Entorno virtual no encontrado en $skills_dir/.venv" >&2
        echo "   Ejecuta: bash $skills_dir/setup.sh" >&2
        return 1
    fi
    # shellcheck disable=SC1090
    source "$activate"
}

skills() {
    local cmd="${1:-help}"
    [ $# -gt 0 ] && shift

    # 'help' no requiere instalación completa.
    if [ "$cmd" = "help" ] || [ "$cmd" = "-h" ] || [ "$cmd" = "--help" ]; then
        cat <<'EOF'
skills-linktic — comandos disponibles:

  skills ripor   --descripcion "..." --evidencia "..." [--fecha YYYY-MM-DD]
  skills ticket  --asunto "..." (--descripcion "..." | --descripcion-archivo PATH) [--adjunto PATH]
  skills login   Login manual de Google en Ripor (genera state.json)
  skills help    Esta ayuda

Banderas comunes:
  --headless     Oculta el navegador
  --dry-run      Llena el formulario pero no envía

Variables:
  SKILLS_LINKTIC_HOME   Override del directorio de instalación
EOF
        return 0
    fi

    local skills_dir
    skills_dir="$(_skills_find_dir)" || return 1
    _skills_activate_venv "$skills_dir" || return 1

    case "$cmd" in
        ripor)
            python "$skills_dir/skills/registro-horas/registrar_horas.py" "$@"
            ;;
        ticket)
            python "$skills_dir/skills/ticket-infra/crear_ticket_confiani.py" "$@"
            ;;
        login)
            python "$skills_dir/skills/registro-horas/registrar_horas.py" --login-manual
            ;;
        *)
            echo "❌ Comando desconocido: $cmd" >&2
            echo "   Usa 'skills help' para ver los disponibles." >&2
            return 1
            ;;
    esac
}

# Permite también ejecutar directamente: `bash skills.sh ripor ...`
if [ "${BASH_SOURCE[0]:-}" = "${0:-}" ]; then
    skills "$@"
fi
