#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
glpi-weekly-sheet — gera o Quadro de Trabalho Semanal (.xlsx/.ods/.md)
a partir de:
  (1) planos ativos F/S/P dos projetos  (docs/05_progresso/planos_ativos)
  (2) backlog do GLPI (chamados em nome do analista)
  (3) agenda real do analista           (.glpi/agenda.yaml)

Modelo: Projeto -> F (fase) -> S (sessao) -> P (tarefa, ~2h)
Dry-run por padrao: imprime o quadro no terminal; --write grava o arquivo.

Uso:
  glpi-weekly-sheet.py                        # semana atual, dry-run
  glpi-weekly-sheet.py --semana=2026-W41 --write
  glpi-weekly-sheet.py --formato=xlsx,md --write
  glpi-weekly-sheet.py --from-glpi            # busca backlog na API
  glpi-weekly-sheet.py --capacidade           # só o relatorio de capacidade
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from datetime import datetime, timedelta, date
from pathlib import Path
from typing import Optional

try:
    import yaml
except ImportError:
    sys.exit("ERRO: pip install pyyaml")

# ------------------------------------------------------------------ modelo

DIAS = ["seg", "ter", "qua", "qui", "sex"]
DIAS_LABEL = {"seg": "SEGUNDA-FEIRA", "ter": "TERÇA-FEIRA",
              "qua": "QUARTA-FEIRA", "qui": "QUINTA-FEIRA",
              "sex": "SEXTA-FEIRA"}
MARCADORES = {"[ ]": "todo", "[~]": "doing", "[t]": "testing",
              "[x]": "done", "[A]": "closed"}
RE_ITEM = re.compile(
    r"^\s*-\s*\[(?P<mark>[ ~tTxXaA])\]\s*\*\*(?P<code>F\d+(?:\.S\d+)?(?:\.P\d+)?)\*\*\s*(?P<titulo>.+?)\s*$"
)
RE_META = re.compile(r"<!--\s*glpi:(?P<attrs>[^>]*?)-->")
RE_ATTR = re.compile(r'(\w+)\s*=\s*"([^"]*)"')


@dataclass
class Periodo:
    id: str                 # M1..M4, T1..T4
    inicio: datetime
    fim: datetime
    reservado: bool = False

    @property
    def minutos(self) -> float:
        return (self.fim - self.inicio).total_seconds() / 60.0

    def __str__(self) -> str:
        return f"{self.id} {self.inicio:%H:%M}-{self.fim:%H:%M}"


@dataclass
class Tarefa:
    code: str               # F2.S4.P5
    titulo: str
    estado: str             # todo|doing|testing|done|closed
    projeto: str
    horas: float = 2.0
    plan_end: Optional[str] = None
    origem: str = "plano"   # plano | glpi
    ticket: Optional[str] = None

    @property
    def minutos(self) -> float:
        return self.horas * 60.0

    @property
    def fase(self) -> str:
        return self.code.split(".")[0]

    @property
    def rotulo(self) -> str:
        t = self.titulo if len(self.titulo) <= 46 else self.titulo[:43] + "..."
        return f"[{self.code}] {t}"


@dataclass
class Dia:
    sigla: str
    data: date
    projeto: str
    periodos: list[Periodo] = field(default_factory=list)
    intervalo: tuple[datetime, datetime] | None = None
    fixos: list[dict] = field(default_factory=list)
    alocacao: dict[str, Optional[Tarefa]] = field(default_factory=dict)

    @property
    def capacidade(self) -> float:
        return sum(p.minutos for p in self.periodos if not p.reservado)

    @property
    def ocupado(self) -> float:
        vistos, tot = set(), 0.0
        for t in self.alocacao.values():
            if t and t.code not in vistos:
                vistos.add(t.code)
                tot += t.minutos
        return tot

    @property
    def rho(self) -> float:
        return self.ocupado / self.capacidade if self.capacidade else 0.0


# ------------------------------------------------------- grade de periodos

def _hm(d: date, hhmm: str) -> datetime:
    h, m = (int(x) for x in hhmm.split(":"))
    return datetime(d.year, d.month, d.day, h, m)


