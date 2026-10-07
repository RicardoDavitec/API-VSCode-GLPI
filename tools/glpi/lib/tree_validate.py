#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

DOC = """Validador minimo de arvore F/S/P para GLPI.

Suporta:
- --from=<arquivo.json> para validar JSON local
- --remote --project-code=<CODE> para validar projeto remoto via CLI glpi
- --strict, --only, --skip, --quiet, --format=json|text|md
"""

CODE_RE = re.compile(r"^[A-Z0-9]+(?:\.[A-Z0-9]+){0,2}$")


def eprint(msg):
    print(msg, file=sys.stderr)


def parse_args():
    p = argparse.ArgumentParser(description=DOC)
    p.add_argument("--from", dest="source", help="JSON local de entrada")
    p.add_argument("--remote", action="store_true", help="validar projeto remoto no GLPI")
    p.add_argument("--project-code", help="codigo do projeto no GLPI")
    p.add_argument("--only", help="Lista de regras isoladas, exemplo: V03,V06")
    p.add_argument("--skip", help="Lista de regras a ignorar")
    p.add_argument("--strict", action="store_true", help="promove avisos para erros")
    p.add_argument("--format", choices=["text", "json", "md"], default="text")
    p.add_argument("--out", help="arquivo para gravar o relatorio")
    p.add_argument("--quiet", action="store_true", help="so imprime exit code")
    return p.parse_args()


def normalize_only(value):
    if not value:
        return set()
    return {v.strip() for v in value.split(",") if v.strip()}


def decide_rule(rule, only, skip):
    if only and rule not in only:
        return False
    if rule in skip:
        return False
    return True


def file_to_payload(path):
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(path)
    data = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(data, dict):
        for key in ("tasks", "items", "nodes"):
            if key in data and isinstance(data[key], list):
                return data[key]
    if isinstance(data, list):
        return data
    raise ValueError("JSON precisa ser lista ou conter 'tasks'/'items'/'nodes'")


def infer_level(code):
    if not code:
        return None
    code = str(code).strip()
    if re.match(r"^[A-Z]+\d*$", code):
        return "F"
    if "." in code:
        parts = code.split(".")
        if len(parts) == 2:
            return "S"
        if len(parts) >= 3:
            return "P"
    return None


def get_name(item):
    return str((item.get("name") or item.get("title") or "")).strip()


def get_code(item):
    code = item.get("code") or item.get("code_glpi") or item.get("external_code") or ""
    return str(code).strip()


def read_remote_project(project_code=None):
    repo_root = Path(__file__).resolve().parents[3]
    project_file = repo_root / ".glpi" / "project.yaml"
    alt_file = repo_root / ".glpi" / "project.homolog.yaml"
    project_id = None

    for candidate in [project_file, alt_file]:
        if not candidate.exists():
            continue
        text = candidate.read_text(encoding="utf-8")

        if project_code:
            code = str(project_code).strip()
            if code.isdigit():
                project_id = int(code)
                break
            for pattern in [
                rf"^\s*project_id:\s*(\d+)\s*$",
                rf"^\s*code:\s*['\"]?{re.escape(code)}['\"]?\s*$",
                rf"^\s*key:\s*['\"]?{re.escape(code)}['\"]?\s*$",
            ]:
                m = re.search(pattern, text, flags=re.M)
                if m:
                    if m.lastindex:
                        project_id = int(m.group(1))
                        break

        m = re.search(r"^\s*project_id:\s*(\d+)\s*$", text, flags=re.M)
        if m:
            project_id = int(m.group(1))
            if project_code is None:
                break

    if project_id is None:
        project_id = 12

    env = "homolog" if os.environ.get("GLPI_ENV", "prod").lower() == "homolog" else "prod"
    cmd = [str(repo_root / "tools" / "glpi" / "glpi"), f"--env={env}", "project", "tasks", str(project_id)]
    try:
        out = subprocess.check_output(cmd, text=True, stderr=subprocess.STDOUT, cwd=str(repo_root))
    except subprocess.CalledProcessError as exc:
        raise RuntimeError(f"falha ao consultar projeto remoto: {exc.output}")

    try:
        payload = json.loads(out)
    except json.JSONDecodeError:
        return []
    return payload if isinstance(payload, list) else []


