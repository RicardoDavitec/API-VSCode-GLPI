#!/usr/bin/env python3
"""atualizar_kit.py — verifica updates no pmf-dev-kit e sincroniza no produto.

Uso tipico (a partir do kit ou via wrapper do produto):
  python3 scripts/atualizar_kit.py --target=/path/produto --check-only
  python3 scripts/atualizar_kit.py --target=/path/produto --profile=full-skeleton --yes
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


def run(
    cmd: list[str],
    cwd: Path | None = None,
    check: bool = False,
    capture: bool = True,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        check=check,
        text=True,
        capture_output=capture,
    )


def git_ok(repo: Path) -> bool:
    return (repo / ".git").exists() or run(["git", "-C", str(repo), "rev-parse", "--is-inside-work-tree"]).returncode == 0


def git_out(repo: Path, *args: str) -> str:
    p = run(["git", "-C", str(repo), *args])
    if p.returncode != 0:
        return ""
    return (p.stdout or "").strip()


def resolve_target(raw: str | None) -> Path:
    if raw:
        return Path(raw).expanduser().resolve()
    env = os.environ.get("ATUALIZAR_KIT_TARGET")
    if env:
        return Path(env).expanduser().resolve()
    # cwd se for git repo
    cwd = Path.cwd().resolve()
    if git_ok(cwd):
        top = git_out(cwd, "rev-parse", "--show-toplevel")
        return Path(top).resolve() if top else cwd
    return cwd


def read_kit_path_from_yaml(target: Path) -> Path | None:
    cfg = target / ".glpi" / "kit.yaml"
    if not cfg.is_file():
        return None
    for line in cfg.read_text(encoding="utf-8", errors="replace").splitlines():
        s = line.strip()
        if s.startswith("path:"):
            val = s.split(":", 1)[1].strip().strip("\"'")
            if val:
                return Path(val).expanduser().resolve()
    return None


def resolve_kit(explicit: str | None, target: Path, script_file: Path) -> Path | None:
    candidates: list[Path] = []
    if explicit:
        candidates.append(Path(explicit).expanduser().resolve())
    for key in ("PMF_DEV_KIT", "PMF_KIT_ROOT"):
        if os.environ.get(key):
            candidates.append(Path(os.environ[key]).expanduser().resolve())
    yaml_path = read_kit_path_from_yaml(target)
    if yaml_path:
        candidates.append(yaml_path)
    # script vive em <kit>/scripts/atualizar_kit.py
    kit_from_script = script_file.resolve().parent.parent
    if (kit_from_script / "scripts" / "upgrade-into.sh").is_file():
        candidates.append(kit_from_script)
    candidates.append((target / ".." / "pmf-dev-kit").resolve())
    candidates.append((Path.home() / "projetos" / "pmf-dev-kit").resolve())

    seen: set[Path] = set()
    for c in candidates:
        if c in seen:
            continue
        seen.add(c)
        if (c / "scripts" / "upgrade-into.sh").is_file() and (c / "tools" / "glpi").is_dir():
            return c
    return None


def infer_profile(target: Path, override: str | None) -> str:
    if override:
        return override
    if (target / "docs" / "00_visao_geral").is_dir():
        return "full-skeleton"
    if (target / "docs" / "05_progresso").is_dir() or (target / ".github" / "skills" / "atualizar").is_dir():
        return "pmf-core"
    return "pmf-core"


def ensure_product_wrapper(kit: Path, target: Path) -> Path:
    """Instala wrapper fino no produto apontando para o kit."""
    scripts = target / "scripts"
    scripts.mkdir(parents=True, exist_ok=True)
    wrapper = scripts / "atualizar-kit"
    body = f"""#!/usr/bin/env bash
