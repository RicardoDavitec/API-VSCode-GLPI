# Manual de uso — Integração GLPI (CLI e operação)

> Guia operacional do CLI, configs, secrets, skills e conceitos GLPI.  
> **Integração passo a passo (bootstrap, WSL/Windows):** [`MANUAL_INTEGRACAO_GLPI.md`](MANUAL_INTEGRACAO_GLPI.md)  
> Complementa: [`INTEGRACAO_GLPI_GESTAO_PROJETOS.md`](INTEGRACAO_GLPI_GESTAO_PROJETOS.md) (visão) e [`GLPI-rest-API-documentationmd`](GLPI-rest-API-documentationmd) (API raw).

**Fonte:** [pmf-dev-kit](https://gitness.franca.sp.gov.br/PMF-Integracao_GLPI/pmf-dev-kit)  
**Última atualização:** 21/07/2026  
**Escopo:** gestão de projeto / auditoria institucional — **fora** do domínio de negócio da aplicação do produto.

Os IDs Ticket/Project abaixo usam o exemplo histórico **SIGS-Samu** (10554 / 72). Em cada produto, use os valores de `.glpi/project.yaml`.

---

## Sumário

1. [Visão do fluxo](#1-visão-do-fluxo)
2. [Conceitos GLPI (projeto, chamado, tarefas)](#2-conceitos-glpi-projeto-chamado-tarefas)
3. [Arquivos de configuração (`.glpi/`)](#3-arquivos-de-configuração-glpi)
4. [Autenticação e secrets](#4-autenticação-e-secrets)
5. [Variáveis de ambiente](#5-variáveis-de-ambiente)
6. [CLI `tools/glpi/glpi`](#6-cli-toolsglpiglpi)
7. [Skills relacionados](#7-skills-relacionados)
8. [Fluxos do dia a dia](#8-fluxos-do-dia-a-dia)
9. [Testes sem comprometer o GLPI](#9-testes-sem-comprometer-o-glpi)
10. [Troubleshooting](#10-troubleshooting)
11. [Inventário de exemplo (IDs)](#11-inventário-de-exemplo-ids)
12. [Roadmap](#12-roadmap)

---

## 1. Visão do fluxo

```text
┌─────────────────────────────────────────────────────────────────┐
│  Desenvolvimento local (git, plano, CI)                         │
│  PLANO_IMPLEMENTACAO.md · commits · exporte/importe             │
│  (artefatos vendorizados a partir do pmf-dev-kit)               │
└────────────────────────────┬────────────────────────────────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
     skill glpi-followup   CLI glpi    (futuro CI)
              │              │
              └──────┬───────┘
                     ▼
         ~/.secrets + .glpi/project.yaml
                     │
                     ▼
              initSession (API)
                     │
         ┌───────────┼───────────┐
         ▼           ▼           ▼
      Ticket     Project    ProjectTask
     (chamado)  (projeto)   (tarefas)
     follow-up   get/list    seed/list
```

### Ciclo típico de entrega

1. Trabalhar no item do plano (ex.: S4, S1.P1).
2. Validar localmente (build/health).
3. Commit + push (`commit` / `exporte`).
4. Registrar evidência no chamado: `glpi-followup` → `ITILFollowup` no Ticket do `project.yaml`.
5. (Opcional) Atualizar % / status da `ProjectTask` (`glpi-task-upsert` ou UI).
6. Marcar checkbox *follow-up GLPI enviado?* no checklist de commit (quando existir).

### Separação de responsabilidades

| Camada | Onde | O quê |
|--------|------|--------|
| Produto (domínio) | `apps/*`, código do negócio | Funcionalidade do sistema |
| Gestão / auditoria | `tools/glpi`, `.glpi/`, skills | Ticket + Project no suporte.franca |
| Kit fonte | `pmf-dev-kit` | Bootstrap / upgrade das ferramentas |
| Secrets | `~/.secrets/` (máquina) | Tokens — **nunca** no git |

---

## 2. Conceitos GLPI (projeto, chamado, tarefas)

No GLPI da Prefeitura, três conceitos se complementam (não são a mesma coisa):

### 2.1 Projeto (`Project`) — container de entrega

- **O que é:** objeto de gestão de projeto (escopo, % global, datas).
- **Config:** `project_id` em `.glpi/project.yaml` (ex. histórico Samu: **72**).
- **Para que serve:** agrupar fases/tarefas de implementação; visão gerencial do produto.
- **API:** `GET/POST /Project/`, `GET /Project/:id`.

### 2.2 Chamado / Ticket (`Ticket`) — canal institucional

- **O que é:** chamado de suporte/atendimento (ITIL), com requerente, técnico, status, timeline.
- **Config:** `ticket_id` em `.glpi/project.yaml` (ex. histórico Samu: **10554**).
- **Para que serve:** auditoria oficial perante a DTI/suporte; histórico legível por gestores; follow-ups.
- **API:** `GET /Ticket/:id`, follow-ups via `POST /ITILFollowup/`.

Relação prática: o **Ticket** é o “processo administrativo”; o **Project** é o “plano de entrega”. Podem coexistir sem vínculo automático obrigatório na API — o vínculo é feito pela **config do repositório** (`.glpi/project.yaml`).

### 2.3 Tarefas de projeto (`ProjectTask`) — fases (S) / itens (P)

- **O que é:** tarefa **dentro de um Project** (nome, %, conteúdo, datas, pai).
- **Hierarquia operacional (padrão kit):**
  - **S** (fase/semana) = tarefa **pai** (`code=S4`)
  - **P** (item) = **subtarefa** (`code=S4.P1`, `projecttasks_id` = id do pai)
- **Templates:** `corporate-phases` (Discovery→Evolução) ou fases S0–Sn (exemplo em `product-s-phases.example.json`). Ver `HIERARQUIA_S_P_GLPI.md`.
- **API:** `POST /ProjectTask/`, `GET /ProjectTask/:id` (campo `projecttasks_id` = pai).

> Não confundir com **TicketTask** (tarefa *do chamado*). O MVP atual trabalha com **ProjectTask** + **ITILFollowup** no Ticket.

### 2.4 Follow-up (`ITILFollowup`) — diário no chamado

- Comentário/atualização na timeline do Ticket.
- Usado pelo skill/CLI para registrar checkpoints, deploys, resumos de sessão.
- **Não** altera sozinho o % das ProjectTasks.

### 2.5 Fluxo da informação (resumo)

```text
PLANO_IMPLEMENTACAO (repo)
  ## Fase 4 (S4)     ──► ProjectTask pai   code=S4
  | Item | [ ] | … | ──► ProjectTask filho code=S4.Pn  parent=S4
        │
        ▼
   git commit/push   ──► evidência (sha)
        │
        ▼
   glpi-task-upsert ──► atualiza pai e/ou filho
        │
Ticket (ticket_id) ←── ITILFollowup (canal oficial)
Project (project_id) ←── container das ProjectTasks
```

Mapa entidades: VSCode (S→P) · Git (commit) · GLPI (pai→filho). Detalhe em `HIERARQUIA_S_P_GLPI.md`.

### 2.6 Mapa evento → GLPI
| Evento local | Onde aparece no GLPI |
|--------------|----------------------|
| Seed de fases | Novas `ProjectTask` no Project configurado |
| Checkpoint / entrega | `ITILFollowup` no Ticket configurado |
| Avanço de fase | `percent_done` / estado da `ProjectTask` (`task upsert`) |
| Encerramento macro | Status do Ticket / % do Project (UI ou API) |

---

## 3. Arquivos de configuração (`.glpi/`)

Tudo sob `.glpi/` é **versionável** (sem secrets).

### 3.0 `instance.yaml` — instância GLPI

| Campo | Função |
|-------|--------|
| `preset` | `api-vscode-glpi` (default PMF) ou `generic` |
| `glpi.api_url` | Base `/apirest.php` |
| `glpi.require_app_token` | `true` na PMF; `false` em instâncias sem App-Token |
| `secrets.format` | `pmf` ou `generic` |

Criado pelo bootstrap ou assistente `install-glpi.sh`.

### 3.1 `project.yaml` — identidade deste repositório

| Campo | Exemplo | Função |
|-------|---------|--------|
| `key` | `meu-produto` | Identificador lógico do produto |
| `ticket_id` | `10554` | Ticket padrão do CLI (`ticket get` / `followup`) |
| `project_id` | `72` | Project padrão (`project get` / `tasks` / `seed-phases`) |
| `phase_template` | `corporate-phases` | Nome do template em `templates/` |
| `followup_private` | `false` | Se `true`, follow-up privado no GLPI |
| `entity_hint` / `location_hint` | texto | Documentação humana (não enviados automaticamente) |

Sobrescreva IDs na linha de comando quando necessário:  
`./tools/glpi/glpi ticket get 99999`

### 3.2 `templates/corporate-phases.json` (+ `.yaml`)

**O que é:** receita das fases Discovery → Evolução para **criar** `ProjectTask`s.

**Para que serve:** padronizar fases de gestão em qualquer produto PMF (campo opcional `samu_map` / mapa S0–Sn no plano).

| Campo da fase | Função |
|---------------|--------|
| `code` | Código curto (`1`, `4.1`…) |
| `name` | Nome da ProjectTask no GLPI |
| `content` | Descrição gravada no GLPI |
| `percent_done` | % inicial (seed) |
| `samu_map` | Ligação documental com fases Sx do plano |

**Uso:** `./tools/glpi/glpi seed-phases` (dry-run) ou `--apply`.

> No Bot_Pan existe template/hierarquia próprios (`botpan-phases`, IDs 12–30). **Não** ficam neste repositório.

### 3.3 `workspace.yaml` — bundle multi-repositório

**O que é:** lista de clones que compõem o programa/produto (polyrepo).

**Para que serve:** bundle polyrepo para `glpi-retro-scan` (planos/commits/branches → candidatos a ProjectTask).

| Campo | Função |
|-------|--------|
| `bundle` | Nome do pacote (ex.: `meu-produto`) |
| `glpi.ticket_id` / `project_id` | Contexto GLPI do bundle |
| `repos[].path` | Caminho absoluto do clone |
| `repos[].role` | `primary` / `module` / … |
| `repos[].weight` | Peso na deduplicação futura |
| `scanners` | Fontes planejadas: plan, checklist, commit… |

**Estado atual:** arquivo de configuração; scanner ainda não implementado no CLI.

### 3.4 `state-project-72.json` — espelho local do seed

**O que é:** JSON com os IDs das `ProjectTask` já criadas no Project 72.

**Para que serve:**

1. Evitar recriar fases no `seed-phases` (SKIP por nome).
2. Permitir `project tasks` listar via `GET /ProjectTask/:id` (a API `Project/72/ProjectTask` pode retornar `[]` nesta instância).

| Campo | Função |
|-------|--------|
| `project_id` | 72 |
| `template` | `corporate-phases` |
| `tasks[].id` | ID GLPI da ProjectTask |
| `tasks[].name` / `code` | Identificação |

Atualizado automaticamente após `seed-phases --apply`. Pode ser commitado (não contém secrets).

---

## 4. Autenticação e secrets

### 4.1 Arquivo padrão

`~/.secrets/GLPI-tokens.txt` — pasta `.secrets` na **raiz do home** (Linux/WSL: `/home/<user>/.secrets/`; Windows: `%USERPROFILE%\.secrets\`). Fora do git.

Setup completo (WSL/Windows): [`MANUAL_INTEGRACAO_GLPI.md`](MANUAL_INTEGRACAO_GLPI.md) §§3–5.

Formato esperado (linhas livres parseadas pelo CLI):

```text
Pessoal API-GLPI: <user_token>
Grupo   API-GLPI: <app_token>
URL-API: https://suporte.franca.sp.gov.br/apirest.php
```

| Label no arquivo | Header HTTP | Papel |
|------------------|-------------|--------|
| Pessoal API-GLPI | `Authorization: user_token …` | Identifica o usuário |
| Grupo API-GLPI | `App-Token: …` | Cliente API (obrigatório na PMF) |
| URL-API | base do CLI | Endpoint legacy `/apirest.php` |

### 4.2 Sequência de sessão

1. `GET /initSession/` → `session_token`
2. Demais chamadas com `Session-Token` + `App-Token`
3. `GET /killSession/` ao terminar (o CLI faz isso via `trap`)

### 4.3 Segurança

- Nunca commitar tokens, `.env` com GLPI, nem dumps de sessão.
- Não colocar dados clínicos / PII sensível em follow-ups.
- Preferir testes só-leitura até haver sandbox ou `--dry-run` no followup.

---

## 5. Variáveis de ambiente

Todas são **opcionais** se o arquivo de secrets + `.glpi/project.yaml` estiverem corretos.

| Variável | Default | Descrição |
|----------|---------|-----------|
| `GLPI_USER_TOKEN` | Pessoal no secrets | Token de usuário |
| `GLPI_APP_TOKEN` | Grupo no secrets | App-Token do cliente API |
| `GLPI_API_URL` | URL do secrets ou `https://suporte.franca.sp.gov.br/apirest.php` | Base da API (sem barra final) |
| `GLPI_SECRETS_FILE` | `$HOME/.secrets/GLPI-tokens.txt` | Caminho do arquivo de tokens |
| `GLPI_PROJECT_FILE` | `<repo>/.glpi/project.yaml` | Config do projeto |
| `GLPI_STATES_FILE` | `<repo>/.glpi/maps/states.json` | Mapa alias→projectstates_id |
| `GLPI_DRY_RUN` | (vazio) | Se `1`, forca dry-run em task create/patch/upsert |

### Exemplos

```bash
# Usar tokens só por env (sem ler o arquivo)
export GLPI_USER_TOKEN='...'
export GLPI_APP_TOKEN='...'
export GLPI_API_URL='https://suporte.franca.sp.gov.br/apirest.php'
./tools/glpi/glpi auth

# Secrets em outro path
export GLPI_SECRETS_FILE="$HOME/.secrets/GLPI-tokens-homolog.txt"
./tools/glpi/glpi ticket get
```

---

## 6. CLI `tools/glpi/glpi`

### 6.1 Pré-requisitos

- `bash`, `curl`, `jq`
- Secrets válidos (arquivo ou env)
- Executar **da raiz do repositório** (ou path absoluto para o script)

```bash
chmod +x tools/glpi/glpi   # se necessário
./tools/glpi/glpi --help
```

### 6.2 Comandos

#### `auth`

Testa credenciais e imprime `session_token` + URL (sessão encerrada ao sair).

```bash
./tools/glpi/glpi auth
```

#### `ticket get [id]`

Obtém o chamado. Sem `id`, usa `ticket_id` do `project.yaml`.

```bash
./tools/glpi/glpi ticket get
./tools/glpi/glpi ticket get 10554
```

#### `ticket followup [id] <texto|->`

Cria `ITILFollowup` no Ticket (**grava no GLPI**).

```bash
./tools/glpi/glpi ticket followup - "[S4] GPS validado no A05s. Commit abc1234. Proximo: fila offline."
./tools/glpi/glpi ticket followup 10554 "texto"
echo "texto" | ./tools/glpi/glpi ticket followup - -
```

Resposta típica: `{"id": <followup_id>, "message": ""}`.

#### `project get [id]`

Obtém o Project (default `project_id` do yaml).

```bash
./tools/glpi/glpi project get
./tools/glpi/glpi project get 72
```

#### `project tasks [id]`

Lista ProjectTasks do projeto. Estratégia:

1. Sub-itens `Project/:id/ProjectTask` (pode vir vazio nesta instância)
2. Fallback: IDs em `.glpi/state-project-<id>.json` + `GET` individual
3. Fallback: paginação filtrando `projects_id`

```bash
./tools/glpi/glpi project tasks
```

#### `task get|create|patch|upsert` (P0)

Gerencia `ProjectTask` (gestão de entrega). **Dry-run por padrão**; grava só com `--apply`.

```bash
./tools/glpi/glpi task get 804
./tools/glpi/glpi task patch 804 --percent=40 --state=gep3
./tools/glpi/glpi task patch 804 --percent=100 --state=gep7 --real-end=2026-07-20 --apply
./tools/glpi/glpi task upsert --code=4.2 --percent=25 --state=gep3 --apply
./tools/glpi/glpi task create --name="Nova" --state=gep1 --percent=0 --parent-task=804
```

Aliases de estado: `.glpi/maps/states.json` (`gep1`, `gep3`, `gep4`, `gep7`, `gep9`, …).  
`GLPI_DRY_RUN=1` força dry-run mesmo com `--apply`.  
Skill: `.github/skills/glpi-task-upsert/SKILL.md`.

#### `project create` (P1)

Cria `Project` (dry-run por padrão).

```bash
./tools/glpi/glpi project create --name="Novo produto" --code=COD --state=gep1 --priority=3
./tools/glpi/glpi project create --name="..." --code=... --apply
```

Skill: `.github/skills/glpi-project-create/SKILL.md`.

#### `retro-scan` (P1)

Lê `.glpi/workspace.yaml`, varre planos/checklists/**commits** e gera candidatos **S (pai)** / **P (filho)** em `docs/06_glpi/retro-scans/`.

**Timestamps (v2):** commits no mesmo dia encadeiam `real_start`←commit anterior e `real_end`←commit atual; o 1º do dia usa estimativa (`GLPI_RETRO_ESTIMATE_MINUTES`, default 60). Datas do plano têm prioridade; commits preenchem `null`.

**Status/GEP:** `[x]`→`gep7`, `[~]`→`gep3`, `[ ]`→`gep1`; evidência só de commit → `gep7` (retro).

```bash
./tools/glpi/bin/glpi-retro-scan
./tools/glpi/glpi retro-scan --workspace=.glpi/workspace.yaml
```

#### `retro-apply --from=JSON` (P1)

Aplica o JSON do scan em ordem **pai → filho**. Dry-run por padrão.

```bash
./tools/glpi/bin/glpi-retro-apply --from=docs/06_glpi/retro-scans/ARQUIVO.json
./tools/glpi/bin/glpi-retro-apply --from=... --kinds=phase --limit=8
./tools/glpi/bin/glpi-retro-apply --from=... --apply   # após revisão
```

Skill: `.github/skills/glpi-retro-scan/SKILL.md`.  
Wrappers: `tools/glpi/bin/`.  
Hierarquia: `docs/06_glpi/HIERARQUIA_S_P_GLPI.md`.

#### `states discover [--apply]`

Descobre `ProjectState` via API e gera `.glpi/maps/states.json`.

```bash
./tools/glpi/glpi states discover
./tools/glpi/glpi states discover --apply
./tools/glpi/glpi states discover --preset=api-vscode-glpi --apply
```

Prioridade na v1 da instalação (`install-glpi.sh`). Se a API retornar 403, use o mapa do preset.

#### `seed-phases [project_id] [--apply] [--template=nome]`

Cria **tarefas pai** a partir do template JSON.

| Template | Uso |
|----------|-----|
| `corporate-phases` (default no example) | Pais Discovery→Evolução |
| `samu-s-phases` / fases S (via exemplo `product-s-phases.example.json`) | Pais S0–S7 do plano |

| Modo | Comportamento |
|------|----------------|
| Sem `--apply` (padrão) | **Dry-run**: imprime NEW/SKIP, não grava |
| Com `--apply` | `POST /ProjectTask/` + atualiza `state-project-*.json` |

```bash
./tools/glpi/glpi seed-phases
./tools/glpi/glpi seed-phases --template=samu-s-phases --apply
./tools/glpi/glpi seed-phases 72 --template=corporate-phases --apply
```

Filhos (itens P) vêm do `retro-scan` + `task upsert --code=Sn.Pm --parent-code=Sn`.

---

## 7. Skills relacionados

| Skill | Função | Como usar (frase / gatilho) |
|-------|--------|-----------------------------|
| **`glpi-task-upsert`** | Cria/atualiza pai S / filho P (GEP, %, datas) | “atualize S4.P5 para gep3” |
| **`glpi-project-create`** | Cria Project GLPI | “crie o projeto GLPI em dry-run” |
| **`glpi-retro-scan`** | Candidatos S(pai)/P(filho) do markdown | “rode o retro-scan GLPI” |
| **`glpi-followup`** | Enviar follow-up no Ticket via CLI | “envie follow-up GLPI com o resumo da sessão” |
| **`commit`** | Mensagem padronizada; checklist menciona GLPI | “faça o commit no padrão” |
| **`exporte`** | Status → commit → push do branch ativo | “exporte” / “salve e publique” |
| **`importe`** | Fetch + pull do remoto | “importe” |
| **`atualizar`** | Sync inteligente (pull/push/merge) | “atualize” |
| **`encerrar-sessao`** | Documento `SESSAO_*` + perguntar commit/push | “encerre a sessão” |
| **`documentar`** | Atualizar planos/checklists | “documente o progresso” |
| **`backup`** | Backup compactado (quando existir script) | “faça backup” |

### Skill `glpi-followup` — checklist do agente

1. Montar texto: `[Sx.y] o quê · evidência · próximo`.
2. Rodar `./tools/glpi/glpi ticket followup - "…"`.
3. Confirmar ID do follow-up na resposta.
4. Lembrar checkbox em `FLUXO_COMMIT_CHECKLIST.md`.

Skill: `.github/skills/glpi-followup/SKILL.md`

### Integração com o checklist de commit

Arquivo: `docs/05_progresso/geral/FLUXO_COMMIT_CHECKLIST.md` (quando o perfil bootstrap incluir progresso).

Item: **- [ ] follow-up GLPI enviado?**

Fecha o ciclo: evidência no git **e** no suporte institucional.

---

## 8. Fluxos do dia a dia

### 8.1 Só consulta (seguro)

```bash
./tools/glpi/glpi auth
./tools/glpi/glpi ticket get
./tools/glpi/glpi project get
./tools/glpi/glpi project tasks
./tools/glpi/glpi seed-phases    # dry-run
```

### 8.2 Registrar entrega / checkpoint

```bash
./tools/glpi/glpi ticket followup - "[S4] Validacao GPS USA-01 OK. sha:6247537. Proximo: offline sync."
```

### 8.3 (Re)seed de fases

```bash
./tools/glpi/glpi seed-phases           # ver NEW/SKIP
./tools/glpi/glpi seed-phases --apply    # so se houver NEW e autorizacao
./tools/glpi/glpi project tasks
```

### 8.4 Encerrar sessão com auditoria

1. Skill `encerrar-sessao` → `SESSAO_*.md`
2. Commit/push (`exporte`)
3. Skill `glpi-followup` com resumo do dia (opcional mas recomendado)

---

## 9. Testes sem comprometer o GLPI

| Ação | Grava no GLPI? |
|------|----------------|
| `auth`, `ticket get`, `project get`, `project tasks` | Não |
| `seed-phases` (sem `--apply`) | Não |
| `task create\|patch\|upsert` (sem `--apply`) | Não |
| `seed-phases --apply` | **Sim** (ProjectTasks) |
| `task * --apply` | **Sim** (ProjectTask) |
| `ticket followup` | **Sim** (ITILFollowup) |

Mitigações:

1. Usar apenas comandos de leitura em rotina de teste.
2. Homologação: outro `ticket_id` / `project_id` em yaml temporário ou `GLPI_SECRETS_FILE` de homolog.
3. `followup_private: true` reduz visibilidade, mas **ainda grava**.
4. Futuro: `GLPI_DRY_RUN=1` / `--dry-run` no followup (ainda não implementado).

---

## 10. Troubleshooting

| Sintoma | Causa provável | Ação |
|---------|----------------|------|
| `ERROR_APP_TOKEN_PARAMETERS_MISSING` | Sem App-Token | Conferir `Grupo API-GLPI` ou `GLPI_APP_TOKEN` |
| `ERROR_WRONG_APP_TOKEN_PARAMETER` | App-Token inválido | Trocar: Grupo = App, Pessoal = user |
| `ERROR_GLPI_LOGIN_USER_TOKEN` | user_token errado | Conferir Pessoal |
| `ticket_id nao informado` | yaml sem `ticket_id` | Preencher `.glpi/project.yaml` ou passar ID |
| `project tasks` → `[]` | Sub-API vazia / state ausente | Verificar `state-project-72.json`; recriar state após seed |
| `template nao encontrado` | Nome errado | Conferir `phase_template` e arquivo em `templates/*.json` |
| `estado desconhecido` | Alias ausente no mapa | Usar id numerico ou completar `.glpi/maps/states.json` |
| Follow-up sem permissão | Perfil GLPI | Ajustar perfil/entidade no suporte |

Logs úteis: resposta JSON completa do `curl` (o CLI já imprime via `jq`).

---

## 11. Inventário de exemplo (IDs)

Exemplo histórico **SIGS-Samu** (não são defaults do kit; cada produto configura os seus):

| Tipo | ID | Nome |
|------|-----|------|
| Ticket | 10554 | Samu Operacional |
| Project | 72 | Desenvolvimento PMF SIGS-Samu |
| ProjectTask | 800 | 1. Discovery |
| ProjectTask | 801 | 2. Análise |
| ProjectTask | 802 | 3. Projeto |
| ProjectTask | 803 | 4.1 Implementação Front-end |
| ProjectTask | 804 | 4.2 Implementação Back-end |
| ProjectTask | 805 | 5. Evolução |

UI (exemplo): `https://suporte.franca.sp.gov.br/front/project.form.php?id=72`

---

## 12. Roadmap

| Item | Status |
|------|--------|
| CLI auth / ticket / project / seed | Feito |
| Skill `glpi-followup` | Feito |
| Seed corporate-phases no 72 | Feito |
| CLI `task get/create/patch/upsert` + skill `glpi-task-upsert` | Feito (P0) |
| Mapa estados GEP (`gep1/3/4/7/9`; faltam 2/5/6/8 na amostra) | Parcial (P1) |
| `corporate-phases` com state/% | Feito (P1) |
| `project create` + skill `glpi-project-create` | Feito (P1) |
| `retro-scan` dry-run + skill `glpi-retro-scan` | Feito (P1) |
| `retro-apply` pai→filho + wrappers `bin/` | Feito (P1) |
| `retro-scan --apply` auto-create tasks | Substituído por `retro-apply --apply` |
| `--dry-run` no followup | Pendente |
| CI `glpi-notify` pós-deploy | Pendente |
| Sync contínuo com `PLANO_IMPLEMENTACAO.md` | Pendente |

---

## Referências rápidas

| Recurso | Path |
|---------|------|
| Manual de integração (rosto Gitness) | `docs/06_glpi/MANUAL_INTEGRACAO_GLPI.md` · `README.md` |
| Este manual | `docs/06_glpi/MANUAL_USO_GLPI.md` |
| Visão de integração | `docs/06_glpi/INTEGRACAO_GLPI_GESTAO_PROJETOS.md` |
| API REST (cópia) | `docs/06_glpi/GLPI-rest-API-documentationmd` |
| CLI | `tools/glpi/glpi` |
| Skill follow-up | `.github/skills/glpi-followup/SKILL.md` |
| Checklist commit | `docs/05_progresso/geral/FLUXO_COMMIT_CHECKLIST.md` |
| Plano produto | `docs/05_progresso/geral/PLANO_IMPLEMENTACAO.md` |
| Bootstrap | `scripts/bootstrap-into.sh` |
