# Reavaliação — Integração VSCode / Git / GLPI

> Base: `Integração SKILLs IA entre Projeto - GLPI.txt` (estrutura de campos GLPI + relação de entidades).  
> Cruza com o MVP implementado (`tools/glpi`, `glpi-followup`, `.glpi/*`).  
> Data: 20/07/2026.

---

## 1. O que o documento de requisitos pede

### 1.1 Estrutura GLPI (campos)

**Projeto (`Project`)** — metadados ricos:

| Bloco | Campos (normalizados) |
|-------|------------------------|
| Identidade | Data criação, última atualização, Nome, Código, Prioridade, Filho de, Estado, % finalizado, Tipo |
| Gerente | Usuário, Grupo |
| Planejamento | Data início/fim planejados, duração planejada |
| Real | Data início/fim reais, duração efetiva |
| Texto | Descrição, Comentários |

**Estados** incluem fila operacional clássica **e** estados GEP (1 Produto Backlog … 9 Fechado, Impedimento, etc.).

**Tarefa do projeto (`ProjectTask`)**:

| Bloco | Campos |
|-------|--------|
| Vínculos | Projeto, Filho de (hierarquia), Modelo de tarefa, Pai |
| Identidade | Nome, Tipo, Estado, % finalizado, Marco (sim/não), Equipe |
| Planejamento / Real | Datas e durações |
| Detalhes | Descrição, Comentários |

### 1.2 Relação de entidades (visão alvo)

| Entidade | Ambiente | Documentação | Ação |
|----------|----------|--------------|------|
| **VSCode / Agente IA** | Projeto (Win ou WSL) | Plano / checklist / todolist | Finaliza tarefa |
| **Git** (GitHub / Gitness) | Repositório | Markdown e/ou histórico CVS | Commit (push) / pull |
| **GLPI** | Projeto | Lista de tarefas do projeto | Cria / atualiza tarefa |

### 1.3 Skills exigidos pelo documento

1. **Gerar projeto no GLPI** (quando projeto novo) — preencher campos da estrutura.
2. **Gerar lista de tarefas** a partir de markdown / checklist / todolist (retroativo, mono ou polyrepo).
3. **Atualizar tarefas** manualmente e automaticamente (fim de tarefa e/ou commits/push).
4. **Planos/checklists/todolists** devem **conter os campos GLPI pertinentes** (fonte alinhada ao destino).

---

## 2. O que existe hoje (MVP)

```text
VSCode/Cursor ──skills──► git commit/push (exporte)
       │
       └──glpi-followup──► Ticket 10554 (ITILFollowup)
                              ▲
CLI seed-phases ──► Project 72 + ProjectTasks 800–805 (só nome/%/content)
```

| Capacidade | Status |
|------------|--------|
| Auth API + ticket get/followup | Feito |
| Project get + list tasks | Feito (parcial) |
| Seed fases genéricas Discovery→Evolução | Feito |
| Criar Project completo (código, prioridade, estado GEP, gerente, datas) | **Não** |
| Criar/atualizar ProjectTask com estado GEP, datas, marco, equipe, pai | **Não** |
| Retro-scan markdown → tasks | Config `workspace.yaml` só; scanner **não** |
| Sync automático no push/CI | **Não** |
| Planos markdown com campos GLPI | **Não** (plano usa `[ ]/[x]` S0–S7) |
| Ticket como diário institucional | Feito (`glpi-followup`) |

**Gap principal:** o MVP privilegia o **Ticket (auditoria)**; o documento privilegia o **Project + ProjectTask (gestão de entrega)** com ciclo de vida GEP.

---

## 3. Modelo alvo reavaliado (triângulo VSCode ↔ Git ↔ GLPI)

### 3.1 Papéis claros (não misturar)

| Camada | Fonte de verdade para… | Não deve ser |
|--------|------------------------|--------------|
| **VSCode + docs** | Intenção de trabalho do dia (plano local, checklist) | Sistema de tickets da DTI |
| **Git** | Evidência imutável de código (commit, branch, PR) | Substituto do ProjectTask |
| **GLPI Project/Task** | Status oficial de gestão (estado GEP, %, datas) | Repo de código |
| **GLPI Ticket** | Canal institucional / auditoria para stakeholders | Backlog detalhado de sprint |

