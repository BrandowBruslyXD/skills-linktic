# Contribuir a skills-linktic

Repo interno del equipo Linktic. PRs externos no se aceptan automáticamente,
pero se revisan caso por caso.

## Setup local de desarrollo

```bash
git clone https://github.com/BrandowBruslyXD/skills-linktic.git
cd skills-linktic
bash setup.sh --skip-login --skip-config   # solo deps, sin interacción
source .venv/bin/activate
```

## Antes de mandar un PR

1. Sintaxis bash y Python:
   ```bash
   bash -n install.sh setup.sh skills.sh
   python -m py_compile skills/_common.py skills/registro-horas/*.py skills/ticket-infra/*.py
   ```
2. (Opcional) lint:
   ```bash
   pip install ruff && ruff check skills/
   ```
3. Asegúrate que **no hay valores reales** (proyecto, centro de costo, emails)
   en `config.toml` — esos van en `config.local.toml` (gitignored).

## Estructura

- `skills/_common.py` — utilidades compartidas (config loader, sanitización HTML, helpers Playwright).
- `skills/<skill>/SKILL.md` — instrucciones para Claude/agentes que invoquen la skill.
- `skills/<skill>/<script>.py` — implementación.
- `config.toml` — defaults del equipo (sin secretos).
- `config.local.toml` — overrides personales (gitignored).
- `install.sh` / `install.ps1` — entrypoints de instalación.
- `setup.sh` / `setup.bat` — heavy lifting (venv, deps, credenciales).
- `skills.sh` / `skills.bat` — wrapper del comando `skills`.

## Agregar una skill nueva

1. Crear `skills/<nueva-skill>/`.
2. Añadir `SKILL.md` (frontmatter `name` + `description`), `requirements.txt`, y el script Python.
3. Si introduce nuevos identificadores cambiantes por usuario, agregarlos a
   `config.toml` con el placeholder `REEMPLAZA_EN_CONFIG_LOCAL` y leerlos con
   `_common.load_config("<seccion>")`.
4. Registrar el subcomando en `skills.sh` y `skills.bat`.

## Releases

Versionado semver. Para liberar:

```bash
git tag -a v0.X.0 -m "Release v0.X.0"
git push origin v0.X.0
```

El one-liner del README usa `main` por simplicidad; para entornos que
requieran reproducibilidad, sustituye `main` por el tag deseado.