def montar_periodos(dia: date, j: dict, grade: dict) -> tuple[list[Periodo], tuple]:
    """Divide manha e tarde em N periodos de duracao igual DENTRO do bloco."""
    res = set(grade.get("reservados", ["M1", "T4"]))
    out: list[Periodo] = []

    for pref, n, ini_k, fim_k in (
        ("M", grade["periodos_manha"], "manha_inicio", "manha_fim"),
        ("T", grade["periodos_tarde"], "tarde_inicio", "tarde_fim"),
    ):
        ini, fim = _hm(dia, j[ini_k]), _hm(dia, j[fim_k])
        passo = (fim - ini) / n
        for i in range(n):
            pid = f"{pref}{i+1}"
            out.append(Periodo(
                id=pid,
                inicio=ini + i * passo,
                fim=ini + (i + 1) * passo,
                reservado=(pid in res),
            ))

    intervalo = (_hm(dia, j["intervalo_inicio"]), _hm(dia, j["intervalo_fim"]))
    return out, intervalo


# --------------------------------------------------------- leitura de plano

def ler_plano(caminho: Path, projeto: str) -> list[Tarefa]:
    """Extrai tarefas P (e sessoes S sem P) de um plano markdown F/S/P."""
    tarefas: list[Tarefa] = []
    linhas = caminho.read_text(encoding="utf-8").splitlines()

    for i, linha in enumerate(linhas):
        m = RE_ITEM.match(linha)
        if not m:
            continue
        code = m.group("code")
        if ".P" not in code:          # só tarefas P vao para o quadro
            continue

        mark = "[" + m.group("mark").lower().replace("a", "A") + "]"
        estado = MARCADORES.get(mark, MARCADORES.get(f"[{m.group('mark')}]", "todo"))
        if estado in ("done", "closed"):
            continue                  # concluido nao entra no quadro

        # procura o metadado glpi nas 3 linhas seguintes
        plan_end, horas = None, 2.0
        for j in range(i, min(i + 4, len(linhas))):
            mm = RE_META.search(linhas[j])
            if mm:
                attrs = dict(RE_ATTR.findall(mm.group("attrs")))
                plan_end = attrs.get("plan_end")
                if attrs.get("hours"):
                    try:
                        horas = float(attrs["hours"])
                    except ValueError:
                        pass
                break

        tarefas.append(Tarefa(
            code=code,
            titulo=m.group("titulo").strip(),
            estado=estado,
            projeto=projeto,
            horas=horas,
            plan_end=plan_end,
        ))
    return tarefas


def coletar_tarefas(cfg: dict, raiz: Path) -> list[Tarefa]:
    todas: list[Tarefa] = []
    for proj in cfg["projetos"]:
        base = Path(proj.get("repo") or raiz)
        pdir = base / proj.get("planos", "docs/05_progresso/planos_ativos")
        if not pdir.is_dir():
            print(f"  [aviso] sem planos_ativos: {pdir}", file=sys.stderr)
            continue
        for md in sorted(pdir.glob("*.md")):
            if md.name.upper() == "README.MD":
                continue
            todas.extend(ler_plano(md, proj["code"]))
    return todas


def carregar_backlog_glpi(arquivo: Optional[Path]) -> list[Tarefa]:
    """Le JSON produzido por: glpi tickets --assigned-to=me --format=json"""
    if not arquivo or not arquivo.is_file():
        return []
    dados = json.loads(arquivo.read_text(encoding="utf-8"))
    out = []
    for t in dados:
        out.append(Tarefa(
            code=t.get("code") or f"GLPI-{t['id']}",
            titulo=t.get("name", ""),
            estado=t.get("state", "todo"),
            projeto=t.get("project_code", "?"),
            horas=float(t.get("hours", 2.0)),
            origem="glpi",
            ticket=str(t["id"]),
        ))
    return out


# ------------------------------------------------------------- alocacao

PESO_ESTADO = {"doing": 0, "testing": 1, "todo": 2}


def chave_prioridade(t: Tarefa):
    fase = int(re.sub(r"\D", "", t.fase) or 9)
    prazo = t.plan_end or "9999-99-99"
    return (PESO_ESTADO.get(t.estado, 3), prazo, fase, t.code)