### 3.2 Fluxo de informação alvo

```text
┌─ VSCode / Agente ─────────────────────────────────────────┐
│  PLANO / checklist / todolist (campos GLPI embutidos)     │
│  skills: oncoto-oncovo → documentar → build → commit      │
└─────────────┬───────────────────────────────┬─────────────┘
              │ exporte (push)                │ glpi-*
              ▼                               ▼
┌─ Git (Gitness) ─┐                 ┌─ GLPI ──────────────────────┐
│ commit + sha    │── opcional CI ─►│ Project (estado/gerente/%)  │
│ branch/PR       │   glpi-notify   │  └─ ProjectTask (GEP, datas)│
└─────────────────┘                 │ Ticket (follow-up evidência)│
                                    └─────────────────────────────┘
```

**Regra de ouro:**  
- **Fechar tarefa no plano local** ⇒ skill atualiza `ProjectTask` (estado/%/datas reais).  
- **Commit/push** ⇒ evidência no Git **e** follow-up no Ticket (e/ou patch mínimo na task: “última evidência = sha”).  
- **Não** usar só follow-up no Ticket como se fosse gestão de tarefas.

### 3.3 Mapeamento campo a campo (docs → GLPI)

Planos futuros devem expor metadados (YAML frontmatter ou tabela) alinhados à estrutura:

```yaml
# Exemplo em item de plano / task local
glpi:
  project_id: 72          # ou criar novo
  task_code: "S4.P1"      # filho; pai = S4
  parent_code: "S4"       # ProjectTask pai (fase)
  name: "Fila offline sync"
  type: "Desenvolvimento e inovacao TI"
  state: "GEP 3. Fazendo"
  percent_done: 40
  is_milestone: false
  plan_start: "2026-07-20"
  plan_end: "2026-07-27"
  real_start: "2026-07-20"
  team: ["Desenvolvimento > SIGS"]
```

Checklist `[x]` sozinho **não basta** para preencher Estado GEP, datas e gerente.

### 3.4 Skills alvo (reavaliação)

| Skill (proposto) | Gatilho | Ação GLPI | Prioridade |
|------------------|---------|-----------|------------|
| `glpi-project-create` | Projeto novo | POST `Project` com campos da estrutura | P1 |
| `glpi-retro-scan` | Inventário / onboarding | Lê planos/commits (workspace) → candidatos ProjectTask | P1 |
| `glpi-task-upsert` | Fim de item / sync | Cria/atualiza ProjectTask (estado, %, datas, pai) | P0 |
| `glpi-followup` | Checkpoint / push | ITILFollowup no Ticket (já existe) | Feito |
| `glpi-sync-plano` | Após editar PLANO_*.md | Diff checklist ↔ ProjectTasks | P1 |
| Extensão `exporte` / CI | Push bem-sucedido | follow-up + opcional bump % task | P2 |
| Extensão `encerrar-sessao` | Fim do dia | Resumo → follow-up + tasks tocadas | P2 |

CLI deve evoluir além de `seed-phases`/`followup`:

```text
glpi project create|patch
glpi task get|create|patch   # ProjectTask com campos GEP
glpi retro-scan [--apply]
glpi sync-plano [--apply]
```

---

## 4. Alinhamento com o que já temos (não jogar fora)

| Manter | Motivo |
|--------|--------|
| Ticket 10554 + `glpi-followup` | Auditoria institucional (DTI) |
| Project 72 + tasks 800–805 | Base de fases; evoluir campos, não recriar às cegas |
| `.glpi/project.yaml` + secrets | Config por repo |
| `workspace.yaml` | Base do retro-scan polyrepo |
| `corporate-phases` | Template inicial; enriquecer com estado/tipo/datas padrão |
| Separação tools ≠ apps/backend | Continua válida |

| Ajustar | Para |
|---------|------|
| Foco “só follow-up no Ticket” | Dual: **Task = gestão**, **Follow-up = evidência** |
| Seed só `name/content/%` | Payload completo (estado, datas, marco, pai) |
| Plano S0–S7 sem metadados GLPI | Frontmatter / tabela por item |
| Skills só git (`exporte`) | Gatilho GLPI no fechamento de tarefa e no push |

