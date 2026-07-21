#!/usr/bin/env python3
"""glpi-retro-scan — candidatos hierárquicos S (pai) / P (filho) a ProjectTask."""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path

# Duração estimada (min) para o 1º commit do dia quando não há Plan ini / outra meta
DEFAULT_ESTIMATE_MINUTES = int(os.environ.get("GLPI_RETRO_ESTIMATE_MINUTES", "60"))

CHECK_RE = re.compile(r"^\s*[-*]\s*\[([ xX~])\]\s+(.+)$")
TABLE_STATUS_RE = re.compile(r"^\|\s*(.+?)\s*\|\s*\[([ xX~])\]\s*\|")
PHASE_HEADING_RE = re.compile(
    r"^##\s+Fase\s+(\d+)\s*[—\-–:].*\((S\d+)\)",
    re.IGNORECASE,
)
PHASE_HEADING_ALT_RE = re.compile(
    r"^##\s+.*\((S\d+)\)\s*$",
    re.IGNORECASE,
)
S_CODE_RE = re.compile(r"\b(S[0-9]+(?:\.[Pp][0-9]+)?)\b")
STATUS_CELL_RE = re.compile(r"^\[([ xX~])\]$")
DATE_RE = re.compile(r"^(\d{4}-\d{2}-\d{2}(?:[ T]\d{2}:\d{2}(?::\d{2})?)?)$")
META_ROW_RE = re.compile(
    # exatamente 2 colunas (Campo|Valor); [^|]+ evita capturar header largo de itens
    r"^\|\s*(ID|%|GEP|Plan ini|Plan fim|Real ini|Real fim)\s*\|\s*([^|]+?)\s*\|\s*$",
    re.IGNORECASE,
)