def alocar(dias: list[Dia], tarefas: list[Tarefa], aloc_cfg: dict) -> list[Tarefa]:
    """Aloca tarefas nos periodos. Retorna as NAO alocadas (backlog)."""
    estrategia = aloc_cfg.get("estrategia", "morning-first")
    min_tarde = float(aloc_cfg.get("min_minutos_tarde", 25))
    max_rho = float(aloc_cfg.get("max_ocupacao", 1.0))
    sobra: list[Tarefa] = []

    por_proj: dict[str, list[Tarefa]] = {}
    for t in sorted(tarefas, key=chave_prioridade):
        por_proj.setdefault(t.projeto, []).append(t)

    for dia in dias:
        fila = por_proj.get(dia.projeto, [])
        livres = [p for p in dia.periodos if not p.reservado]
        if estrategia == "morning-first":
            livres.sort(key=lambda p: (0 if p.id.startswith("M") else 1, p.id))

        usados: set[str] = set()
        for t in list(fila):
            if dia.rho >= max_rho:
                break
            # quantos periodos contiguos a tarefa precisa
            candidatos = [p for p in livres if p.id not in usados]
            if not candidatos:
                break
            bloco: list[Periodo] = []
            acumulado = 0.0
            for p in candidatos:
                if p.id.startswith("T") and p.minutos < min_tarde and t.minutos > p.minutos:
                    continue
                bloco.append(p)
                acumulado += p.minutos
                if acumulado >= t.minutos:
                    break
            if acumulado < t.minutos * 0.6:     # nem 60% caberia
                continue
            for p in bloco:
                dia.alocacao[p.id] = t
                usados.add(p.id)
            fila.remove(t)

        # periodos livres sem tarefa -> rotulo de disponibilidade tecnica
        for p in livres:
            dia.alocacao.setdefault(p.id, None)

    for fila in por_proj.values():
        sobra.extend(fila)
    return sobra


# ------------------------------------------------------------ renderizacao

def render_terminal(dias: list[Dia], backlog: list[Tarefa], cfg: dict) -> None:
    g = cfg["grade"]
    rr, ri = g["rotulo_reservado"], g["rotulo_intervalo"]
    larg = 30

    print("\n" + "=" * (8 + larg * len(dias)))
    print("QUADRO DE TRABALHO SEMANAL — " + cfg["analista"]["nome"])
    print(cfg["analista"]["setor"])
    print("=" * (8 + larg * len(dias)))

    cab = "PERÍODO".ljust(8)
    for d in dias:
        cab += f"{DIAS_LABEL[d.sigla]} {d.data:%d/%m}".ljust(larg)
    print(cab)
    print("-" * (8 + larg * len(dias)))

    ordem = [p.id for p in dias[0].periodos if p.id.startswith("M")]
    ordem_t = [p.id for p in dias[0].periodos if p.id.startswith("T")]

    def linha(pid: str) -> str:
        s = pid.ljust(8)
        for d in dias:
            per = next((p for p in d.periodos if p.id == pid), None)
            if per is None:
                s += "".ljust(larg); continue
            if per.reservado:
                s += rr.ljust(larg)
            else:
                t = d.alocacao.get(pid)
                s += (t.rotulo[:larg - 1] if t else "—").ljust(larg)
        return s

    for pid in ordem:
        print(linha(pid))
    print("INTERV.".ljust(8) + "".join(ri.ljust(larg) for _ in dias))
    for pid in ordem_t:
        print(linha(pid))

    # compromissos fixos
    if any(d.fixos for d in dias):
        s = "FIXO".ljust(8)
        for d in dias:
            s += (d.fixos[0]["nome"][:larg - 1] if d.fixos else "").ljust(larg)
        print(s)

    # capacidade
    print("-" * (8 + larg * len(dias)))
    s = "CAP.".ljust(8)
    for d in dias:
        s += f"{d.ocupado/60:.1f}h / {d.capacidade/60:.1f}h  (ρ={d.rho:.0%})".ljust(larg)
    print(s)

    cap = sum(d.capacidade for d in dias) / 60
    occ = sum(d.ocupado for d in dias) / 60
    print(f"\nCapacidade semanal: {cap:.2f} h · Alocado: {occ:.2f} h · ρ={occ/cap:.0%}")

    print("\nBACKLOG (não alocado nesta semana)")
    print("-" * 62)
    smap = cfg["backlog"]["status_map"]
    if not backlog:
        print("  (vazio)")
    for t in sorted(backlog, key=chave_prioridade)[:20]:
        print(f"  {t.rotulo[:44]:46s} {smap.get(t.estado, t.estado)}")
    if len(backlog) > 20:
        print(f"  ... e mais {len(backlog)-20} item(ns)")
    print()


