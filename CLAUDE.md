# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repositorio

Automatizaciones Playwright para dos tareas internas del equipo Linktic:
- **registro-horas** → llena la jornada en Ripor (`https://ripor.co/u/horas`).
- **ticket-infra** → crea tickets en la mesa Confiani (`https://erp.confiani.com/helpdesk`).

Cada subcarpeta de `skills/` es una *skill* autocontenida con su propio `SKILL.md` (instrucciones para el agente que la invoque), `requirements.txt`, script Python y `capturas/` para debugging.

## Comandos

Todo se ejecuta dentro del venv del repo (`.venv`, creado por `setup.sh` / `install.sh`). Se requiere **Python 3.10+** (validado en setup; el código usa `T | None` y `from __future__ import annotations`).

```bash
# Setup completo (clona, crea venv, instala deps, login Ripor, pide credenciales Confiani)
bash install.sh                       # macOS/Linux
bash setup.sh --skip-login            # reinstalación sin abrir navegador
.\install.bat                         # Windows
powershell -ExecutionPolicy Bypass -File install.ps1   # Windows PowerShell

# Wrapper global (una vez instalado, disponible como `skills` desde cualquier carpeta)
skills ripor   --descripcion "..." --evidencia "..."   [--horas N] [--fecha YYYY-MM-DD] [--transporte "..."]
skills ticket  --asunto "..." --descripcion "..."      [--descripcion-archivo path] [--adjunto path]
skills login   # login manual de Google en Ripor (genera state.json)
skills help

# Invocación directa del script (útil al desarrollar)
python skills/registro-horas/registrar_horas.py --login-manual
python skills/registro-horas/registrar_horas.py --descripcion "..." --evidencia "..." --dry-run
python skills/ticket-infra/crear_ticket_confiani.py --asunto "..." --descripcion-archivo ticket_descripcion.txt
```

Banderas comunes definidas en `skills/_common.py::add_browser_args`:
- `--headless`: oculta el navegador (por defecto se abre visible — requerido en muchos casos para diagnosticar cambios de UI en Ripor/Confiani).
- `--dry-run`: llena el formulario pero no hace submit.

No hay test suite ni linter configurados.

## Arquitectura

- `skills.sh` / `skills.bat` son wrappers que activan `.venv` y enrutan el subcomando (`ripor`, `ticket`, `login`) al script Python correspondiente. La instalación expone `skills` globalmente (función shell o `PATH`).
- `skills/_common.py` centraliza utilidades compartidas: viewport por defecto, helpers de capturas (`snap`, `capturas_dir`), parser args (`add_browser_args`), y `warn_if_world_readable` para alertar permisos laxos en `state.json` / `.env`. Los scripts agregan `skills/` al `sys.path` antes de importarlo.
- **Persistencia de sesión** (registro-horas): Google OAuth se hace una vez con `--login-manual`, que abre Chromium visible (`channel=chrome`, con flags anti-automatización) y guarda cookies+localStorage en `skills/registro-horas/state.json`. Las corridas posteriores cargan ese `storage_state` y el flujo completo dura segundos. Si Google invalida la sesión, el script falla y pide relanzar `--login-manual`.
- **Credenciales** (ticket-infra): se leen de `.env` en la raíz (`CONFIANI_USER`, `CONFIANI_PASSWORD`) usando un parser regex tolerante (`_parse_env_file` en `crear_ticket_confiani.py`) que acepta comillas, `export KEY=`, `#` comentarios y CRLF. `setup.sh` escribe el `.env` vía Python para evitar interpolación shell de `$`/`` ` ``/`"`/`\` en passwords. `.env.example` es la plantilla. El login Confiani es por formulario propio, no OAuth.
- **Valores fijos por equipo** están hardcodeados en cada script (proyecto Ripor `005 - PROYECTO POSITIVA SGDEA 2026 - 3T`, centro de costos Confiani `[0004008]`, proceso `Proceso de Ingeniería Cloud`, servicio `Gestión - GCP`). Si cambian, edítalos en el script — no hay archivo de configuración.
- **Capturas**: cada paso del flujo Playwright llama `snap(page, CAPTURAS, "nombre")`. Quedan en `skills/<skill>/capturas/` (gitignored) y son la principal herramienta de debug cuando los selectores fallan por cambios de UI upstream.

## Reglas operativas (de los SKILL.md)

- **Nunca** envíes en Ripor sin mostrar primero un resumen y obtener confirmación del usuario.
- Descripciones (Ripor y Confiani) deben ser **texto plano sin markdown ni emojis** — los destinos las muestran literales.
- Asunto de ticket Confiani ≤ 70 caracteres.
- No inventes URLs de evidencia. Si el usuario no da una, sugiere PR/commit del día (`git log --since="1 day ago" --oneline`) o pide explícitamente.
- Fechas en Ripor: convertir lenguaje natural ("ayer", "el lunes") a `YYYY-MM-DD` con la fecha del sistema y avisar al usuario qué fecha se va a usar antes de enviar.
- `state.json`, `.env`, y `ticket_descripcion.txt` son temporales/locales — `.gitignore` los excluye.