---

## 5. Fluxo operacional recomendado (dia a dia)

1. **`oncoto-oncovo`** — “onde estou” no plano (e, se houver, estado GEP da ProjectTask).
2. Implementar / validar (`build-*`).
3. **`documentar`** — marcar item no plano **e** preencher campos GLPI do item.
4. **`glpi-task-upsert`** — atualiza ProjectTask (estado → GEP 4 Testando / % / real_end se fechou).
5. **`commit` + `exporte`** — evidência no Git.
6. **`glpi-followup`** — uma linha no Ticket: fase + sha + próximo.
7. Checkbox *follow-up GLPI* + (futuro) *ProjectTask atualizada?*.

Retroativo (uma vez / sob demanda):

1. `glpi-retro-scan` dry-run sobre `workspace.yaml`.
2. Revisão humana.
3. `--apply` → ProjectTasks.
4. Opcional: `glpi-project-create` só se não existir Project.

---

## 6. Riscos e governança

| Risco | Mitigação |
|-------|-----------|
| Gravar demais no GLPI de produção | Dry-run padrão; sandbox; confirmação em `--apply` |
| Estados GEP vs IDs internos GLPI | Mapear `projectstates_id` via API (`listSearchOptions` / dropdown) em `.glpi/maps/states.yaml` |
| Divergência plano local × GLPI | `glpi-sync-plano` + auditoria semanal |
| Polyrepo com tarefas duplicadas | Dedup por `task_code` + `workspace` weights |
| Encoding/ruído em docs `.txt`/`.odt` | Preferir markdown UTF-8 em `docs/06_glpi/` (este arquivo) |

---

## 7. Conclusão da reavaliação

O texto de requisitos define a integração correta como um **triângulo**:

- **VSCode/Agente** decide e documenta (plano com campos GLPI).
- **Git** prova a mudança (commit/push).
- **GLPI Project/Task** oficializa gestão (estado GEP, %, datas, hierarquia).
- **GLPI Ticket** permanece canal de **auditoria**, não o backlog.

O MVP atual cobre bem o **eixo Git ↔ Ticket (follow-up)** e um **seed mínimo de ProjectTasks**.  
Para cumprir o documento, o próximo salto é o **eixo Plano ↔ ProjectTask** (criar/atualizar com a estrutura completa) + **retro-scan** + **gatilhos no fim de tarefa e no push**.

### Prioridade sugerida

1. ~~P0 — CLI `task patch/create` + skill `glpi-task-upsert`~~ **Feito (20/07/2026)**
2. ~~P1 — Mapa estados GEP + `corporate-phases` enriquecido~~ **Feito (parcial: gep2/5/6/8 sem ID na amostra API)**
3. ~~P1 — `glpi-retro-scan` dry-run~~ **Feito**
4. ~~P1 — `glpi-project-create`~~ **Feito (dry-run/apply)**
5. P2 — Hook em `exporte`/CI + campos GLPI no `PLANO_IMPLEMENTACAO`
6. P2 — Completar IDs `gep2/5/6/8` quando aparecerem no GLPI UI
7. P2 — `retro-scan --apply` criando ProjectTasks automaticamente apos revisao

### P1 — como usar

```bash
./tools/glpi/glpi project create --name="Novo" --code=X --state=gep1
./tools/glpi/glpi retro-scan
# relatorio: docs/06_glpi/retro-scans/
./tools/glpi/glpi seed-phases   # template com state/% enriquecidos
```

Skills: `glpi-project-create`, `glpi-retro-scan`

---

## Referências

- Requisitos: `docs/06_glpi/Integração SKILLs IA entre  Projeto - GLPI.txt`
- Manual MVP: `docs/06_glpi/MANUAL_USO_GLPI.md`
- Visão: `docs/06_glpi/INTEGRACAO_GLPI_GESTAO_PROJETOS.md`
- Config: `.glpi/project.yaml`, `workspace.yaml`, `templates/corporate-phases.*`
