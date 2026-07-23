# Hierarquia plano ↔ GLPI (S / P / átomo)

> Convenção do **pmf-dev-kit**: **S** = fase (pai) · **P** = pacote ~2h (filho) · **átomo** = evidência só no `content`.  
> Data: 23/07/2026.

Exemplos de código (`S4`, Project 72) vêm do produto histórico SIGS-Samu; adapte ao `project_id` e ao plano do seu produto.

---

## Relação entre entidades

| Entidade | Ambiente | Documentação | Nível | Ação |
|----------|----------|--------------|-------|------|
| **VSCode / Agente IA** | Projeto (Win ou WSL) | Plano / checklist / todolist | **Fase (S)** → **Pacote (P)** → átomos | Finalização de pacote |
| **Git** (GitHub / Gitness) | Repositório | Markdown e/ou histórico | — | Commit (push) / pull |
| **GLPI** | Projeto | Lista de tarefas do projeto | **Tarefa (pai)** → **Subtarefa (filho)** | Cria / atualiza fase ou pacote |

### Três níveis (canônico)

```text
Project <project_id>
├── [S] Fase / módulo          code=S4  ou  M.BACKEND
│     ├── [P] Pacote ~2h       code=S4.P1  (ProjectTask filho)
│     │     └── átomos         somente em content (checklist + fontes)
│     └── [P] Pacote ~2h       code=S4.P2
└── …
```

| Nível | Código | GLPI `ProjectTask` | Onde vive o detalhe |
|-------|--------|--------------------|---------------------|
| Fase (S) | `S0`…`Sn` ou `M.BACKEND` | Tarefa **pai** | título + datas agregadas |
| Pacote (P) | `S4.P1`, `M.WEB.P3` | Tarefa **filho** | `content` com átomos |
| Átomo | — | **não** cria ProjectTask | bullet no `content` do pacote |

O `glpi-retro-scan --pack` agrupa linhas de checklist/commits em pacotes com alvo default **120 min**, priorizando **módulo** (`backend`, `web`, `mobile`, `infra`, `postgresql`, `docs`, `geral`).

Campos temporais e progresso no `PLANO_IMPLEMENTACAO.md` (por fase e por item):

| Plano | GLPI |
|-------|------|
| `%` | `percent_done` |
| `GEP` | `projectstates_id` |
| `Plan ini` / `Plan fim` | `plan_start_date` / `plan_end_date` |
| `Real ini` / `Real fim` | `real_start_date` / `real_end_date` |
| `Critério` / átomos | trecho de `content` |

### Fluxo da informação

```text
PLANO / checklist / commits
  ## Fase 4 … (S4)          ──► ProjectTask pai  code=S4
  bullets / itens curtos    ──► empacotados em S4.Pn (~2h)
        │                         átomos → content do pacote
        ▼
   git commit/push           ──► evidência (sha) + ITILFollowup no Ticket
        │
        ▼
   glpi-task-upsert          ──► atualiza fase e/ou pacote (estado GEP, %)
```

---

## Skills (hierarquia)

| Skill | Papel na hierarquia |
|-------|---------------------|
| `glpi-project-create` | Cria o **Project** (quando novo) |
| `glpi-retro-scan` | Gera candidatos **S** / **P** (com `--pack`: pacotes + átomos no content) |
| `glpi-task-upsert` | Cria/atualiza pai (`--code=S4`) ou pacote (`--code=S4.P1 --parent-code=S4`) |
| `acompanhar-chamado` | Evidência no **Ticket** (não substitui pacote); alias legado `glpi-followup` |
| `seed-phases` | Template `corporate-phases` **ou** fases S (exemplo `product-s-phases.example.json`) |

### Convenção de códigos

- Pai: `S{n}` — `S0`, `S1`, … `Sn` (ou fase de módulo `M.BACKEND`, `M.WEB`, …)
- Filho (pacote): `S{n}.P{m}` (átomo único com código estável) ou `S{n}.PKG{m}` (pacote multi-átomo)
- Átomo: sem ProjectTask próprio; listado no `content`

### Titulação (ProjectTask e cabeçalho de acompanhamento)

```text
{Modulo} - {Fase|esporadico} [- {Pacote}] - {Acao concreta}
```

Exemplos: `Web - F1 - P2 - Criacao CRUD Usuario` · `Geral - esporadico - Benchmark fluxo panico` · `Mobile - Build APK V2.09 R23 - GPS integrado`.

Proibido: proximos passos, checklists, documentacao, fase de implementacao (genericos).

No Ticket, a skill `acompanhar-chamado` usa esse padrao como **primeira linha** do `ITILFollowup` (sugere, pergunta edicao, default = sugestao).

### Empacotamento (`--pack`)

| Param / env | Default | Papel |
|-------------|---------|--------|
| `--pack` / `GLPI_RETRO_PACK_MODE=on` | off | Liga 3 níveis |
| `--pack-target-min` / `GLPI_RETRO_PACK_TARGET_MIN` | 120 | Alvo de minutos por pacote |
| `--pack-gap-min` / `GLPI_RETRO_PACK_GAP_MIN` | 45 | Gap máximo entre átomos no mesmo pacote |

Artefato com pack: `docs/06_glpi/retro-scans/YYYY-MM-DD_HHMM_<bundle>_pack.json` (preserva scans sem `_pack`).

---

## Estado local

Arquivo `.glpi/state-project-<id>.json`:

```json
{
  "tasks": [
    { "id": 900, "code": "S4", "name": "S4 — …", "kind": "phase" },
    { "id": 901, "code": "S4.P5", "name": "…", "kind": "item", "parent_code": "S4", "parent_id": 900 }
  ]
}
```

---

## CLI

```bash
# Wrappers diretos (preferidos; skills os chamam)
./tools/glpi/bin/glpi-seed-phases --template=corporate-phases
./tools/glpi/bin/glpi-retro-scan
./tools/glpi/bin/glpi-retro-scan --pack --pack-target-min=120
./tools/glpi/bin/glpi-retro-apply --from=docs/06_glpi/retro-scans/ARQUIVO_pack.json
./tools/glpi/bin/glpi-task-upsert --code=S4 --name="S4 — …" --state=gep3 --percent=60
./tools/glpi/bin/glpi-task-upsert --code=S4.P5 --parent-code=S4 --name="…" --state=gep1 --percent=0 --apply
```

### Fluxo lote (após revisão do relatório)

1. `glpi-retro-scan --pack` — gera JSON (fases + pacotes; átomos em `atoms_detail` + `content`)
2. Revisar NEW/SKIP e tabela por módulo no `.md`
3. `glpi-retro-apply --from=JSON` (dry-run) → `--apply` se ok

---

## Nota sobre template `corporate-phases`

Discovery → Evolução permanece como template **corporativo padrão** do kit (fases de gestão PMF).  
A hierarquia operacional por plano é **S / P / átomo** (adaptar o exemplo `product-s-phases.example.json` + itens do plano).

Integração completa: [`MANUAL_INTEGRACAO_GLPI.md`](MANUAL_INTEGRACAO_GLPI.md).