def render_markdown(dias: list[Dia], backlog: list[Tarefa], cfg: dict) -> str:
    g = cfg["grade"]
    L = ["# Quadro de Trabalho Semanal",
         f"\n> Analista: **{cfg['analista']['nome']}** · {cfg['analista']['setor']}",
         f"> Semana: {dias[0].data:%d/%m/%Y} a {dias[-1].data:%d/%m/%Y}\n",
         "| PERÍODO | " + " | ".join(
             f"{DIAS_LABEL[d.sigla]}<br>{d.data:%d/%m}" for d in dias) + " |",
         "|---|" + "---|" * len(dias)]

    def cel(d: Dia, pid: str) -> str:
        per = next((p for p in d.periodos if p.id == pid), None)
        if per is None:
            return ""
        if per.reservado:
            return f"_{g['rotulo_reservado']}_"
        t = d.alocacao.get(pid)
        return f"`{t.code}` {t.titulo}" if t else "—"

    for pid in [p.id for p in dias[0].periodos if p.id.startswith("M")]:
        L.append(f"| {pid} | " + " | ".join(cel(d, pid) for d in dias) + " |")
    L.append(f"| **—** | " + " | ".join(
        f"_{g['rotulo_intervalo']}_" for _ in dias) + " |")
    for pid in [p.id for p in dias[0].periodos if p.id.startswith("T")]:
        L.append(f"| {pid} | " + " | ".join(cel(d, pid) for d in dias) + " |")

    L.append("\n## Capacidade\n")
    L.append("| Dia | Projeto | Capacidade | Alocado | ρ |")
    L.append("|---|---|---|---|---|")
    for d in dias:
        L.append(f"| {DIAS_LABEL[d.sigla]} | {d.projeto} | "
                 f"{d.capacidade/60:.2f} h | {d.ocupado/60:.2f} h | {d.rho:.0%} |")

    L.append("\n## Backlog\n")
    L.append("| Item | Status |")
    L.append("|---|---|")
    smap = cfg["backlog"]["status_map"]
    for t in sorted(backlog, key=chave_prioridade):
        L.append(f"| `{t.code}` {t.titulo} | {smap.get(t.estado, t.estado)} |")
    return "\n".join(L) + "\n"


def render_xlsx(dias: list[Dia], backlog: list[Tarefa], cfg: dict, destino: Path) -> bool:
    try:
        from openpyxl import Workbook
        from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
    except ImportError:
        print("  [aviso] openpyxl ausente: pip install openpyxl", file=sys.stderr)
        return False

    g = cfg["grade"]
    wb = Workbook(); ws = wb.active; ws.title = "Planilha1"
    bold = Font(bold=True)
    head = PatternFill("solid", fgColor="D9E1F2")
    disp = PatternFill("solid", fgColor="F2F2F2")
    thin = Side(style="thin", color="999999")
    box = Border(left=thin, right=thin, top=thin, bottom=thin)
    ctr = Alignment(horizontal="center", vertical="center", wrap_text=True)

    # --- backlog (A/B) ---
    ws["A1"] = "BACKLOG"; ws["B1"] = "STATUS"
    for c in ("A1", "B1"):
        ws[c].font = bold; ws[c].fill = head; ws[c].border = box
    smap = cfg["backlog"]["status_map"]
    lin = 2
    for fx in cfg["backlog"].get("itens_fixos", []):
        ws.cell(lin, 1, fx["rotulo"]).border = box
        ws.cell(lin, 2, fx["status"]).border = box
        lin += 1
    for t in sorted(backlog, key=chave_prioridade):
        ws.cell(lin, 1, t.rotulo).border = box
        ws.cell(lin, 2, smap.get(t.estado, t.estado)).border = box
        lin += 1

    # --- quadro semanal (D..) ---
    ws.cell(1, 4, f"QUADRO DE TRABALHO SEMANAL – ANALISTA "
                  f"{cfg['analista']['nome']}").font = bold
    ws.cell(2, 4, cfg["analista"]["setor"]).font = bold
    ws.cell(3, 4, "PERÍODO").font = bold
    ws.cell(3, 4).fill = head; ws.cell(3, 4).border = box
    for j, d in enumerate(dias):
        c = ws.cell(3, 5 + j, f"{DIAS_LABEL[d.sigla]}\n{d.data:%d/%m}")
        c.font = bold; c.fill = head; c.border = box; c.alignment = ctr

    def bloco(pids: list[str], r0: int) -> int:
        for i, pid in enumerate(pids):
            r = r0 + i
            ws.cell(r, 4, f"{i+1}º").font = bold
            ws.cell(r, 4).border = box; ws.cell(r, 4).alignment = ctr
            for j, d in enumerate(dias):
                per = next((p for p in d.periodos if p.id == pid), None)
                cel = ws.cell(r, 5 + j)
                cel.border = box; cel.alignment = ctr
                if per is None:
                    continue
                if per.reservado:
                    cel.value = g["rotulo_reservado"]; cel.fill = disp
                else:
                    t = d.alocacao.get(pid)
                    cel.value = t.rotulo if t else "—"
        return r0 + len(pids)

    pm = [p.id for p in dias[0].periodos if p.id.startswith("M")]
    pt = [p.id for p in dias[0].periodos if p.id.startswith("T")]
    r = bloco(pm, 4)
    ws.cell(r, 4, g["rotulo_intervalo"]).font = bold
    ws.cell(r, 4).border = box
    for j in range(len(dias)):
        c = ws.cell(r, 5 + j, g["rotulo_intervalo"])
        c.border = box; c.alignment = ctr; c.fill = disp
    r = bloco(pt, r + 1)

    # linha de capacidade
    ws.cell(r, 4, "ρ (ocupação)").font = bold
    ws.cell(r, 4).border = box
    for j, d in enumerate(dias):
        c = ws.cell(r, 5 + j, f"{d.ocupado/60:.1f}h / {d.capacidade/60:.1f}h  ({d.rho:.0%})")
        c.border = box; c.alignment = ctr

    ws.column_dimensions["A"].width = 46
    ws.column_dimensions["B"].width = 18
    ws.column_dimensions["D"].width = 22
    for j in range(len(dias)):
        ws.column_dimensions[chr(ord("E") + j)].width = 28

    destino.parent.mkdir(parents=True, exist_ok=True)
    wb.save(destino)
    return True


