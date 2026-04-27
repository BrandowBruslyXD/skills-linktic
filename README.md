# skills-linktic

Automatizaciones Playwright para tareas internas del equipo Linktic:

- **Registro de horas en Ripor** (`skills ripor`)
- **Creación de tickets en Confiani** (`skills ticket`)

## ✨ Características

- 🚀 Instalación con un comando en macOS, Linux y Windows
- 🌍 Comando global `skills` disponible desde cualquier carpeta
- 🔒 Credenciales en `.env` (permisos `600`), sesión de Google persistente
- 📸 Capturas automáticas para diagnosticar fallos de selectores
- 🎯 Workspace de VS Code preconfigurado

## 📦 Instalación con un solo comando

### 🍎 macOS / 🐧 Linux

Abre una terminal y pega:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/BrandowBruslyXD/skills-linktic/main/install.sh)
```

El script:
1. Verifica que tengas `git` y `python3` (3.10+); si no, te dice cómo instalarlos.
2. Clona el repo en `~/skills-linktic`.
3. Crea el venv, instala Playwright + Chromium.
4. Te pide credenciales de Confiani y abre Chrome para login de Ripor.
5. Registra el comando `skills` en `~/.zshrc` o `~/.bashrc`.

Para usar `skills` en la terminal actual sin reiniciarla:

```bash
exec $SHELL -l    # o: source ~/skills-linktic/skills.sh
```

### 🪟 Windows (PowerShell — NO requiere admin)

```powershell
irm https://raw.githubusercontent.com/BrandowBruslyXD/skills-linktic/main/install.ps1 | iex
```

El script:
1. Verifica `git` y `python` (3.10+); si faltan, sugiere `winget install`.
2. Clona el repo en `%USERPROFILE%\skills-linktic`.
3. Crea venv, instala dependencias y Chromium.
4. Pide credenciales y abre Chrome para login de Ripor.
5. Agrega el directorio al `PATH` del usuario (sin tocar el `PATH` del sistema).

Cierra y reabre PowerShell (o `$env:PATH += ";$env:USERPROFILE\skills-linktic"`) para usar `skills`.

### 📦 Desde un checkout local

```bash
git clone https://github.com/BrandowBruslyXD/skills-linktic.git
cd skills-linktic
bash install.sh           # macOS/Linux
.\install.ps1             # Windows (PowerShell)
```

### 🤖 Instalación silenciosa (CI / reinstalación)

```bash
bash setup.sh --skip-login   # macOS/Linux: omite login interactivo de Ripor
.\setup.bat --skip-login     # Windows
```

## 🔧 Requisitos

- **Python 3.10+** (usa `T | None` y `from __future__ import annotations`)
- **Git**
- **Chrome o Chromium** (Playwright lo instala automáticamente)
- Conexión a internet

## 🚦 Qué hace la instalación

1. Clona o actualiza el repo (`~/skills-linktic` en macOS/Linux, `%USERPROFILE%\skills-linktic` en Windows).
2. Crea entorno virtual (`.venv`).
3. Instala dependencias (`playwright`).
4. Instala Chromium.
5. Pide credenciales de Confiani y las guarda en `.env` con permisos `600`.
6. Abre Chrome para login manual de Google en Ripor (omitible con `--skip-login`).
7. Registra el wrapper `skills.sh` en `~/.zshrc` o `~/.bashrc` (Unix), o en `PATH` (Windows).

> **Nota:** el venv se activa solo dentro del proceso de `install.sh`. Para usar `skills` en la **misma terminal** sin reiniciar:
> ```bash
> source ~/skills-linktic/skills.sh
> ```

## 🛠️ Uso

```bash
# Registrar horas (descripción + URL de evidencia)
skills ripor --descripcion "Configuré Cloud SQL en positiva-sgda-cap" \
             --evidencia  "https://github.com/org/repo/pull/123"

# Con fecha y horas custom
skills ripor --descripcion "..." --evidencia "..." --fecha 2026-04-15 --horas 8

# Crear ticket de infra
skills ticket --asunto "Habilitar Cloud SQL Admin API en positiva-sgda-cap" \
              --descripcion-archivo ticket_descripcion.txt \
              --adjunto evidencia.png

# Login manual Ripor (primera vez o tras expirar la sesión)
skills login

# Ayuda
skills help
```

Banderas comunes:

- `--headless` — oculta el navegador.
- `--dry-run` — llena el formulario pero no envía.

## 🧪 Variables de entorno opcionales

| Variable | Descripción |
|---|---|
| `SKILLS_LINKTIC_HOME` | Override del directorio de instalación. |
| `CONFIANI_USER` / `CONFIANI_PASSWORD` | Credenciales (alternativa a `.env`). |
| `PYTHON_CMD` | Binario Python a usar en `setup.sh` (default: `python3`). |
| `INSTALL_DIR` | Destino del clonado en `install.sh`. |
| `REPO_URL` | URL del repo (para forks). |

## 🗂️ Estructura

```
skills-linktic/
├── install.sh / install.bat      Bootstrapper (clona/actualiza + setup)
├── setup.sh   / setup.bat        Crea venv, instala deps, pide creds
├── skills.sh  / skills.bat       Wrapper del comando 'skills'
└── skills/
    ├── _common.py                Utilidades compartidas
    ├── registro-horas/           Skill Ripor
    │   ├── SKILL.md              Instrucciones para el agente
    │   ├── registrar_horas.py
    │   └── requirements.txt
    └── ticket-infra/             Skill Confiani
        ├── SKILL.md
        ├── crear_ticket_confiani.py
        └── requirements.txt
```

## 🔒 Seguridad

- `.env` y `state.json` están en `.gitignore`.
- `setup.sh` aplica `chmod 600` al `.env`; en Windows lo marca como oculto.
- Los scripts emiten un warning si detectan permisos laxos.
- Las contraseñas se escriben al `.env` vía Python para evitar interpolación shell con caracteres especiales (`$`, `` ` ``, `"`, `\`).

## ✅ Compatibilidad

- macOS (Intel / Apple Silicon)
- Linux (Ubuntu, Debian, Fedora…)
- Windows 10/11 (CMD, PowerShell, WSL)

## 📝 VS Code

Abre `skills-linktic.code-workspace` para tareas y configuración integrada.
