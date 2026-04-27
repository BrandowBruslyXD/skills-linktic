"""
Crea un ticket en la mesa de servicio Confiani (Odoo 18 helpdesk).

Combinación fija del solicitante:
  - Centro de costos: [0004008] 004 - PROYECTO POSITIVA SGDEA 2025 - 3T
  - Proceso:          Proceso de Ingeniería Cloud
  - Nombre servicio:  Gestión - GCP

Uso:
  export CONFIANI_USER=tu.email@linktic.com
  export CONFIANI_PASSWORD=xxx
  python skills/ticket-infra/crear_ticket_confiani.py \
      --asunto "Configurar Cloud Run Job ms-radicacion-ia-tutelas" \
      --descripcion-archivo TICKET_INFRA_DEV.txt \
      [--adjunto evidencia.png]

Requisitos: Python 3.10+, playwright>=1.47, Chromium instalado vía `playwright install`.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from _common import (
    DEFAULT_VIEWPORT,
    add_browser_args,
    capturas_dir,
    load_config,
    require_config_value,
    sanitize_html_for_dump,
    snap,
    warn_if_world_readable,
)

from playwright.sync_api import Page, sync_playwright

BASE_URL = "https://erp.confiani.com"
LOGIN_URL = f"{BASE_URL}/web/login"
HELPDESK_URL = f"{BASE_URL}/helpdesk"

CAPTURAS = capturas_dir(__file__)


def _login(page: Page, user: str, password: str) -> None:
    page.goto(LOGIN_URL, wait_until="domcontentloaded")
    page.fill('input[name="login"]', user)
    page.fill('input[name="password"]', password)
    with page.expect_navigation(wait_until="domcontentloaded", timeout=30000):
        page.click('button[type="submit"]')
    if "/web/login" in page.url:
        alerta = page.query_selector(".alert-danger, .o_login_error, .alert.alert-warning")
        msg = alerta.inner_text().strip() if alerta else "credenciales inválidas o servidor rechazó el login"
        raise RuntimeError(f"Login falló: {msg}")
    # Validación adicional: tras login Odoo expone /web o /helpdesk; nunca /web/login.
    if "/web/login" in page.content().lower() and page.query_selector('input[name="password"]'):
        raise RuntimeError("Login aparente pero el formulario sigue presente; revisa credenciales.")


def _select_by_text_contains(page: Page, select_id: str, texto: str, timeout_ms: int = 15000) -> None:
    """Selecciona en <select id=...> la option cuyo texto contenga `texto`."""
    locator = page.locator(f"#{select_id}")
    locator.wait_for(state="attached", timeout=timeout_ms)
    page.wait_for_function(
        """([id, needle]) => {
            const s = document.getElementById(id);
            return s && Array.from(s.options).some(o => o.textContent.includes(needle));
        }""",
        arg=[select_id, texto],
        timeout=timeout_ms,
    )
    valor = locator.evaluate(
        """(el, needle) => {
            const opt = Array.from(el.options).find(o => o.textContent.includes(needle));
            return opt ? opt.value : null;
        }""",
        texto,
    )
    if valor is None:
        opciones = locator.evaluate(
            "el => Array.from(el.options).map(o => o.textContent.trim())"
        )
        raise RuntimeError(
            f"No se encontró option con texto '{texto}' en #{select_id}. "
            f"Opciones disponibles: {opciones}"
        )
    locator.select_option(value=valor)


def _extraer_numero_ticket(page: Page) -> str | None:
    """Devuelve el identificador legible del ticket (`TICKET/123`) o None."""
    m = re.search(r"/sh_tickets?/(\d+)", page.url)
    if m:
        return f"TICKET/{m.group(1)}"
    m = re.search(r"TICKET/(\d+)", page.content())
    return m.group(0) if m else None


def crear_ticket(
    user: str,
    password: str,
    asunto: str,
    descripcion: str,
    proceso: str,
    servicio: str,
    centro_costo_prefijo: str,
    adjuntos: list[Path] | None = None,
    headless: bool = False,
    dry_run: bool = False,
) -> dict:
    if len(asunto) > 70:
        raise ValueError(f"El asunto supera 70 caracteres ({len(asunto)}): '{asunto}'")
    adjuntos = adjuntos or []
    for p in adjuntos:
        if not p.exists():
            raise FileNotFoundError(f"Adjunto no existe: {p}")

    with sync_playwright() as pw:
        browser = pw.chromium.launch(headless=headless)
        context = browser.new_context(viewport=DEFAULT_VIEWPORT)
        page = context.new_page()

        print("[ticket] 1/6 login...")
        _login(page, user, password)
        snap(page, CAPTURAS, "01_login_ok", enabled=dry_run)

        print("[ticket] 2/6 abriendo formulario...")
        page.goto(HELPDESK_URL, wait_until="domcontentloaded")
        page.wait_for_selector("#email_subject", state="visible", timeout=20000)
        snap(page, CAPTURAS, "02_form_abierto", enabled=dry_run)

        print("[ticket] 3/6 asunto y proceso...")
        page.fill("#email_subject", asunto)
        _select_by_text_contains(page, "team", proceso)
        snap(page, CAPTURAS, "03_asunto_proceso", enabled=dry_run)

        print("[ticket] 4/6 esperando servicios (AJAX)...")
        _select_by_text_contains(page, "ticket_type", servicio)
        snap(page, CAPTURAS, "04_servicio", enabled=dry_run)

        print("[ticket] 5/6 centro de costos y descripción...")
        _select_by_text_contains(page, "account_analytic_id", centro_costo_prefijo)

        # El formulario muestra distintos textareas según el servicio; el activo
        # es siempre el único visible marcado como required.
        try:
            page.wait_for_function(
                """() => {
                    return Array.from(document.querySelectorAll('textarea')).some(t => {
                        if (!t.required) return false;
                        const r = t.getBoundingClientRect();
                        return r.width > 0 && r.height > 0;
                    });
                }""",
                timeout=15000,
            )
        except Exception as e:
            snap(page, CAPTURAS, "05_error_sin_textarea")
            (CAPTURAS / "05_error_sin_textarea.html").write_text(
                sanitize_html_for_dump(page.content()), encoding="utf-8"
            )
            raise RuntimeError(
                "No apareció textarea visible con required=true tras seleccionar el servicio. "
                "Revisa capturas/05_error_sin_textarea.{png,html}."
            ) from e

        textarea_id = page.evaluate(
            """() => {
                const t = Array.from(document.querySelectorAll('textarea')).find(t => {
                    if (!t.required) return false;
                    const r = t.getBoundingClientRect();
                    return r.width > 0 && r.height > 0;
                });
                return t ? (t.id || t.name) : null;
            }"""
        )
        print(f"      textarea detectado: #{textarea_id}")
        page.fill(f"#{textarea_id}", descripcion)
        snap(page, CAPTURAS, "05_descripcion_lista", enabled=dry_run)

        if adjuntos:
            selector_file = 'input[type="file"][name="file"]:not([disabled])'
            try:
                page.wait_for_selector(selector_file, state="attached", timeout=10000)
            except Exception as e:
                snap(page, CAPTURAS, "05b_sin_input_adjuntos")
                raise RuntimeError(
                    f"Se pidieron {len(adjuntos)} adjuntos pero el form no expone input de archivos."
                ) from e
            page.locator(selector_file).first.set_input_files(
                [str(p.resolve()) for p in adjuntos]
            )

        if dry_run:
            print("[ticket] 6/6 DRY-RUN: formulario llenado, NO se envía")
            valores = page.evaluate(
                """(tid) => ({
                    email_subject: document.getElementById('email_subject')?.value,
                    team: document.getElementById('team')?.selectedOptions[0]?.textContent?.trim(),
                    ticket_type: document.getElementById('ticket_type')?.selectedOptions[0]?.textContent?.trim(),
                    account_analytic_id: document.getElementById('account_analytic_id')?.selectedOptions[0]?.textContent?.trim(),
                    descripcion: document.getElementById(tid)?.value?.slice(0, 120),
                })""",
                textarea_id,
            )
            resultado = {"dry_run": True, "valores": valores}
            print(f"[ticket] ✅ valores cargados: {valores}")
        else:
            print("[ticket] 6/6 enviando...")
            with page.expect_navigation(wait_until="domcontentloaded", timeout=30000):
                page.click('#submit_ticket')
            numero = _extraer_numero_ticket(page)
            if not numero:
                print(f"      ⚠️  no se pudo extraer número del ticket; revisa {page.url}")
            resultado = {"url": page.url, "ticket": numero}
            print(f"[ticket] ✅ creado: {resultado}")

        context.close()
        browser.close()
        return resultado


def _buscar_env() -> Path | None:
    """Sube hasta 6 niveles buscando un .env. Retorna el primero encontrado."""
    actual = Path(__file__).resolve().parent
    for _ in range(6):
        candidato = actual / ".env"
        if candidato.exists():
            return candidato
        if actual.parent == actual:
            break
        actual = actual.parent
    return None


# Acepta: KEY=val, KEY="val", KEY='val', export KEY=val, con espacios y CRLF.
_ENV_LINE_RE = re.compile(
    r"""^\s*(?:export\s+)?         # opcional 'export '
        (?P<key>[A-Za-z_][A-Za-z0-9_]*)
        \s*=\s*
        (?P<value>
            "(?:[^"\\]|\\.)*"      # "..."
          | '(?:[^'\\]|\\.)*'      # '...'
          | [^\r\n#]*              # crudo (hasta # comentario o EOL)
        )
        \s*(?:\#.*)?$              # comentario al final
    """,
    re.VERBOSE,
)


def _parse_env_file(path: Path) -> dict[str, str]:
    valores: dict[str, str] = {}
    for linea in path.read_text(encoding="utf-8").splitlines():
        stripped = linea.strip()
        if not stripped or stripped.startswith("#"):
            continue
        m = _ENV_LINE_RE.match(linea)
        if not m:
            continue
        valor = m.group("value").strip()
        if len(valor) >= 2 and valor[0] == valor[-1] and valor[0] in ('"', "'"):
            quote = valor[0]
            valor = valor[1:-1]
            if quote == '"':
                # Solo expandimos las escapes seguras y no shell-vars.
                valor = valor.encode("utf-8").decode("unicode_escape")
        valores[m.group("key")] = valor
    return valores


def _leer_env() -> tuple[str, str]:
    user = os.environ.get("CONFIANI_USER")
    pwd = os.environ.get("CONFIANI_PASSWORD")
    if not user or not pwd:
        env_path = _buscar_env()
        if env_path:
            warn_if_world_readable(env_path)
            datos = _parse_env_file(env_path)
            user = user or datos.get("CONFIANI_USER")
            pwd = pwd or datos.get("CONFIANI_PASSWORD")
    if not user or not pwd:
        sys.exit("❌ Faltan CONFIANI_USER / CONFIANI_PASSWORD (env vars o .env)")
    return user, pwd


def main() -> None:
    cfg = load_config("confiani")

    parser = argparse.ArgumentParser(description="Crea ticket en Confiani helpdesk")
    parser.add_argument("--asunto", required=True, help="Asunto del ticket (max 70 chars)")
    grupo = parser.add_mutually_exclusive_group(required=True)
    grupo.add_argument("--descripcion", help="Texto de la descripción")
    grupo.add_argument("--descripcion-archivo", help="Ruta a archivo con la descripción")
    parser.add_argument("--adjunto", action="append", default=[],
                        help="Ruta a adjunto (repetible)")
    parser.add_argument("--proceso", default=cfg.get("proceso"),
                        help="Texto del 'Proceso' (default: config.toml).")
    parser.add_argument("--servicio", default=cfg.get("servicio"),
                        help="Texto del 'Servicio' (default: config.toml).")
    parser.add_argument("--centro-costo", default=cfg.get("centro_costo_prefijo"),
                        help="Prefijo del centro de costo (ej. '[0004008]'). Default: config.toml.")
    add_browser_args(parser)
    args = parser.parse_args()

    proceso        = require_config_value({"proceso": args.proceso}, "proceso", "confiani", "--proceso")
    servicio       = require_config_value({"servicio": args.servicio}, "servicio", "confiani", "--servicio")
    centro_costo   = require_config_value({"centro_costo_prefijo": args.centro_costo}, "centro_costo_prefijo", "confiani", "--centro-costo")

    if args.descripcion_archivo:
        ruta = Path(args.descripcion_archivo)
        if not ruta.exists():
            sys.exit(f"❌ Archivo de descripción no existe: {ruta}")
        descripcion = ruta.read_text(encoding="utf-8")
    else:
        descripcion = args.descripcion

    user, pwd = _leer_env()
    resultado = crear_ticket(
        user=user,
        password=pwd,
        asunto=args.asunto,
        descripcion=descripcion,
        proceso=proceso,
        servicio=servicio,
        centro_costo_prefijo=centro_costo,
        adjuntos=[Path(p) for p in args.adjunto],
        headless=args.headless,
        dry_run=args.dry_run,
    )
    if resultado.get("dry_run"):
        print("\nDRY-RUN OK - nada enviado")
    else:
        print(f"\nTicket: {resultado.get('ticket') or 'sin número extraído'}")
        print(f"URL:    {resultado['url']}")


if __name__ == "__main__":
    main()