def render_ods(dias, backlog, cfg, destino: Path) -> bool:
    """ODS via odfpy; se ausente, sugere converter o xlsx com libreoffice."""
    try:
        from odf.opendocument import OpenDocumentSpreadsheet
        from odf.table import Table, TableRow, TableCell
        from odf.text import P
    except ImportError:
        print("  [aviso] odfpy ausente: pip install odfpy", file=sys.stderr)
        print("          alternativa: libreoffice --headless --convert-to ods arquivo.xlsx",
              file=sys.stderr)
        return False

    doc = OpenDocumentSpreadsheet()
    tb = Table(name="Planilha1")

    def row(vals):
        tr = TableRow()
        for v in vals:
            tc = TableCell(valuetype="string")
            tc.addElement(P(text=str(v)))
            tr.addElement(tc)
        tb.addElement(tr)

    g = cfg["grade"]
    row(["BACKLOG", "STATUS", "", "QUADRO DE TRABALHO SEMANAL – ANALISTA "
         + cfg["analista"]["nome"]])
    row(["", "", "", cfg["analista"]["setor"]])
    row(["", "", "", "PERÍODO"] + [f"{DIAS_LABEL[d.sigla]} {d.data:%d/%m}" for d in dias])

    smap = cfg["backlog"]["status_map"]
    itens = [(f["rotulo"], f["status"]) for f in cfg["backlog"].get("itens_fixos", [])]
    itens += [(t.rotulo, smap.get(t.estado, t.estado))
              for t in sorted(backlog, key=chave_prioridade)]

    pm = [p.id for p in dias[0].periodos if p.id.startswith("M")]
    pt = [p.id for p in dias[0].periodos if p.id.startswith("T")]
    seq = [(f"{i+1}º", pid) for i, pid in enumerate(pm)]
    seq += [(g["rotulo_intervalo"], None)]
    seq += [(f"{i+1}º", pid) for i, pid in enumerate(pt)]

    for i, (rot, pid) in enumerate(seq):
        bl = itens[i] if i < len(itens) else ("", "")
        linha = [bl[0], bl[1], "", rot]
        for d in dias:
            if pid is None:
                linha.append(g["rotulo_intervalo"]); continue
            per = next((p for p in d.periodos if p.id == pid), None)
            if per is None:
                linha.append("")
            elif per.reservado:
                linha.append(g["rotulo_reservado"])
            else:
                t = d.alocacao.get(pid)
                linha.append(t.rotulo if t else "—")
        row(linha)

    for bl in itens[len(seq):]:
        row([bl[0], bl[1]])

    doc.spreadsheet.addElement(tb)
    destino.parent.mkdir(parents=True, exist_ok=True)
    doc.save(str(destino))
    return True


