#!/usr/bin/env python3
"""
install_glpi.py — assistente Python de implantacao GLPI.
Orquestra install-glpi.sh / bootstrap, descoberta de estados e validacao.
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path


def kit_root() -> Path:
    return Path(__file__).resolve().parent.parent


def run(cmd: list[str], *, cwd: Path | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
    print("+", " ".join(cmd), file=sys.stderr)
    return subprocess.run(cmd, cwd=cwd, check=check, text=True)


def detect_os() -> str:
    if Path("/proc/version").is_file():
        text = Path("/proc/version").read_text(errors="replace")
        if "microsoft" in text.lower():
            return "wsl"
    if os.name == "nt" or "MSYSTEM" in os.environ:
        return "git-bash"
    return "linux"


def expand(path: str) -> Path:
    return Path(os.path.expanduser(path)).resolve()


def check_prereqs() -> list[str]:
    missing = [c for c in ("bash", "curl", "jq", "python3", "rsync", "git") if not shutil.which(c)]
    return missing


def secrets_hint(preset: str) -> str:
    if preset == "api-vscode-glpi":
        return """Formato pmf (~/.secrets/GLPI-tokens.txt):
  Pessoal API-GLPI: <user_token>
  Grupo   API-GLPI: <app_token>
  URL-API: https://suporte.franca.sp.gov.br/apirest.php
"""
    return """Formato generic:
  USER_TOKEN: <token>
  APP_TOKEN: <token opcional>
  API_URL: https://seu-glpi/apirest.php
"""


def interactive_wizard(args: argparse.Namespace) -> argparse.Namespace:
    print("=== install_glpi.py — assistente GLPI ===\n")
    print(f"OS detectado: {detect_os()}\n")

    if not args.preset:
        print("Presets:")
        print("  1) api-vscode-glpi  — PMF Franca (default equipe)")
        print("  2) generic          — qualquer instancia GLPI")
        choice = input("Escolha [1]: ").strip() or "1"
        args.preset = "api-vscode-glpi" if choice in ("1", "") else "generic"

    if not args.profile:
        args.profile = input("Perfil bootstrap [pmf-core]: ").strip() or "pmf-core"

    if not args.target:
        default = str(Path.home() / "projetos" / "meu-produto")
        args.target = input(f"Diretorio do produto [{default}]: ").strip() or default

    if not args.glpi_url:
        if args.preset == "api-vscode-glpi":
            default_url = "https://suporte.franca.sp.gov.br/apirest.php"
            args.glpi_url = input(f"URL API GLPI [{default_url}]: ").strip() or default_url
        else:
            args.glpi_url = input("URL API GLPI (https://host/apirest.php): ").strip()

    if not args.key:
        args.key = Path(args.target).name or "meu-produto"

    if args.ticket is None:
        args.ticket = input("ticket_id [0]: ").strip() or "0"
    if args.project is None:
        args.project = input("project_id [0]: ").strip() or "0"

    if not args.secrets_file:
        args.secrets_file = str(Path.home() / ".secrets" / "GLPI-tokens.txt")

    sf = expand(args.secrets_file)
    if not sf.is_file():
        print("\nSecrets nao encontrados:", sf)
        print(secrets_hint(args.preset))
        if input("Continuar mesmo assim? [s/N]: ").strip().lower() not in ("s", "sim", "y"):
            sys.exit(1)

    if not args.yes:
        args.yes = input("\nConfirmar instalacao? [S/n]: ").strip().lower() not in ("n", "nao", "no")

    return args


def main() -> int:
    p = argparse.ArgumentParser(description="Assistente Python — implantacao GLPI")
    p.add_argument("--target", help="Diretorio do produto")
    p.add_argument("--profile", default="", choices=["", "glpi-only", "pmf-core", "full-skeleton"])
    p.add_argument("--preset", default="", choices=["", "api-vscode-glpi", "generic"])
    p.add_argument("--key", default="")
    p.add_argument("--ticket", default=None)
    p.add_argument("--project", default=None)
    p.add_argument("--glpi-url", default="")
    p.add_argument("--secrets-file", default="")
    p.add_argument("--secrets-format", default="pmf", choices=["pmf", "generic", "env"])
    p.add_argument("--yes", "-y", action="store_true")
    p.add_argument("--force", action="store_true")
    p.add_argument("--skip-bootstrap", action="store_true")
    p.add_argument("--skip-auth", action="store_true")
    p.add_argument("--skip-discover", action="store_true")
    p.add_argument("--skip-seed", action="store_true")
    p.add_argument("--discover-only", action="store_true", help="So descobrir estados no target")
    p.add_argument("--non-interactive", action="store_true")
    args = p.parse_args()

    missing = check_prereqs()
    if missing:
        print("Dependencias ausentes:", ", ".join(missing), file=sys.stderr)
        print("sudo apt install -y bash curl jq python3 rsync git", file=sys.stderr)
        return 1

    if not args.non_interactive and not args.discover_only:
        args = interactive_wizard(args)

    kr = kit_root()
    install_sh = kr / "scripts" / "install-glpi.sh"

    if args.discover_only:
        if not args.target:
            print("erro: --target obrigatorio com --discover-only", file=sys.stderr)
            return 1
        target = expand(args.target)
        discover = kr / "tools" / "glpi" / "lib" / "states_discover.py"
        cmd = [
            sys.executable,
            str(discover),
            "--repo-root",
            str(target),
            "--preset",
            args.preset or "api-vscode-glpi",
            "--secrets-file",
            args.secrets_file or str(Path.home() / ".secrets" / "GLPI-tokens.txt"),
            "--secrets-format",
            args.secrets_format,
            "--apply",
        ]
        if args.glpi_url:
            cmd.extend(["--api-url", args.glpi_url])
        return subprocess.call(cmd)

    if not args.target:
        print("erro: informe --target ou use modo interativo", file=sys.stderr)
        return 1

    cmd = ["bash", str(install_sh), f"--target={expand(args.target)}"]
    cmd.append(f"--profile={args.profile or 'pmf-core'}")
    cmd.append(f"--preset={args.preset or 'api-vscode-glpi'}")
    if args.key:
        cmd.append(f"--key={args.key}")
    if args.ticket is not None:
        cmd.append(f"--ticket={args.ticket}")
    if args.project is not None:
        cmd.append(f"--project={args.project}")
    if args.glpi_url:
        cmd.append(f"--glpi-url={args.glpi_url}")
    if args.secrets_file:
        cmd.append(f"--secrets-file={expand(args.secrets_file)}")
    cmd.append(f"--secrets-format={args.secrets_format}")
    if args.yes:
        cmd.append("--yes")
    if args.force:
        cmd.append("--force")
    if args.non_interactive:
        cmd.append("--non-interactive")
    if args.skip_bootstrap:
        cmd.append("--skip-bootstrap")
    if args.skip_auth:
        cmd.append("--skip-auth")
    if args.skip_discover:
        cmd.append("--skip-discover")
    if args.skip_seed:
        cmd.append("--skip-seed")

    try:
        run(cmd)
    except subprocess.CalledProcessError as e:
        return e.returncode
    return 0


if __name__ == "__main__":
    sys.exit(main())
