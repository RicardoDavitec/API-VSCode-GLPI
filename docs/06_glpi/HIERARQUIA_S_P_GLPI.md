# Hierarquia plano ↔ GLPI (S / P)

> Convenção do **pmf-dev-kit**: **S** = tarefa pai · **P** = subtarefa filho.  
> Data: 21/07/2026.

Exemplos de código (`S4`, Project 72) vêm do produto histórico SIGS-Samu; adapte ao `project_id` e ao plano do seu produto.

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
| Fase / semana | `S0` … `Sn` (ex.: `S4`) | Tarefa **pai** | `projects_id` = Project do `project.yaml` |
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
Project <project_id>
├── [pai]  S0  …
│     ├── [filho] S0.P1  …
│     └── [filho] S0.P2  …
├── [pai]  S1  …
│     └── …
└── [pai]  S4  …
      ├── [filho] S4.P1  …
      └── [filho] S4.P5  …
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
| `seed-phases` | Template `corporate-phases` **ou** fases S (exemplo `product-s-phases.example.json`) |

### Convenção de códigos

- Pai: `S{n}` — `S0`, `S1`, … `Sn`
- Filho: `S{n}.P{m}` — `S4.P1`, `S4.P2` (ordem da tabela no plano)
- Sub-item explícito no texto (`S1.5`) pode virar filho `S1.P…` ou código documentado no state

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
./tools/glpi/bin/glpi-retro-apply --from=docs/06_glpi/retro-scans/ARQUIVO.json
./tools/glpi/bin/glpi-task-upsert --code=S4 --name="S4 — …" --state=gep3 --percent=60
./tools/glpi/bin/glpi-task-upsert --code=S4.P5 --parent-code=S4 --name="…" --state=gep1 --percent=0 --apply
```

### Fluxo lote (após revisão do relatório)

1. `glpi-retro-scan` — gera JSON (dedupe por `code` S/P)
2. Revisar NEW/SKIP no `.md`
3. `glpi-retro-apply --from=JSON` (dry-run) → `--apply` se ok

---

## Nota sobre template `corporate-phases`

Discovery → Evolução permanece como template **corporativo padrão** do kit (fases de gestão PMF).  
A hierarquia operacional por plano é **S/P** (adaptar o exemplo `product-s-phases.example.json` + itens do `PLANO_IMPLEMENTACAO.md`).

Integração completa: [`MANUAL_INTEGRACAO_GLPI.md`](MANUAL_INTEGRACAO_GLPI.md).