# ------------------------------------------------------------------- main

def semana_iso(txt: Optional[str]) -> tuple[int, int]:
    if txt:
        m = re.match(r"(\d{4})-W(\d{1,2})", txt)
        if not m:
            sys.exit("ERRO: --semana no formato AAAA-Wnn (ex.: 2026-W41)")
        return int(m.group(1)), int(m.group(2))
    hoje = date.today()
    iso = hoje.isocalendar()
    return iso[0], iso[1]


def main() -> int:
    ap = argparse.ArgumentParser(description="Gera o Quadro de Trabalho Semanal")
    ap.add_argument("--agenda", default=".glpi/agenda.yaml")
    ap.add_argument("--semana", help="AAAA-Wnn (default: semana atual)")
    ap.add_argument("--backlog-json", help="JSON de chamados do GLPI")
    ap.add_argument("--formato", default="md", help="md,xlsx,ods")
    ap.add_argument("--out-dir")
    ap.add_argument("--estrategia", choices=["slice", "atom", "morning-first"])
    ap.add_argument("--capacidade", action="store_true",
                    help="só o relatório de capacidade")
    ap.add_argument("--write", action="store_true", help="grava o(s) arquivo(s)")
    a = ap.parse_args()

    raiz = Path.cwd()
    agenda = Path(a.agenda)
    if not agenda.is_file():
        sys.exit(f"ERRO: {agenda} nao encontrado. "
                 f"Copie de .glpi/agenda.yaml.example")
    cfg = yaml.safe_load(agenda.read_text(encoding="utf-8"))
    if a.estrategia:
        cfg["alocacao"]["estrategia"] = a.estrategia

    ano, sem = semana_iso(a.semana)
    segunda = date.fromisocalendar(ano, sem, 1)

    # monta os dias
    jornadas = cfg["jornadas"]
    dias: list[Dia] = []
    for i, sig in enumerate(DIAS):
        j = next((v for v in jornadas.values() if sig in v["dias"]), None)
        if j is None:
            continue
        d = segunda + timedelta(days=i)
        per, intv = montar_periodos(d, j, cfg["grade"])
        dias.append(Dia(sigla=sig, data=d,
                        projeto=cfg["dedicacao"].get(sig, "?"),
                        periodos=per, intervalo=intv,
                        fixos=j.get("compromissos_fixos", [])))

    if a.capacidade:
        print(f"\nCapacidade — semana {ano}-W{sem:02d}\n" + "-" * 64)
        tot = 0.0
        for d in dias:
            m = [p for p in d.periodos if p.id.startswith("M") and not p.reservado]
            t = [p for p in d.periodos if p.id.startswith("T") and not p.reservado]
            print(f"  {DIAS_LABEL[d.sigla]:15s} {d.projeto:8s} "
                  f"manha {m[0].minutos:5.1f} min x{len(m)} · "
                  f"tarde {t[0].minutos:5.1f} min x{len(t)} = {d.capacidade/60:.2f} h")
            tot += d.capacidade / 60
        print("-" * 64)
        print(f"  TOTAL {tot:.2f} h  ->  {tot/2:.1f} tarefas P de 2h\n")
        return 0

    tarefas = coletar_tarefas(cfg, raiz)
    tarefas += carregar_backlog_glpi(
        Path(a.backlog_json) if a.backlog_json else None
    )

    if not tarefas:
        print("  [aviso] nenhuma tarefa P pendente encontrada nos planos ativos.",
              file=sys.stderr)
        print("          verifique docs/05_progresso/planos_ativos/ dos projetos.",
              file=sys.stderr)

    # ------------------------------------------------------------- alocacao
    backlog = alocar(dias, tarefas, cfg["alocacao"])

    # ------------------------------------------- guarda de capacidade (rho)
    max_rho = float(cfg["alocacao"].get("max_ocupacao", 1.0))
    alerta = float(cfg["alocacao"].get("alerta_ocupacao", 0.85))
    sobrecarga = False
    for d in dias:
        if d.rho > max_rho + 1e-9:
            print(f"  [ERRO] {DIAS_LABEL[d.sigla]} sobrealocado: "
                  f"rho={d.rho:.0%} > {max_rho:.0%} "
                  f"({d.ocupado/60:.2f} h em {d.capacidade/60:.2f} h)",
                  file=sys.stderr)
            sobrecarga = True
        elif d.rho >= alerta:
            print(f"  [aviso] {DIAS_LABEL[d.sigla]} com rho={d.rho:.0%} "
                  f"(limiar de alerta {alerta:.0%})", file=sys.stderr)

    # --------------------------------------------------------- visualizacao
    render_terminal(dias, backlog, cfg)

    if sobrecarga:
        print("  Reduza tarefas, aumente --estrategia=atom ou reveja as horas.\n",
              file=sys.stderr)
        return 2

    # --------------------------------------------------------------- escrita
    if not a.write:
        print("  [dry-run] nenhum arquivo gravado. Use --write para gerar.\n")
        return 0

    out_dir = Path(a.out_dir or cfg["saida"]["dir"])
    padrao = cfg["saida"]["nome"]
    formatos = [f.strip().lower() for f in a.formato.split(",") if f.strip()]
    gerados: list[Path] = []

    for ext in formatos:
        destino = out_dir / padrao.format(ano=ano, semana=f"{sem:02d}", ext=ext)
        ok = False
        if ext == "md":
            destino.parent.mkdir(parents=True, exist_ok=True)
            destino.write_text(render_markdown(dias, backlog, cfg),
                               encoding="utf-8")
            ok = True
        elif ext == "xlsx":
            ok = render_xlsx(dias, backlog, cfg, destino)
        elif ext == "ods":
            ok = render_ods(dias, backlog, cfg, destino)
        else:
            print(f"  [aviso] formato desconhecido: {ext}", file=sys.stderr)
            continue
        if ok:
            gerados.append(destino)
            print(f"  gravado: {destino}")

    # sidecar JSON para rastreio e para o glpi-node-upsert
    if gerados:
        sidecar = out_dir / f"quadro_semanal-{ano}_S{sem:02d}.json"
        payload = {
            "gerado_em": datetime.now().isoformat(timespec="seconds"),
            "semana": f"{ano}-W{sem:02d}",
            "analista": cfg["analista"]["nome"],
            "estrategia": cfg["alocacao"]["estrategia"],
            "arquivos": [str(p) for p in gerados],
            "dias": [
                {
                    "sigla": d.sigla,
                    "data": d.data.isoformat(),
                    "projeto": d.projeto,
                    "capacidade_min": round(d.capacidade, 1),
                    "ocupado_min": round(d.ocupado, 1),
                    "rho": round(d.rho, 4),
                    "periodos": [
                        {
                            "id": p.id,
                            "inicio": p.inicio.strftime("%H:%M"),
                            "fim": p.fim.strftime("%H:%M"),
                            "minutos": round(p.minutos, 1),
                            "reservado": p.reservado,
                            "tarefa": (d.alocacao.get(p.id).code
                                       if d.alocacao.get(p.id) else None),
                            "titulo": (d.alocacao.get(p.id).titulo
                                       if d.alocacao.get(p.id) else None),
                        }
                        for p in d.periodos
                    ],
                    "fixos": d.fixos,
                }
                for d in dias
            ],
            "backlog": [
                {
                    "code": t.code, "titulo": t.titulo, "estado": t.estado,
                    "projeto": t.projeto, "horas": t.horas,
                    "plan_end": t.plan_end, "origem": t.origem,
                    "ticket": t.ticket,
                }
                for t in sorted(backlog, key=chave_prioridade)
            ],
            "resumo": {
                "capacidade_h": round(sum(d.capacidade for d in dias) / 60, 2),
                "alocado_h": round(sum(d.ocupado for d in dias) / 60, 2),
                "tarefas_alocadas": len({
                    t.code for d in dias for t in d.alocacao.values() if t
                }),
                "tarefas_backlog": len(backlog),
            },
        }
        sidecar.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8")
        print(f"  gravado: {sidecar}")

    print("\n  Próximos passos sugeridos:")
    print("    ./tools/glpi/bin/glpi-node-upsert --from=<sidecar.json> --plan-only")
    print("    ./tools/glpi/bin/glpi-tree-validate --remote --project-code=<CODE>")
    print()
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n  interrompido pelo usuário.", file=sys.stderr)
        sys.exit(130)
# =============================================================================
#  FIM DE glpi-weekly-sheet.py
# =============================================================================