#!/usr/bin/env python3
"""Descobre ProjectState via API GLPI e gera .glpi/maps/states.json."""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request
from datetime import date
from pathlib import Path
from typing import Any


def slugify(name: str) -> str:
    s = name.lower().strip()
    s = re.sub(r"[^a-z0-9]+", "_", s)
    s = re.sub(r"_+", "_", s).strip("_")
    return s or "state"


def gep_alias(name: str) -> str | None:
    m = re.search(r"gep\s*(\d+)", name, re.I)
    if m:
        return f"gep{m.group(1)}"
    return None


def load_env_from_secrets(path: Path, fmt: str) -> dict[str, str]:
    out: dict[str, str] = {}
    if not path.is_file():
        return out
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if fmt == "generic":
            for key in ("API_URL", "USER_TOKEN", "APP_TOKEN"):
                if line.upper().startswith(key + ":"):
                    out[key.lower()] = line.split(":", 1)[1].strip()
        else:
            if re.search(r"url.*api", line, re.I):
                m = re.search(r"(https?://\S+)", line)
                if m:
                    out["api_url"] = m.group(1).rstrip("/")
            elif re.search(r"pessoal\s+api-glpi", line, re.I):
                out["user_token"] = line.split(":", 1)[1].strip()
            elif re.search(r"grupo\s+api-glpi", line, re.I):
                out["app_token"] = line.split(":", 1)[1].strip()
            elif line.upper().startswith("USER_TOKEN:"):
                out["user_token"] = line.split(":", 1)[1].strip()
            elif line.upper().startswith("APP_TOKEN:"):
                out["app_token"] = line.split(":", 1)[1].strip()
    return out


def http_get(url: str, headers: dict[str, str]) -> tuple[int, str]:
    req = urllib.request.Request(url, headers=headers, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return resp.status, resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        return e.code, body


def init_session(api_url: str, user_token: str, app_token: str | None) -> str:
    api_url = api_url.rstrip("/")
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"user_token {user_token}",
    }
    if app_token:
        headers["App-Token"] = app_token
    code, body = http_get(f"{api_url}/initSession/", headers)
    if code != 200:
        raise RuntimeError(f"initSession HTTP {code}: {body[:500]}")
    data = json.loads(body)
    token = data.get("session_token")
    if not token:
        raise RuntimeError(f"initSession sem session_token: {body[:500]}")
    return token


def kill_session(api_url: str, session_token: str, app_token: str | None) -> None:
    api_url = api_url.rstrip("/")
    headers = {"Content-Type": "application/json", "Session-Token": session_token}
    if app_token:
        headers["App-Token"] = app_token
    try:
        http_get(f"{api_url}/killSession/", headers)
    except Exception:
        pass


def fetch_project_states(api_url: str, session_token: str, app_token: str | None) -> list[dict[str, Any]]:
    api_url = api_url.rstrip("/")
    headers = {"Content-Type": "application/json", "Session-Token": session_token}
    if app_token:
        headers["App-Token"] = app_token

    items: list[dict[str, Any]] = []
    start, page = 0, 100
    while start < 5000:
        end = start + page - 1
        code, body = http_get(f"{api_url}/ProjectState/?range={start}-{end}", headers)
        if code != 200:
            raise RuntimeError(f"ProjectState HTTP {code}: {body[:500]}")
        chunk = json.loads(body)
        if not isinstance(chunk, list):
            raise RuntimeError(f"ProjectState resposta inesperada: {body[:300]}")
        if not chunk:
            break
        items.extend(chunk)
        if len(chunk) < page:
            break
        start += page
    return items


def build_states_map(states: list[dict[str, Any]], preset: str) -> dict[str, Any]:
    aliases: dict[str, int] = {}
    by_id: dict[str, str] = {}
    seen_slugs: dict[str, int] = {}

    for st in states:
        sid = st.get("id")
        name = (st.get("name") or st.get("completename") or "").strip()
        if sid is None or not name:
            continue
        sid_int = int(sid)
        by_id[str(sid_int)] = name

        base = slugify(name)
        if base not in aliases:
            aliases[base] = sid_int
        else:
            n = seen_slugs.get(base, 1) + 1
            seen_slugs[base] = n
            aliases[f"{base}_{n}"] = sid_int

        ga = gep_alias(name)
        if ga and ga not in aliases:
            aliases[ga] = sid_int
            aliases[f"{ga}_{slugify(name)}"] = sid_int

    return {
        "comment": "Gerado por glpi states discover / install_glpi.py",
        "preset": preset,
        "updated_at": date.today().isoformat(),
        "source": "api-discover",
        "aliases": dict(sorted(aliases.items())),
        "by_id": dict(sorted(by_id.items(), key=lambda x: int(x[0]))),
    }


def main() -> int:
    p = argparse.ArgumentParser(description="Descobre ProjectState via API GLPI")
    p.add_argument("--repo-root", default=".", help="Raiz do produto")
    p.add_argument("--api-url", default=os.environ.get("GLPI_API_URL", ""))
    p.add_argument("--user-token", default=os.environ.get("GLPI_USER_TOKEN", ""))
    p.add_argument("--app-token", default=os.environ.get("GLPI_APP_TOKEN", ""))
    p.add_argument("--secrets-file", default="")
    p.add_argument("--secrets-format", default="pmf", choices=["pmf", "generic", "env"])
    p.add_argument("--preset", default="api-vscode-glpi")
    p.add_argument("--out", default="", help="Arquivo de saida (default .glpi/maps/states.json)")
    p.add_argument("--apply", action="store_true", help="Gravar arquivo")
    p.add_argument("--json", action="store_true", help="Imprimir JSON no stdout")
    args = p.parse_args()

    repo = Path(args.repo_root).resolve()
    out_path = Path(args.out) if args.out else repo / ".glpi" / "maps" / "states.json"

    api_url = args.api_url
    user_token = args.user_token
    app_token = args.app_token or None

    if not user_token or (not api_url and args.secrets_file):
        secrets_path = Path(args.secrets_file or os.path.expanduser("~/.secrets/GLPI-tokens.txt"))
        env = load_env_from_secrets(secrets_path, args.secrets_format)
        api_url = api_url or env.get("api_url", "")
        user_token = user_token or env.get("user_token", "")
        app_token = app_token or env.get("app_token")

    if not api_url or not user_token:
        print("erro: informe --api-url e --user-token ou configure secrets", file=sys.stderr)
        return 1

    session = init_session(api_url, user_token, app_token)
    try:
        states = fetch_project_states(api_url, session, app_token)
    except RuntimeError as e:
        err = str(e)
        if "403" in err or "401" in err or "RIGHT_MISSING" in err:
            print(
                f"aviso: sem permissao para GET /ProjectState/ — usando mapa do preset ou existente.\n  {err}",
                file=sys.stderr,
            )
            return 3
        raise
    finally:
        kill_session(api_url, session, app_token)

    if not states:
        print("aviso: nenhum ProjectState retornado pela API", file=sys.stderr)
        return 2

    payload = build_states_map(states, args.preset)
    text = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"

    if args.json or not args.apply:
        print(text)

    if args.apply:
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(text, encoding="utf-8")
        print(f"Mapa gravado em {out_path} ({len(payload['by_id'])} estados)", file=sys.stderr)
    elif not args.json:
        print(f"Dry-run: {len(payload['by_id'])} estados. Use --apply para gravar em {out_path}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main())