def validate_items(items, strict=False, only=None, skip=None):
    only = only or set()
    skip = skip or set()
    errors = []
    warnings = []

    def add(rule, sev, msg):
        bucket = errors if sev == "error" else warnings
        bucket.append((rule, msg))

    seen = {}
    for idx, item in enumerate(items):
        code = get_code(item)
        name = get_name(item)

        if decide_rule("V01", only, skip):
            if code and not CODE_RE.match(code):
                add("V01", "error", f"codigo invalido: {code!r} (item #{idx})")

        if decide_rule("V09", only, skip):
            if code:
                prev = seen.get(code)
                if prev is not None:
                    add("V09", "error", f"codigo duplicado: {code} em {prev} e {idx}")
                seen[code] = idx

        if decide_rule("V18", only, skip):
            if code and name and code not in name and f"[{code}]" not in name:
                add("V18", "error", f"name sem prefixo [{code}]: {name!r}")

        if decide_rule("V05", only, skip):
            start = item.get("plan_start_date") or item.get("real_start_date")
            end = item.get("plan_end_date") or item.get("real_end_date")
            if start and end and start > end:
                add("V05", "error", f"inicio posterior ao fim: {code or name!r}")

        if decide_rule("V06", only, skip):
            percent = item.get("percent_done")
            try:
                if percent is not None:
                    p = int(percent)
                    if p < 0 or p > 100:
                        add("V06", "error", f"percent_done fora de [0,100]: {code or name!r} ({percent})")
            except Exception:
                add("V06", "error", f"percent_done invalido: {code or name!r} ({percent!r})")

    return errors, warnings


def render_report(errors, warnings, source, fmt="text"):
    if fmt == "json":
        payload = {"source": source, "errors": [[r, m] for r, m in errors], "warnings": [[r, m] for r, m in warnings]}
        return json.dumps(payload, ensure_ascii=False, indent=2)

    lines = [f"glpi-tree-validate · {source}", f"erros={len(errors)} avisos={len(warnings)}"]
    if errors:
        lines.append("ERROS:")
        for rule, msg in errors:
            lines.append(f"  {rule}  {msg}")
    if warnings:
        lines.append("AVISOS:")
        for rule, msg in warnings:
            lines.append(f"  {rule}  {msg}")

    if fmt == "md":
        md = ["# glpi-tree-validate", "", f"- source: {source}", f"- erros: {len(errors)}", f"- avisos: {len(warnings)}", ""]
        if errors:
            md.append("## Erros")
            for rule, msg in errors:
                md.append(f"- `{rule}`: {msg}")
            md.append("")
        if warnings:
            md.append("## Avisos")
            for rule, msg in warnings:
                md.append(f"- `{rule}`: {msg}")
        return "\n".join(md)

    return "\n".join(lines)


def main():
    args = parse_args()
    only = normalize_only(args.only)
    skip = normalize_only(args.skip)
    source = args.source or ("remote" if args.remote else "stdin")

    try:
        if args.remote:
            items = read_remote_project(args.project_code)
        elif args.source:
            items = file_to_payload(args.source)
        else:
            items = []

        errors, warnings = validate_items(items, strict=args.strict, only=only, skip=skip)
        if args.strict:
            for rule, msg in warnings:
                errors.append((f"{rule}*", msg))
            warnings = []

        report = render_report(errors, warnings, source, fmt=args.format)
        if args.out:
            Path(args.out).write_text(report + "\n", encoding="utf-8")
        if not args.quiet:
            print(report)
        return 2 if errors else 0
    except Exception as exc:
        if args.out:
            Path(args.out).write_text(f"ERRO: {exc}\n", encoding="utf-8")
        if not args.quiet:
            eprint(f"ERRO: {exc}")
        return 11


if __name__ == "__main__":
    sys.exit(main())
