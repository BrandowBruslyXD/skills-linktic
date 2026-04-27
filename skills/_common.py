"""Utilidades compartidas entre las skills de Playwright."""

from __future__ import annotations

import os
import sys
from argparse import ArgumentParser
from datetime import date
from pathlib import Path

if sys.version_info >= (3, 11):
    import tomllib
else:  # pragma: no cover - solo aplica si alguien fuerza 3.10
    import tomli as tomllib  # type: ignore

DEFAULT_VIEWPORT = {"width": 1440, "height": 900}

REPO_ROOT = Path(__file__).resolve().parent.parent
CONFIG_FILE = REPO_ROOT / "config.toml"
CONFIG_LOCAL_FILE = REPO_ROOT / "config.local.toml"

_PLACEHOLDER = "REEMPLAZA_EN_CONFIG_LOCAL"


def _load_toml(path: Path) -> dict:
    if not path.exists():
        return {}
    with path.open("rb") as f:
        return tomllib.load(f)


def load_config(seccion: str) -> dict:
    """Carga `config.toml`, mergea `config.local.toml`, aplica env vars.

    Precedencia (gana el último):
      1. config.toml          (defaults del equipo, commiteado)
      2. config.local.toml    (overrides por usuario, gitignored)
      3. SKILLS_<SECCION>_<KEY>  (env vars)
    """
    cfg = dict(_load_toml(CONFIG_FILE).get(seccion, {}))
    cfg.update(_load_toml(CONFIG_LOCAL_FILE).get(seccion, {}))

    prefijo = f"SKILLS_{seccion.upper()}_"
    for env_key, env_val in os.environ.items():
        if env_key.startswith(prefijo):
            clave = env_key[len(prefijo):].lower()
            cfg[clave] = env_val
    return cfg


def require_config_value(cfg: dict, clave: str, seccion: str, flag: str) -> str:
    """Obtiene `cfg[clave]` o aborta con mensaje claro si está sin configurar."""
    valor = cfg.get(clave)
    if valor is None or valor == _PLACEHOLDER:
        sys.exit(
            f"❌ Falta '{seccion}.{clave}' en config.local.toml.\n"
            f"   Soluciones:\n"
            f"     1) Copia config.local.toml.example a config.local.toml y edítalo.\n"
            f"     2) Pasa el flag {flag} \"valor\" al comando.\n"
            f"     3) Exporta SKILLS_{seccion.upper()}_{clave.upper()}=valor"
        )
    return str(valor)


def capturas_dir(script_file: str) -> Path:
    """Crea (si hace falta) y retorna skills/<skill>/capturas/ relativo al script."""
    ruta = Path(script_file).resolve().parent / "capturas"
    ruta.mkdir(exist_ok=True)
    return ruta


def snap(page, dir_: Path, nombre: str, enabled: bool = True) -> None:
    """Screenshot full-page condicional."""
    if not enabled:
        return
    ruta = dir_ / f"{nombre}.png"
    page.screenshot(path=str(ruta), full_page=True)
    print(f"      📸 {ruta.name}")


def add_browser_args(parser: ArgumentParser) -> None:
    """Añade --headless y --dry-run con textos unificados entre skills."""
    parser.add_argument(
        "--headless", action="store_true",
        help="Ocultar navegador (por defecto se muestra)",
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Llena el formulario pero no envía",
    )


def warn_if_world_readable(path: Path) -> None:
    """Imprime un warning si `path` es legible por otros usuarios (perms > 600)."""
    try:
        mode = path.stat().st_mode & 0o777
        if mode & 0o077:
            print(
                f"⚠️  {path.name} tiene permisos {oct(mode)} — ejecuta "
                f"`chmod 600 {path}` para restringir."
            )
    except FileNotFoundError:
        pass


def fecha_iso(valor: str) -> date:
    """Tipo argparse: convierte 'YYYY-MM-DD' a date con mensaje legible."""
    try:
        return date.fromisoformat(valor)
    except ValueError as e:
        from argparse import ArgumentTypeError
        raise ArgumentTypeError(
            f"Fecha inválida '{valor}'. Formato esperado: YYYY-MM-DD"
        ) from e


def sanitize_html_for_dump(html: str, max_bytes: int = 200_000) -> str:
    """Recorta HTML antes de volcarlo a disco para no leakear cookies/tokens.

    - Limita tamaño (200KB por default).
    - Elimina headers de scripts inline (que a veces incluyen tokens).
    """
    import re as _re

    # Borrar contenido de <script>...</script> (suele tener tokens/configs).
    html = _re.sub(
        r"<script\b[^>]*>.*?</script>", "<!-- script removed -->",
        html, flags=_re.DOTALL | _re.IGNORECASE,
    )
    if len(html) > max_bytes:
        html = html[:max_bytes] + f"\n<!-- truncado a {max_bytes} bytes -->"
    return html
