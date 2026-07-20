# Hierarquia plano ↔ GLPI (SAMU)

> Refatoração: **S** = tarefa pai · **P** = subtarefa filho.  
> Data: 20/07/2026.

---

## Relação entre entidades

| Entidade | Ambiente | Documentação | Nível | Ação |
|----------|----------|--------------|-------|------|
| **VSCode / Agente IA** | Projeto (Win ou WSL) | Plano / checklist / todolist | **Fase/semana (S)** → **Item (P)** | Finalização de tarefa |
| **Git** (GitHub / Gitness) | Repositório | Markdown e/ou histórico | — | Commit (push) / pull |
| **GLPI** | Projeto | Lista de tarefas do projeto | **Tarefa (pai)** → **Subtarefa (filho)** | Cria / atualiza tarefa |

### Mapeamento canônico

| Plano local | Código | GLPI `ProjectTask` | Campo vínculo |
|-------------|--------|--------------------|---------------|
| Fase / semana | `S0` … `S7` (ex.: `S4`) | Tarefa **pai** | `projects_id` = Project 72 |
| Item da fase | `S4.P1`, `S4.P2`… | Tarefa **filho** (subtarefa) | `projecttasks_id` = id do pai `S4` |

Campos temporais e progresso no `PLANO_IMPLEMENTACAO.md` (por fase e por item):

| Plano | GLPI |
|-------|------|
| `%` | `percent_done` |
| `GEP` | `projectstates_id` |
| `Plan ini` / `Plan fim` | `plan_start_date` / `plan_end_date` |
| `Real ini` / `Real fim` | `real_start_date` / `real_end_date` |
| `Critério` | trecho de `content` |

```text
Project 72
├── [pai]  S0  Scaffold e infra
│     ├── [filho] S0.P1  Monorepo npm workspaces
│     └── [filho] S0.P2  Docker compose …
├── [pai]  S1  MVP TARM + Monitor
│     └── …
└── [pai]  S4  Unidade móvel + GPS MVP
      ├── [filho] S4.P1  App mobile autenticação …
      └── [filho] S4.P5  Fila offline sync
```

### Fluxo da informação

```text
PLANO_IMPLEMENTACAO.md
  ## Fase 4 … (S4)          ──► ProjectTask pai  code=S4
  | Item | [ ] | … |         ──► ProjectTask filho code=S4.Pn  parent=S4
        │
        ▼
   git commit/push           ──► evidência (sha) + ITILFollowup no Ticket
        │
        ▼
   glpi-task-upsert          ──► atualiza pai e/ou filho (estado GEP, %)
```

---

## Skills (hierarquia)

| Skill | Papel na hierarquia |
|-------|---------------------|
| `glpi-project-create` | Cria o **Project** (quando novo) |
| `glpi-retro-scan` | Gera candidatos **S (pai)** e **P (filho)** a partir do markdown |
| `glpi-task-upsert` | Cria/atualiza pai (`--code=S4`) ou filho (`--code=S4.P1 --parent-code=S4`) |
| `glpi-followup` | Evidência no **Ticket** (não substitui subtarefa) |
| `seed-phases` | Template legado Discovery→Evolução **ou** `samu-s-phases` (pais S0–S7) |

### Convenção de códigos

- Pai: `S{n}` — `S0`, `S1`, … `S7`
- Filho: `S{n}.P{m}` — `S4.P1`, `S4.P2` (ordem da tabela no plano)
- Sub-item explícito no texto (`S1.5`) pode virar filho `S1.P…` ou código documentado no state

---

## Estado local

Arquivo `.glpi/state-project-72.json`:

```json
{
  "tasks": [
    { "id": 900, "code": "S4", "name": "S4 — Unidade móvel", "kind": "phase" },
    { "id": 901, "code": "S4.P5", "name": "Fila offline sync", "kind": "item", "parent_code": "S4", "parent_id": 900 }
  ]
}
```

---

## CLI

```bash
# Wrappers diretos (preferidos; skills os chamam)
./tools/glpi/bin/glpi-seed-phases --template=samu-s-phases
./tools/glpi/bin/glpi-retro-scan
./tools/glpi/bin/glpi-retro-apply --from=docs/06_glpi/retro-scans/ARQUIVO.json
./tools/glpi/bin/glpi-task-upsert --code=S4 --name="S4 — Unidade móvel" --state=gep3 --percent=60
./tools/glpi/bin/glpi-task-upsert --code=S4.P5 --parent-code=S4 --name="Fila offline sync" --state=gep1 --percent=0 --apply
```

### Fluxo lote (após revisão do relatório)

1. `glpi-retro-scan` — gera JSON (dedupe por `code` S/P)
2. Revisar NEW/SKIP no `.md`
3. `glpi-retro-apply --from=JSON` (dry-run) → `--apply` se ok

---

## Nota sobre template `corporate-phases`

Discovery → Evolução permanece como template **corporativo opcional** (fases de gestão PMF).  
A hierarquia operacional SAMU do plano é **S/P** (`samu-s-phases` + itens do `PLANO_IMPLEMENTACAO.md`).