def load_workspace(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    data: dict = {"repos": [], "scanners": [], "glpi": {}}
    section = None
    current_repo: dict | None = None
    for raw in text.splitlines():
        line = raw.rstrip()
        if not line.strip() or line.strip().startswith("#"):
            continue
        if re.match(r"^bundle:\s*", line):
            data["bundle"] = line.split(":", 1)[1].strip()
            section = None
            continue
        if line.startswith("glpi:"):
            section = "glpi"
            continue
        if line.startswith("repos:"):
            section = "repos"
            continue
        if line.startswith("scanners:"):
            m = re.search(r"\[(.*)\]", line)
            if m:
                data["scanners"] = [x.strip() for x in m.group(1).split(",") if x.strip()]
            section = None
            continue
        if section == "glpi" and re.match(r"^\s+\w+:", line):
            k, v = line.strip().split(":", 1)
            data["glpi"][k.strip()] = v.strip()
            continue
        if section == "repos":
            if re.match(r"^\s+-\s+id:", line):
                if current_repo:
                    data["repos"].append(current_repo)
                current_repo = {"id": line.split(":", 1)[1].strip()}
            elif current_repo and re.match(r"^\s+\w+:", line):
                k, v = line.strip().split(":", 1)
                current_repo[k.strip()] = v.strip()
    if current_repo:
        data["repos"].append(current_repo)
    return data


def _clean_cell(v: str) -> str:
    v = (v or "").strip()
    v = re.sub(r"`([^`]*)`", r"\1", v)
    if v in {"—", "-", "–", ""}:
        return ""
    return v.strip()


def _parse_table_row(line: str) -> list[str] | None:
    s = line.strip()
    if not s.startswith("|") or s.count("|") < 3:
        return None
    # separator row
    if re.match(r"^\|[\s\-:|]+\|$", s):
        return None
    parts = [p.strip() for p in s.strip("|").split("|")]
    return parts


def _normalize_ts(v: str) -> str | None:
    """Normaliza para 'YYYY-MM-DD HH:MM:SS' (formato GLPI). Aceita ISO com timezone."""
    v = _clean_cell(v)
    if not v:
        return None
    # ISO 8601 (git %cI): 2026-07-21T14:30:00-03:00
    if "T" in v or re.search(r"[+-]\d{2}:\d{2}$", v) or v.endswith("Z"):
        try:
            iso = v.replace("Z", "+00:00")
            dt = datetime.fromisoformat(iso)
            if dt.tzinfo is not None:
                dt = dt.astimezone()
            return dt.strftime("%Y-%m-%d %H:%M:%S")
        except ValueError:
            pass
    if DATE_RE.match(v):
        if len(v) == 10:
            return f"{v} 00:00:00"
        if "T" in v:
            v = v.replace("T", " ")
        if len(v) == 16:
            return f"{v}:00"
        return v[:19] if len(v) >= 19 else v
    return None


def _parse_dt(ts: str | None) -> datetime | None:
    if not ts:
        return None
    norm = _normalize_ts(ts) or ts
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%d"):
        try:
            return datetime.strptime(norm[:19] if len(norm) >= 19 else norm, fmt)
        except ValueError:
            continue
    return None


def _fmt_dt(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def _empty_dates() -> dict:
    return {
        "plan_start": None,
        "plan_end": None,
        "real_start": None,
        "real_end": None,
        "temporal_source": None,
    }


def _parse_percent(v: str) -> int | None:
    v = _clean_cell(v).replace("%", "")
    if not v:
        return None
    try:
        return max(0, min(100, int(float(v))))
    except ValueError:
        return None


def status_from_mark(mark: str) -> str:
    m = mark.lower()
    if m == "x":
        return "done"
    if m == "~":
        return "partial"
    return "pending"


def percent_from_status(st: str) -> int:
    return {"done": 100, "partial": 50, "pending": 0}.get(st, 0)


def state_from_status(st: str) -> str:
    return {"done": "gep7", "partial": "gep3", "pending": "gep1"}.get(st, "gep1")


def phase_status_from_items(items: list[dict]) -> str:
    if not items:
        return "pending"
    if all(i["status_local"] == "done" for i in items):
        return "done"
    if any(i["status_local"] in ("done", "partial") for i in items):
        return "partial"
    return "pending"


def _item_from_enriched_row(cols: list[str], headers: list[str], current_phase: str, f: Path, repo_path: Path, repo_id: str, line_no: int) -> dict | None:
    """Tabela nova: ID | Item | Status | % | Plan ini | Plan fim | Real ini | Real fim | Critério | GEP"""
    hmap = {h.lower(): i for i, h in enumerate(headers)}

    def col(*names: str) -> str:
        for n in names:
            i = hmap.get(n.lower())
            if i is not None and i < len(cols):
                return cols[i]
        return ""

    code = _clean_cell(col("id", "código", "codigo")).upper()
    title = _clean_cell(col("item", "nome", "título", "titulo"))
    status_raw = _clean_cell(col("status"))
    if not title:
        return None
    if title.lower() in {"item", "status", "critério", "criterio"}:
        return None

    st = None
    sm = STATUS_CELL_RE.match(status_raw)
    if sm:
        st = status_from_mark(sm.group(1))
    elif status_raw.lower() in {"x", "done", "concluido", "concluído"}:
        st = "done"
    elif status_raw in {"~", "parcial"}:
        st = "partial"
    else:
        # fallback legado: Status embutido no 2º campo
        return None

    pct = _parse_percent(col("%", "percent", "percentual"))
    if pct is None:
        pct = percent_from_status(st)
    gep = _clean_cell(col("gep", "estado")).lower() or state_from_status(st)
    criterio = _clean_cell(col("critério", "criterio", "critério de teste"))

    if not code:
        # legado sem ID
        return None
    if re.match(r"^S\d+$", code):
        # linha de fase na tabela de itens — ignorar
        return None
    parent = current_phase
    pm = re.match(r"^(S\d+)\.P\d+$", code, re.I)
    if pm:
        parent = pm.group(1).upper()
        code = code.upper()

    plan_start = _normalize_ts(col("plan ini", "plan_start", "início planejado", "inicio planejado"))
    plan_end = _normalize_ts(col("plan fim", "plan_end", "fim planejado"))
    real_start = _normalize_ts(col("real ini", "real_start", "início real", "inicio real"))
    real_end = _normalize_ts(col("real fim", "real_end", "fim real"))

    return {
        "kind": "item",
        "code": code,
        "parent_code": parent,
        "title": title[:200],
        "status_local": st,
        "percent_done": pct,
        "state": gep,
        "plan_start": plan_start,
        "plan_end": plan_end,
        "real_start": real_start,
        "real_end": real_end,
        "temporal_source": "plan" if any([plan_start, plan_end, real_start, real_end]) else None,
        "criterion": criterio,
        "confidence": 0.95,
        "source_repos": [repo_id],
        "sources": [{"kind": "plan", "path": str(f.relative_to(repo_path)), "line": line_no}],
    }


def scan_plano_hierarchy(repo_path: Path, repo_id: str) -> list[dict]:
    """Extrai S (pai) e P (filho) de PLANO_*.md estilo SAMU (modelo enriquecido)."""
    out: list[dict] = []
    files = sorted(repo_path.glob("**/PLANO*.md"))
    files = [f for f in files if "node_modules" not in f.parts and ".git" not in f.parts]

    for f in files:
        try:
            lines = f.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue

        current_phase: str | None = None
        current_phase_title: str | None = None
        current_phase_line = 0
        phase_meta: dict = {}
        item_idx = 0
        phase_items: list[dict] = []
        table_headers: list[str] | None = None

        def flush_phase() -> None:
            nonlocal phase_items, current_phase, current_phase_title, current_phase_line, phase_meta, table_headers
            if not current_phase:
                phase_items = []
                phase_meta = {}
                table_headers = None
                return
            st = phase_status_from_items(phase_items)
            pct = phase_meta.get("percent_done")
            if pct is None:
                if phase_items:
                    pct = int(round(sum(i["percent_done"] for i in phase_items) / len(phase_items)))
                else:
                    pct = percent_from_status(st)
            state = phase_meta.get("state") or state_from_status(st)
            out.append(
                {
                    "kind": "phase",
                    "code": current_phase,
                    "parent_code": None,
                    "title": current_phase_title or current_phase,
                    "status_local": st,
                    "percent_done": pct,
                    "state": state,
                    "plan_start": phase_meta.get("plan_start"),
                    "plan_end": phase_meta.get("plan_end"),
                    "real_start": phase_meta.get("real_start"),
                    "real_end": phase_meta.get("real_end"),
                    "temporal_source": (
                        "plan"
                        if any(
                            phase_meta.get(k)
                            for k in ("plan_start", "plan_end", "real_start", "real_end")
                        )
                        else None
                    ),
                    "confidence": 0.97,
                    "source_repos": [repo_id],
                    "sources": [
                        {
                            "kind": "plan",
                            "path": str(f.relative_to(repo_path)),
                            "line": current_phase_line,
                        }
                    ],
                }
            )
            out.extend(phase_items)
            phase_items = []
            phase_meta = {}
            table_headers = None

        for i, line in enumerate(lines, 1):
            hm = PHASE_HEADING_RE.match(line) or PHASE_HEADING_ALT_RE.match(line)
            if hm:
                flush_phase()
                if PHASE_HEADING_RE.match(line):
                    current_phase = hm.group(2).upper()
                else:
                    current_phase = hm.group(1).upper()
                current_phase_title = line.lstrip("#").strip()
                current_phase_line = i
                item_idx = 0
                continue

            if not current_phase:
                continue

            # Meta fase (Campo | Valor)
            mm = META_ROW_RE.match(line)
            if mm:
                key = mm.group(1).strip().lower()
                val = _clean_cell(mm.group(2))
                if key == "id":
                    pass
                elif key == "%":
                    p = _parse_percent(val)
                    if p is not None:
                        phase_meta["percent_done"] = p
                elif key == "gep":
                    phase_meta["state"] = val.lower()
                elif key == "plan ini":
                    phase_meta["plan_start"] = _normalize_ts(val)
                elif key == "plan fim":
                    phase_meta["plan_end"] = _normalize_ts(val)
                elif key == "real ini":
                    phase_meta["real_start"] = _normalize_ts(val)
                elif key == "real fim":
                    phase_meta["real_end"] = _normalize_ts(val)
                continue

            row = _parse_table_row(line)
            if row:
                # header?
                low = [c.lower() for c in row]
                if "id" in low and ("item" in low or "status" in low):
                    table_headers = row
                    continue
                if table_headers and len(row) >= 3:
                    enriched = _item_from_enriched_row(
                        row, table_headers, current_phase, f, repo_path, repo_id, i
                    )
                    if enriched:
                        phase_items.append(enriched)
                        continue

            # legado: checkbox ou tabela Status na 2ª coluna
            title = None
            st = None
            m = CHECK_RE.match(line)
            if m:
                st = status_from_mark(m.group(1))
                title = m.group(2).strip()
            else:
                m2 = TABLE_STATUS_RE.match(line)
                if m2:
                    title = m2.group(1).strip()
                    st = status_from_mark(m2.group(2))
                    if title.upper().startswith("S") and ".P" in title.upper():
                        # já tratado no enriched
                        continue
                    if title.lower() in {"item", "id", "status", "critério de teste", "criterio de teste", "%", "gep"}:
                        continue

            if not title or not st:
                continue
            low = title.lower()
            if low in {"item", "status", "critério de teste", "criterio de teste", "campo", "valor"}:
                continue
            if low.startswith("pendente") and len(title) < 50:
                continue

            item_idx += 1
            child_code = f"{current_phase}.P{item_idx}"
            phase_items.append(
                {
                    "kind": "item",
                    "code": child_code,
                    "parent_code": current_phase,
                    "title": title[:200],
                    "status_local": st,
                    "percent_done": percent_from_status(st),
                    "state": state_from_status(st),
                    **_empty_dates(),
                    "confidence": 0.85,
                    "source_repos": [repo_id],
                    "sources": [
                        {
                            "kind": "plan",
                            "path": str(f.relative_to(repo_path)),
                            "line": i,
                        }
                    ],
                }
            )

        flush_phase()

    return out


def scan_other_markdown(repo_path: Path, repo_id: str) -> list[dict]:
    """Checklists/TODOs avulsos → itens (sem pai, se nao houver S no titulo)."""
    out: list[dict] = []
    patterns = ["**/CHECKLIST*.md", "**/*TODO*.md", "**/*TAREFAS*.md"]
    files: set[Path] = set()
    for pat in patterns:
        files.update(repo_path.glob(pat))
    files = {f for f in files if "FLUXO_COMMIT" not in f.name.upper() and "PLANO" not in f.name.upper()}

    for f in sorted(files):
        if "node_modules" in f.parts:
            continue
        try:
            lines = f.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue
        for i, line in enumerate(lines, 1):
            m = CHECK_RE.match(line)
            if not m:
                continue
            title = m.group(2).strip()
            st = status_from_mark(m.group(1))
            sm = S_CODE_RE.search(title)
            parent = None
            code = None
            kind = "item"
            if sm:
                raw = sm.group(1).upper()
                if re.match(r"^S\d+$", raw):
                    parent = raw
                    code = f"{raw}.P?"
                else:
                    # S1.5 → tratar como item sob S1
                    parent = re.match(r"^(S\d+)", raw)
                    parent = parent.group(1) if parent else None
                    code = raw.replace(".", ".P") if parent else raw
            out.append(
                {
                    "kind": kind,
                    "code": code,
                    "parent_code": parent,
                    "title": title[:200],
                    "status_local": st,
                    "percent_done": percent_from_status(st),
                    "state": state_from_status(st),
                    **_empty_dates(),
                    "confidence": 0.55,
                    "source_repos": [repo_id],
                    "sources": [
                        {
                            "kind": "checklist",
                            "path": str(f.relative_to(repo_path)),
                            "line": i,
                        }
                    ],
                }
            )
    return out


def scan_commits(
    repo_path: Path,
    repo_id: str,
    limit: int = 80,
    estimate_minutes: int = DEFAULT_ESTIMATE_MINUTES,
) -> list[dict]:
    """Commits com timestamps. Timeline no mesmo dia: fim=commit, início=commit anterior
    (ou estimativa no 1º do dia). Retro: evidência de entrega → gep7/done.
    """
    if not (repo_path / ".git").exists():
        return []
    try:
        log = subprocess.check_output(
            [
                "git",
                "-C",
                str(repo_path),
                "log",
                f"-{limit}",
                "--reverse",
                "--format=%H%x00%cI%x00%s",
            ],
            text=True,
            stderr=subprocess.DEVNULL,
        )
    except subprocess.CalledProcessError:
        return []

    raw_entries: list[dict] = []
    for line in log.splitlines():
        parts = line.split("\x00")
        if len(parts) < 3:
            continue
        sha, iso, msg = parts[0].strip(), parts[1].strip(), parts[2].strip()
        dt = _parse_dt(iso)
        if not dt:
            continue
        raw_entries.append({"sha": sha, "dt": dt, "msg": msg, "iso": iso})

    # Agrupar por dia civil (ordem cronológica já garantida por --reverse)
    by_day: dict[str, list[dict]] = defaultdict(list)
    for e in raw_entries:
        by_day[e["dt"].date().isoformat()].append(e)

    out: list[dict] = []
    for _day, entries in by_day.items():
        prev_dt: datetime | None = None
        for idx, e in enumerate(entries):
            sha, msg, dt = e["sha"], e["msg"], e["dt"]
            real_end = _fmt_dt(dt)
            temporal_source = "commit-chain"
            estimated = None
            if idx == 0 or prev_dt is None:
                # 1º commit do dia: estimar duração
                real_start_dt = dt - timedelta(minutes=estimate_minutes)
                temporal_source = "estimated"
                estimated = estimate_minutes
            else:
                real_start_dt = prev_dt
            real_start = _fmt_dt(real_start_dt)
            # Em retro: plan ≈ real (janela do trabalho versionado)
            plan_start, plan_end = real_start, real_end

            sm = S_CODE_RE.search(msg)
            parent = None
            code = None
            kind = "item"
            if sm:
                raw = sm.group(1).upper()
                if re.match(r"^S\d+$", raw):
                    kind = "phase"
                    code = raw
                    title = f"{raw} (evidencia commit)"
                else:
                    parent_m = re.match(r"^(S\d+)", raw)
                    parent = parent_m.group(1) if parent_m else None
                    code = raw
                    title = msg[:200]
            else:
                title = msg[:200]

            out.append(
                {
                    "kind": kind,
                    "code": code,
                    "parent_code": parent,
                    "title": title,
                    "status_local": "done",
                    "percent_done": 100,
                    "state": "gep7",
                    "plan_start": plan_start,
                    "plan_end": plan_end,
                    "real_start": real_start,
                    "real_end": real_end,
                    "temporal_source": temporal_source,
                    "estimated_minutes": estimated,
                    "confidence": 0.45 if code else 0.3,
                    "source_repos": [repo_id],
                    "sources": [
                        {
                            "kind": "commit",
                            "repo": repo_id,
                            "shas": [sha],
                            "message": msg[:120],
                            "committed_at": real_end,
                            "prev_committed_at": _fmt_dt(prev_dt) if prev_dt else None,
                        }
                    ],
                }
            )
            prev_dt = dt
    return out


def scan_branches(repo_path: Path, repo_id: str) -> list[dict]:
    if not (repo_path / ".git").exists():
        return []
    try:
        raw = subprocess.check_output(
            ["git", "-C", str(repo_path), "branch", "--format=%(refname:short)"],
            text=True,
            stderr=subprocess.DEVNULL,
        )
    except subprocess.CalledProcessError:
        return []
    out = []
    for name in raw.splitlines():
        name = name.strip()
        if not name or name in {"main", "master"}:
            continue
        sm = S_CODE_RE.search(name)
        parent = None
        code = None
        kind = "item"
        if sm:
            c = sm.group(1).upper()
            if re.match(r"^S\d+$", c):
                kind = "phase"
                code = c
            else:
                parent_m = re.match(r"^(S\d+)", c)
                parent = parent_m.group(1) if parent_m else None
                code = c
        out.append(
            {
                "kind": kind,
                "code": code,
                "parent_code": parent,
                "title": f"Branch: {name}",
                "status_local": "pending",
                "percent_done": 0,
                "state": "gep1",
                **_empty_dates(),
                "confidence": 0.3,
                "source_repos": [repo_id],
                "sources": [{"kind": "branch", "repo": repo_id, "name": name}],
            }
        )
    return out


SOURCE_KIND_SCORE = {
    "plan": 100,
    "checklist": 80,
    "todolist": 70,
    "branch": 40,
    "commit": 30,
}

DATE_FIELDS = ("plan_start", "plan_end", "real_start", "real_end")


def _source_score(c: dict) -> int:
    scores = [SOURCE_KIND_SCORE.get(s.get("kind", ""), 10) for s in c.get("sources", [])]
    return max(scores) if scores else 0


def _has_source_kind(c: dict, kind: str) -> bool:
    return any(s.get("kind") == kind for s in c.get("sources", []))


def _merge_dates(dst: dict, src: dict) -> None:
    """Preenche campos temporais nulos em dst com valores de src (não sobrescreve)."""
    filled = False
    for f in DATE_FIELDS:
        if not dst.get(f) and src.get(f):
            dst[f] = src[f]
            filled = True
    if filled and not dst.get("temporal_source"):
        dst["temporal_source"] = src.get("temporal_source") or "merged"
    if src.get("estimated_minutes") and not dst.get("estimated_minutes"):
        dst["estimated_minutes"] = src["estimated_minutes"]
    # Ampliar janela real se ambas as fontes tiverem datas
    ds, de = _parse_dt(dst.get("real_start")), _parse_dt(dst.get("real_end"))
    ss, se = _parse_dt(src.get("real_start")), _parse_dt(src.get("real_end"))
    if ds and ss and ss < ds:
        dst["real_start"] = src["real_start"]
    if de and se and se > de:
        dst["real_end"] = src["real_end"]
    if dst.get("real_start") and dst.get("real_end"):
        if not dst.get("plan_start"):
            dst["plan_start"] = dst["real_start"]
        if not dst.get("plan_end"):
            dst["plan_end"] = dst["real_end"]


def _dedupe_key(c: dict) -> str:
    """Chave canônica: code estável (S4 / S4.P1) agrupa plano+commit; senão título."""
    kind = c.get("kind") or "item"
    code = (c.get("code") or "").upper().strip()
    if code and not code.endswith(".P?") and code != "?":
        return f"{kind}|{code}"
    title = re.sub(r"\s+", " ", (c.get("title") or "").lower().strip())
    parent = (c.get("parent_code") or "").upper()
    return f"{kind}|{parent}|{title}"


def dedupe(cands: list[dict]) -> list[dict]:
    """Deduplica por code (S/P). Preferência: fonte plan > checklist > branch > commit.
    Datas nulas são preenchidas por qualquer fonte (commits preenchem buracos).
    """
    by_key: dict[str, dict] = {}
    for c in cands:
        key = _dedupe_key(c)
        if key not in by_key:
            by_key[key] = json.loads(json.dumps(c))
            # garantir chaves de data
            for f in DATE_FIELDS:
                by_key[key].setdefault(f, None)
            continue
        prev = by_key[key]
        prev["source_repos"] = sorted(set(prev.get("source_repos", []) + c.get("source_repos", [])))
        prev["sources"].extend(c.get("sources", []))
        prev["confidence"] = max(prev.get("confidence", 0), c.get("confidence", 0))
        if not prev.get("parent_code") and c.get("parent_code"):
            prev["parent_code"] = c["parent_code"]

        _merge_dates(prev, c)

        # Preferir título / status da fonte mais confiável (plano > commit)
        if _source_score(c) > _source_score(prev) or (
            _source_score(c) == _source_score(prev)
            and c.get("confidence", 0) > prev.get("confidence", 0)
        ):
            prev["title"] = c.get("title") or prev.get("title")
            if c.get("status_local"):
                prev["status_local"] = c["status_local"]
                prev["percent_done"] = c.get("percent_done", prev.get("percent_done"))
                prev["state"] = c.get("state", prev.get("state"))
        else:
            order = {"pending": 0, "partial": 1, "done": 2}
            if order.get(c.get("status_local") or "", 0) > order.get(prev.get("status_local") or "", 0):
                prev["status_local"] = c["status_local"]
                prev["percent_done"] = c.get("percent_done", prev.get("percent_done"))
                prev["state"] = c.get("state", prev.get("state"))

    def sort_key(x: dict):
        kind_order = 0 if x.get("kind") == "phase" else 1
        return (kind_order, x.get("parent_code") or "", x.get("code") or "", -x.get("confidence", 0))

    return sorted(by_key.values(), key=sort_key)


def reconcile_status_for_retro(cands: list[dict]) -> None:
    """Readequa status/GEP: plano/checklist mandam; commit = evidência de feito (gep7)."""
    for c in cands:
        st = c.get("status_local") or "pending"
        has_plan = _has_source_kind(c, "plan") or _has_source_kind(c, "checklist")
        has_commit = _has_source_kind(c, "commit")

        if has_plan:
            c["status_local"] = st
            c["percent_done"] = percent_from_status(st)
            c["state"] = state_from_status(st)
            if st == "done":
                c["state"] = "gep7"
                c["percent_done"] = 100
        elif has_commit:
            c["status_local"] = "done"
            c["percent_done"] = 100
            c["state"] = "gep7"
        else:
            c["status_local"] = st
            c["percent_done"] = percent_from_status(st)
            c["state"] = state_from_status(st)

        state = (c.get("state") or "").lower().strip()
        m = re.match(r"gep\s*(\d+)", state)
        if m:
            c["state"] = f"gep{m.group(1)}"

def enrich_phase_dates_from_children(cands: list[dict]) -> None:
    """Fase S: datas = min(real_start)/max(real_end) dos filhos; status agregado."""
    by_code = { (c.get("code") or "").upper(): c for c in cands if c.get("code") }
    children_by_parent: dict[str, list[dict]] = defaultdict(list)
    for c in cands:
        if c.get("kind") == "item" and c.get("parent_code"):
            children_by_parent[c["parent_code"].upper()].append(c)

    for parent_code, kids in children_by_parent.items():
        phase = by_code.get(parent_code)
        if not phase or phase.get("kind") != "phase":
            continue
        starts = [_parse_dt(k.get("real_start")) for k in kids]
        ends = [_parse_dt(k.get("real_end")) for k in kids]
        starts = [d for d in starts if d]
        ends = [d for d in ends if d]
        if starts and not phase.get("real_start"):
            phase["real_start"] = _fmt_dt(min(starts))
            phase["temporal_source"] = phase.get("temporal_source") or "children"
        if ends and not phase.get("real_end"):
            phase["real_end"] = _fmt_dt(max(ends))
            phase["temporal_source"] = phase.get("temporal_source") or "children"
        if phase.get("real_start") and not phase.get("plan_start"):
            phase["plan_start"] = phase["real_start"]
        if phase.get("real_end") and not phase.get("plan_end"):
            phase["plan_end"] = phase["real_end"]
        # Status da fase a partir dos filhos (se a fase não veio de plano done)
        if not _has_source_kind(phase, "plan") or phase.get("status_local") in (None, "pending", "partial"):
            agg = phase_status_from_items(kids)
            # Se todos done ou há commits na fase
            if agg == "done" or (_has_source_kind(phase, "commit") and agg != "pending"):
                if agg == "done":
                    phase["status_local"] = "done"
                    phase["percent_done"] = 100
                    phase["state"] = "gep7"
                else:
                    phase["status_local"] = agg
                    phase["percent_done"] = percent_from_status(agg)
                    phase["state"] = state_from_status(agg)


def fill_null_dates_from_commit_sources(cands: list[dict]) -> None:
    """Garante que candidatos com source commit herdem timestamps dos sources se ainda null."""
    for c in cands:
        if all(c.get(f) for f in DATE_FIELDS):
            continue
        commit_ends: list[datetime] = []
        commit_prevs: list[datetime] = []
        for s in c.get("sources", []):
            if s.get("kind") != "commit":
                continue
            if s.get("committed_at"):
                d = _parse_dt(s["committed_at"])
                if d:
                    commit_ends.append(d)
            if s.get("prev_committed_at"):
                d = _parse_dt(s["prev_committed_at"])
                if d:
                    commit_prevs.append(d)
        if not commit_ends:
            continue
        real_end = max(commit_ends)
        real_start = min(commit_prevs) if commit_prevs else real_end - timedelta(minutes=DEFAULT_ESTIMATE_MINUTES)
        if not c.get("real_end"):
            c["real_end"] = _fmt_dt(real_end)
        if not c.get("real_start"):
            c["real_start"] = _fmt_dt(real_start)
            c["temporal_source"] = c.get("temporal_source") or (
                "commit-chain" if commit_prevs else "estimated"
            )
        if not c.get("plan_start"):
            c["plan_start"] = c["real_start"]
        if not c.get("plan_end"):
            c["plan_end"] = c["real_end"]


def load_existing_state(repo_root: Path, project_id: str) -> tuple[set[str], set[str]]:
    names: set[str] = set()
    codes: set[str] = set()
    sf = repo_root / ".glpi" / f"state-project-{project_id}.json"
    if sf.exists():
        data = json.loads(sf.read_text(encoding="utf-8"))
        for t in data.get("tasks", []):
            if t.get("name"):
                names.add(t["name"].strip().lower())
            if t.get("code"):
                codes.add(str(t["code"]).upper())
    return names, codes


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--workspace", required=True)
    ap.add_argument("--repo-root", required=True)
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    ws = load_workspace(Path(args.workspace))
    repo_root = Path(args.repo_root)
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    project_id = str(ws.get("glpi", {}).get("project_id", ""))
    scanners = ws.get("scanners") or ["plan", "checklist", "todolist", "commit", "branch"]
    existing_names, existing_codes = (
        load_existing_state(repo_root, project_id) if project_id else (set(), set())
    )

    cands: list[dict] = []
    for repo in ws.get("repos", []):
        path = Path(repo.get("path", ""))
        rid = repo.get("id", path.name)
        if not path.is_dir():
            print(f"SKIP repo ausente: {rid} ({path})", file=sys.stderr)
            continue
        if any(s in scanners for s in ("plan", "checklist", "todolist")):
            cands.extend(scan_plano_hierarchy(path, rid))
            cands.extend(scan_other_markdown(path, rid))
        if "commit" in scanners:
            cands.extend(scan_commits(path, rid))
        if "branch" in scanners:
            cands.extend(scan_branches(path, rid))

    cands = dedupe(cands)
    fill_null_dates_from_commit_sources(cands)
    reconcile_status_for_retro(cands)
    enrich_phase_dates_from_children(cands)
    for c in cands:
        name = c["title"]
        code = (c.get("code") or "").upper()
        if name.strip().lower() in existing_names or (code and code in existing_codes):
            c["action"] = "SKIP"
        else:
            c["action"] = "NEW"
        c["suggested_glpi"] = {
            "project_id": int(project_id) if project_id.isdigit() else project_id,
            "name": name[:255],
            "code": c.get("code"),
            "kind": c.get("kind"),
            "parent_code": c.get("parent_code"),
            "percent_done": c["percent_done"],
            "state": c["state"],
            "plan_start": c.get("plan_start"),
            "plan_end": c.get("plan_end"),
            "real_start": c.get("real_start"),
            "real_end": c.get("real_end"),
            "temporal_source": c.get("temporal_source"),
            "content": (
                f"Hierarquia: kind={c.get('kind')} code={c.get('code')} "
                f"parent={c.get('parent_code')}\n"
                + (f"Criterio: {c.get('criterion')}\n" if c.get("criterion") else "")
                + f"Fonte: {c['sources'][0]}"
            ),
        }

    stamp = datetime.now(timezone.utc).astimezone().strftime("%Y-%m-%d_%H%M")
    bundle = ws.get("bundle", "workspace")
    json_path = out_dir / f"{stamp}_{bundle}.json"
    md_path = out_dir / f"{stamp}_{bundle}.md"

    phases = [c for c in cands if c.get("kind") == "phase"]
    items = [c for c in cands if c.get("kind") != "phase"]
    report = {
        "generated_at": datetime.now(timezone.utc).astimezone().isoformat(),
        "bundle": bundle,
        "project_id": project_id,
        "hierarchy": {"phase_S": "ProjectTask pai", "item_P": "ProjectTask filho (projecttasks_id)"},
        "mode": "APPLY" if args.apply else "DRY-RUN",
        "total": len(cands),
        "phases": len(phases),
        "items": len(items),
        "new": sum(1 for c in cands if c["action"] == "NEW"),
        "skip": sum(1 for c in cands if c["action"] == "SKIP"),
        "candidates": cands,
    }
    json_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    lines = [
        f"# Retro-scan GLPI hierárquico — {bundle}",
        "",
        f"- Gerado: `{report['generated_at']}`",
        f"- Projeto GLPI: `{project_id}`",
        f"- Hierarquia: **S = tarefa pai** · **P = subtarefa filho**",
        f"- Modo: **{report['mode']}**",
        f"- Total: {report['total']} (fases S={report['phases']}, itens P={report['items']}; "
        f"NEW={report['new']}, SKIP={report['skip']})",
        "",
        "| Acao | Kind | Code | Parent | Titulo | Status | Estado | % | Plan ini | Real fim | Conf |",
        "|------|------|------|--------|--------|--------|--------|---|----------|----------|------|",
    ]
    for c in cands[:250]:
        lines.append(
            f"| {c['action']} | {c.get('kind')} | {c.get('code') or ''} | "
            f"{c.get('parent_code') or ''} | {c['title'][:40].replace('|', '/')} | "
            f"{c['status_local']} | {c['state']} | {c['percent_done']} | "
            f"{(c.get('plan_start') or '')[:10]} | {(c.get('real_end') or '')[:10]} | "
            f"{c['confidence']:.2f} |"
        )
    lines.extend(
        [
            "",
            "## Ordem sugerida de apply",
            "1. Criar/atualizar **pais** (`kind=phase`, `--code=S4`)",
            "2. Criar/atualizar **filhos** (`--code=S4.P1 --parent-code=S4`)",
            "",
            "```bash",
            f"./tools/glpi/bin/glpi-retro-apply --from={json_path}",
            f"./tools/glpi/bin/glpi-retro-apply --from={json_path} --apply   # apos revisao",
            "```",
            "",
            f"JSON: `{json_path}`",
            "Doc: `docs/00-GLPI/HIERARQUIA_S_P_GLPI.md`",
            "",
        ]
    )
    md_path.write_text("\n".join(lines), encoding="utf-8")

    print(
        json.dumps(
            {
                "ok": True,
                "markdown": str(md_path),
                "json": str(json_path),
                **{k: report[k] for k in ("total", "phases", "items", "new", "skip", "mode")},
            },
            ensure_ascii=False,
        )
    )
    if args.apply:
        print(
            "AVISO: --apply no retro-scan apenas marca o relatorio; "
            "use glpi-retro-apply --from=JSON [--apply] apos revisao.",
            file=sys.stderr,
        )
        return 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