# Wrapper local — delega ao pmf-dev-kit (nao editar logica aqui).
set -euo pipefail
KIT="{kit}"
TARGET="$(cd "$(dirname "${{BASH_SOURCE[0]}}")/.." && pwd)"
exec python3 "$KIT/scripts/atualizar_kit.py" --kit="$KIT" --target="$TARGET" "$@"
"""
    old = wrapper.read_text(encoding="utf-8") if wrapper.is_file() else ""
    if old != body:
        wrapper.write_text(body, encoding="utf-8")
        wrapper.chmod(wrapper.stat().st_mode | 0o111)
    # registrar path do kit
    glpi = target / ".glpi"
    glpi.mkdir(parents=True, exist_ok=True)
    kit_yaml = glpi / "kit.yaml"
    desired = f"# Caminho do repositorio fonte pmf-dev-kit (sync via scripts/atualizar-kit)\npath: {kit}\n"
    if not kit_yaml.is_file() or "path:" not in kit_yaml.read_text(encoding="utf-8", errors="replace"):
        kit_yaml.write_text(desired, encoding="utf-8")
    return wrapper


def check_kit_updates(kit: Path, do_fetch: bool) -> dict:
    info: dict = {
        "kit": str(kit),
        "branch": git_out(kit, "branch", "--show-current") or "?",
        "head": git_out(kit, "rev-parse", "--short", "HEAD") or "?",
        "dirty": bool(git_out(kit, "status", "--porcelain")),
        "fetched": False,
        "behind": 0,
        "ahead": 0,
        "remote_commits": [],
        "has_updates": False,
        "messages": [],
    }
    if not git_ok(kit):
        info["messages"].append("kit nao e repositorio git; sync local mesmo assim e possivel")
        return info

    upstream = git_out(kit, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")
    if do_fetch:
        fp = run(["git", "-C", str(kit), "fetch", "--quiet", "origin"])
        info["fetched"] = fp.returncode == 0
        if fp.returncode != 0:
            info["messages"].append(
                f"fetch falhou (offline ou auth): {(fp.stderr or fp.stdout or '').strip()[:200]}"
            )

    if upstream:
        behind = git_out(kit, "rev-list", "--count", f"HEAD..{upstream}")
        ahead = git_out(kit, "rev-list", "--count", f"{upstream}..HEAD")
        info["behind"] = int(behind or "0")
        info["ahead"] = int(ahead or "0")
        if info["behind"] > 0:
            log = git_out(kit, "log", "--oneline", f"HEAD..{upstream}")
            info["remote_commits"] = [ln for ln in log.splitlines() if ln][:15]
            info["has_updates"] = True
            info["messages"].append(
                f"kit esta {info['behind']} commit(s) atras de {upstream}"
            )
        elif info["ahead"] > 0:
            info["messages"].append(
                f"kit esta {info['ahead']} commit(s) a frente de {upstream} (local)"
            )
        else:
            info["messages"].append(f"kit em sync com {upstream}")
    else:
        info["messages"].append("kit sem upstream configurado; usando working tree local")

    return info


def pull_kit(kit: Path) -> tuple[bool, str]:
    if git_out(kit, "status", "--porcelain"):
        return False, "working tree do kit suja; faca commit/stash antes do pull"
    p = run(["git", "-C", str(kit), "pull", "--ff-only"])
    if p.returncode != 0:
        err = (p.stderr or p.stdout or "pull falhou").strip()
        return False, err[:400]
    return True, (p.stdout or "ok").strip()


def run_upgrade(kit: Path, target: Path, profile: str) -> int:
    script = kit / "scripts" / "upgrade-into.sh"
    if not script.is_file():
        print(f"erro: nao encontrado {script}", file=sys.stderr)
        return 1
    print(f"→ upgrade-into.sh {target} --profile={profile}", file=sys.stderr)
    p = run([str(script), str(target), f"--profile={profile}"], capture=False)
    return p.returncode


def target_status(target: Path) -> dict:
    return {
        "target": str(target),
        "branch": git_out(target, "branch", "--show-current") if git_ok(target) else None,
        "porcelain_count": len(git_out(target, "status", "--porcelain").splitlines())
        if git_ok(target)
        else 0,
        "status_sb": git_out(target, "status", "-sb") if git_ok(target) else "",
    }


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Verifica updates no pmf-dev-kit e sincroniza no repositorio produto."
    )
    ap.add_argument("--target", default="", help="Raiz do produto (default: git toplevel / cwd)")
    ap.add_argument("--kit", default="", help="Raiz do pmf-dev-kit")
    ap.add_argument(
        "--profile",
        default="",
        help="glpi-only|pmf-core|full-skeleton (default: inferido)",
    )
    ap.add_argument("--check-only", action="store_true", help="So verifica; nao sincroniza")
    ap.add_argument("--pull-kit", action="store_true", help="git pull --ff-only no kit antes do sync")
    ap.add_argument("--no-fetch", action="store_true", help="Nao executa git fetch no kit")
    ap.add_argument("--yes", "-y", action="store_true", help="Aplica sync sem perguntar")
    ap.add_argument("--json", action="store_true", help="Saida JSON")
    args = ap.parse_args()

    script_file = Path(__file__).resolve()
    target = resolve_target(args.target or None)
    kit = resolve_kit(args.kit or None, target, script_file)
    if kit is None:
        print(
            "erro: pmf-dev-kit nao encontrado. Use --kit=PATH ou export PMF_DEV_KIT=...",
            file=sys.stderr,
        )
        return 1

    if target.resolve() == kit.resolve():
        msg = {
            "ok": False,
            "error": "TARGET e o proprio kit; nada a sincronizar para si mesmo",
            "kit": str(kit),
            "target": str(target),
        }
        print(json.dumps(msg, ensure_ascii=False) if args.json else msg["error"], file=sys.stderr)
        return 2

    profile = infer_profile(target, args.profile or None)
    check = check_kit_updates(kit, do_fetch=not args.no_fetch)

    report = {
        "ok": True,
        "mode": "check-only" if args.check_only else "sync",
        "profile": profile,
        "kit": check,
        "target": target_status(target),
        "actions": [],
    }

    if args.check_only:
        if args.json:
            print(json.dumps(report, ensure_ascii=False, indent=2))
        else:
            print(f"Kit:     {kit}")
            print(f"Target:  {target}")
            print(f"Perfil:  {profile} (inferido/flag)")
            print(f"Branch:  {check['branch']} @ {check['head']}")
            print(f"Dirty:   {check['dirty']}")
            print(f"Behind:  {check['behind']} | Ahead: {check['ahead']}")
            for m in check["messages"]:
                print(f"- {m}")
            if check["remote_commits"]:
                print("Commits remotos pendentes no kit:")
                for c in check["remote_commits"]:
                    print(f"  {c}")
            print("\nCheck-only: nenhuma escrita no produto.")
            print(f"Para sincronizar: {script_file} --target={target} --profile={profile} --yes")
        return 0

    if not args.yes and sys.stdin.isatty():
        print(f"Kit={kit} → Target={target} perfil={profile}", file=sys.stderr)
        for m in check["messages"]:
            print(f"  {m}", file=sys.stderr)
        ans = input("Aplicar upgrade-into no produto? [y/N] ").strip().lower()
        if ans not in ("y", "yes", "s", "sim"):
            print("Cancelado.", file=sys.stderr)
            return 0
    elif not args.yes:
        print("erro: use --yes em modo nao interativo", file=sys.stderr)
        return 1

    if args.pull_kit:
        ok, msg = pull_kit(kit)
        report["actions"].append({"pull_kit": ok, "detail": msg})
        if not ok:
            print(f"erro pull kit: {msg}", file=sys.stderr)
            return 1
        check = check_kit_updates(kit, do_fetch=False)
        report["kit"] = check

    ensure_product_wrapper(kit, target)
    report["actions"].append({"wrapper": str(target / "scripts" / "atualizar-kit")})

    rc = run_upgrade(kit, target, profile)
    report["upgrade_exit"] = rc
    report["target"] = target_status(target)

    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(json.dumps({"ok": rc == 0, "profile": profile, "upgrade_exit": rc}, ensure_ascii=False))
        st = report["target"].get("status_sb") or ""
        if st:
            print(st, file=sys.stderr)
        print(
            "Sync concluido. Revise git status no produto; commit sob demanda (skill exporte/commit).",
            file=sys.stderr,
        )
    return 0 if rc == 0 else rc


if __name__ == "__main__":
    raise SystemExit(main())
