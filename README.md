# pmf-dev-kit — Manual de integração GLPI

**Gitness:** [PMF-Integracao_GLPI/pmf-dev-kit](https://gitness.franca.sp.gov.br/PMF-Integracao_GLPI/pmf-dev-kit)  
**Clone:** `https://gitness.franca.sp.gov.br/git/PMF-Integracao_GLPI/pmf-dev-kit.git`  
**Space:** [PMF-Integracao_GLPI](https://gitness.franca.sp.gov.br/spaces/PMF-Integracao_GLPI)  
**API GLPI:** `https://suporte.franca.sp.gov.br/apirest.php`  
**Última atualização:** 21/07/2026  
**Autor:** [Dr. Ricardo David](AUTHORS.md) · **Patrocínio:** PMF — DTI · **Licença:** [MIT](LICENSE)

Repositório **fonte** para integração **GLPI** com qualquer instância compatível com a API REST.  
**Preset default:** `api-vscode-glpi` (triângulo VSCode/Cursor ↔ Git ↔ GLPI).  
**Exemplificação:** equipe PMF Franca — [suporte.franca.sp.gov.br](https://suporte.franca.sp.gov.br/front/login.php).

> Manual em produtos: [`docs/06_glpi/MANUAL_INTEGRACAO_GLPI.md`](docs/06_glpi/MANUAL_INTEGRACAO_GLPI.md)  
> Secrets: `~/.secrets/glpi.env` (preferido) ou legado `GLPI-tokens.txt` — **nunca** neste repositório. Homolog: `glpi --env=homolog` → `suporte-homolog.franca.sp.gov.br`.

### Instalação rápida (assistentes)

```bash
# Interativo (recomendado — equipe PMF)
./scripts/install-glpi.sh

# Flags (CI / automação)
./scripts/install-glpi.sh --target=~/projetos/meu-app --preset=api-vscode-glpi --non-interactive --yes

# Wizard Python (Windows / discover isolado)
python3 scripts/install_glpi.py
python3 scripts/install_glpi.py --discover-only --target=~/projetos/meu-app --yes
```

---

## Sumário

1. [O que é este kit](#1-o-que-é-este-kit)
2. [Presets e generalização](#2-presets-e-generalização)
3. [Pré-requisitos](#3-pré-requisitos)
4. [Secrets e variáveis de acesso](#4-secrets-e-variáveis-de-acesso)
5. [Ambiente Linux / WSL](#5-ambiente-linux--wsl)
6. [Ambiente Windows](#6-ambiente-windows)
7. [Clonar o kit](#7-clonar-o-kit)
8. [Assistentes de instalação](#8-assistentes-de-instalação)
9. [Projeto pré-existente (bootstrap)](#9-projeto-pré-existente-bootstrap)
10. [Projeto novo](#10-projeto-novo)
11. [Configurar o produto (`.glpi/`)](#11-configurar-o-produto-glpi)
12. [Validar e ativar no GLPI](#12-validar-e-ativar-no-glpi)
13. [Uso diário](#13-uso-diário)
14. [Atualizar o kit no projeto](#14-atualizar-o-kit-no-projeto)
15. [Perfis e numeração de docs](#15-perfis-e-numeração-de-docs)
16. [Troubleshooting](#16-troubleshooting)
17. [Referências](#17-referências)
18. [Autoria e publicação](#autoria-e-publicação)

---

## 1. O que é este kit

| Artefato | Função |
|----------|--------|
| `tools/glpi/` | CLI + wrappers (`bin/glpi-*`) para API REST do GLPI |
| `.glpi/` | Config do produto (sem secrets) + templates de fases |
| `.github/skills/acompanhar-chamado` (+ `glpi-*`) | Skills Cursor (acompanhamento, upsert, project-create, retro-scan) |
| `docs/06_glpi/` | Documentação da integração |
| `scripts/bootstrap-into.sh` | Aplica o kit em um clone de produto |
| `scripts/install-glpi.sh` | Assistente bash (interativo + flags) |
| `scripts/install_glpi.py` | Assistente Python (wizard + discover) |
| `scripts/upgrade-into.sh` | Atualiza tools/skills/docs sem apagar a config do produto |

Cada projeto **vendoriza** uma cópia local. Não execute o CLI de outro clone.

```text
pmf-dev-kit (fonte)
        │  bootstrap-into / upgrade-into
        ▼
produto-X/                  produto-Y/
  tools/glpi/   (cópia)       tools/glpi/   (cópia)
  .glpi/project.yaml          .glpi/project.yaml
        │                           │
        └───────────┬───────────────┘
                    ▼
         ~/.secrets/GLPI-tokens.txt
                    ▼
    <sua-instancia-glpi>/apirest.php
```

| Camada | Itemtype | Papel |
|--------|----------|--------|
| Institucional | `Ticket` | Canal oficial + `ITILFollowup` |
| Entrega | `Project` + `ProjectTask` | Fases (**S**=pai) e itens (**P**=filho) |
| Diário | `ITILFollowup` | Checkpoints, commits, deploys |

---

## 2. Presets e generalização

| Preset | Uso |
|--------|-----|
| **`api-vscode-glpi`** (default) | Equipe PMF — URL/exemplo [suporte.franca](https://suporte.franca.sp.gov.br/apirest.php), estados GEP, secrets formato `pmf` |
| **`generic`** | Qualquer GLPI — URL informada na instalação, template `generic-phases`, secrets formato `generic` |

Config por produto:

- `.glpi/instance.yaml` — URL, preset, `require_app_token`, formato secrets
- `.glpi/project.yaml` — `ticket_id`, `project_id`, template de fases
- `.glpi/maps/states.json` — aliases de estado (preferir **`glpi states discover --apply`**)

Exemplo PMF em `project.yaml`:

```yaml
ticket_id: 10554   # Samu Operacional
project_id: 72     # Desenvolvimento PMF SIGS-Samu
```

---

## 3. Pré-requisitos

| Ferramenta | Obrigatório | Notas |
|------------|-------------|--------|
| `bash` | Sim | Shell do CLI |
| `curl` | Sim | HTTP |
| `jq` | Sim | Parse JSON |
| `python3` | Sim | Utilitários / retro-scan |
| `rsync` | Sim (bootstrap) | `bootstrap-into.sh` |
| `git` | Sim | Clone / fluxo |
| Cursor | Recomendado | Skills em `.github/skills/` |

**Debian/Ubuntu (WSL incluso):**

```bash
sudo apt update
sudo apt install -y bash curl jq python3 rsync git
```

Também é necessário: conta no GLPI com **user token**; **App-Token** quando `require_app_token: true` (preset PMF); IDs de Ticket/Project ou criá-los na UI/CLI.

---

## 4. Secrets e variáveis de acesso

### 4.1 Onde ficam

| Ambiente | Caminho padrão |
|----------|----------------|
| **Linux / WSL** | `$HOME/.secrets/GLPI-tokens.txt` (ex.: `/home/wsl/.secrets/GLPI-tokens.txt`) |
| **Windows (nativo)** | `%USERPROFILE%\.secrets\GLPI-tokens.txt` |
| Override | `GLPI_SECRETS_FILE` = path absoluto |

A pasta `.secrets` fica na **raiz do home** (`~/.secrets`), **fora** de qualquer repositório.

### 4.2 Formato `GLPI-tokens.txt`

**Preset PMF (`format: pmf`):**

```text
Pessoal API-GLPI: <SEU_USER_TOKEN>
Grupo   API-GLPI: <SEU_APP_TOKEN>
URL-API: https://suporte.franca.sp.gov.br/apirest.php
```

**Preset generic:**

```text
USER_TOKEN: <token>
APP_TOKEN: <opcional>
API_URL: https://seu-glpi/apirest.php
```

| Label | Header HTTP | Papel |
|-------|-------------|--------|
| `Pessoal API-GLPI` | `Authorization: user_token …` | Usuário |
| `Grupo API-GLPI` | `App-Token: …` | Cliente API (obrigatório na PMF) |
| `URL-API` | base do CLI | `/apirest.php` |

**Como obter:** Preferências do usuário no GLPI → token pessoal; App-Token com o administrador da API.

### 4.3 Variáveis de ambiente (opcionais)

| Variável | Default | Descrição |
|----------|---------|-----------|
| `GLPI_USER_TOKEN` | Pessoal no secrets | Token de usuário |
| `GLPI_APP_TOKEN` | Grupo no secrets | App-Token |
| `GLPI_API_URL` | URL do secrets | Base da API (sem barra final) |
| `GLPI_SECRETS_FILE` | `$HOME/.secrets/GLPI-tokens.txt` | Path dos tokens |
| `GLPI_PROJECT_FILE` | `<repo>/.glpi/project.yaml` | Config do produto |
| `GLPI_STATES_FILE` | `<repo>/.glpi/maps/states.json` | Alias → estados |
| `GLPI_DRY_RUN` | (vazio) | `1` = força dry-run em tasks |

```bash
export GLPI_USER_TOKEN='...'
export GLPI_APP_TOKEN='...'
export GLPI_API_URL='https://suporte.franca.sp.gov.br/apirest.php'
./tools/glpi/glpi auth
```

**Segurança:** nunca versionar tokens, `.env` com GLPI ou dumps de sessão. Não colocar PII/dados clínicos em follow-ups.

---

## 5. Ambiente Linux / WSL

```bash
mkdir -p ~/.secrets
chmod 700 ~/.secrets
nano ~/.secrets/GLPI-tokens.txt
chmod 600 ~/.secrets/GLPI-tokens.txt

test -f ~/.secrets/GLPI-tokens.txt && echo "OK: secrets presentes"
command -v curl jq python3 rsync git
```

Path no Explorer Windows (arquivo no WSL):

```text
\\wsl.localhost\<Distro>\home\<usuario>\.secrets\GLPI-tokens.txt
```

Convenção de pastas:

```text
/home/<usuario>/projetos/pmf-dev-kit
/home/<usuario>/projetos/<seu-produto>
```

---

## 6. Ambiente Windows

**Recomendado:** WSL2 + Ubuntu — siga a [seção 5](#5-ambiente-linux--wsl) e abra o projeto no Cursor via Remote WSL.

**Nativo (Git Bash)** — só se não houver WSL:

1. Git for Windows + `jq` + `python3` no PATH.
2. `rsync` (MSYS2) **ou** cópia manual das pastas (abaixo).
3. Secrets em `%USERPROFILE%\.secrets\GLPI-tokens.txt`.

```bash
# Git Bash
export GLPI_SECRETS_FILE="/c/Users/<usuario>/.secrets/GLPI-tokens.txt"
./tools/glpi/glpi auth
```

---

## 7. Clonar o kit

```bash
cd ~/projetos
git clone https://gitness.franca.sp.gov.br/git/PMF-Integracao_GLPI/pmf-dev-kit.git
cd pmf-dev-kit
chmod +x scripts/*.sh tools/glpi/glpi tools/glpi/bin/*
```

---

---

## 8. Assistentes de instalação

| Script | Modo | Uso |
|--------|------|-----|
| `scripts/install-glpi.sh` | Interativo + flags | WSL/Linux — fluxo completo |
| `scripts/install_glpi.py` | Wizard Python | Windows / discover isolado |

Fluxo típico (equipe PMF):

```bash
./scripts/install-glpi.sh
# ou
./scripts/install-glpi.sh --target=~/projetos/meu-app --preset=api-vscode-glpi --non-interactive --yes
```

O assistente executa: bootstrap → `glpi auth` → **`glpi states discover --apply`** → seed dry-run → confirma `--apply`.

Flags úteis: `--preset=generic`, `--glpi-url=...`, `--skip-seed`, `--secrets-format=generic`.

---

## 9. Projeto pré-existente (bootstrap)

```bash
./scripts/bootstrap-into.sh /caminho/absoluto/do/produto \
  --profile=pmf-core \
  --key=nome-do-produto \
  --ticket=ID_DO_TICKET \
  --project=ID_DO_PROJECT
```

Exemplos:

```bash
./scripts/bootstrap-into.sh ~/projetos/meu-app --profile=glpi-only --key=meu-app

./scripts/bootstrap-into.sh ~/projetos/meu-app \
  --profile=pmf-core --key=meu-app --ticket=10554 --project=72

./scripts/bootstrap-into.sh ~/projetos/meu-app --profile=full-skeleton --key=meu-app
```

O script copia `tools/glpi`, maps/templates, skills e `docs/06_glpi`; cria `project.yaml` / `workspace.yaml` só se ainda não existirem. Com `--force`, atualiza tools/skills/docs e **preserva** `project.yaml` existente.

### Cópia manual (sem rsync)

```text
kit/tools/glpi/                 →  produto/tools/glpi/
kit/.glpi/maps/                 →  produto/.glpi/maps/
kit/.glpi/templates/            →  produto/.glpi/templates/
kit/.glpi/project.yaml.example  →  produto/.glpi/project.yaml  (editar)
kit/docs/06_glpi/               →  produto/docs/06_glpi/
kit/.github/skills/glpi-*       →  produto/.github/skills/
```

```bash
chmod +x produto/tools/glpi/glpi produto/tools/glpi/bin/*
```

---

## 10. Projeto novo

```bash
mkdir -p ~/projetos/meu-produto && cd ~/projetos/meu-produto
git init

~/projetos/pmf-dev-kit/scripts/bootstrap-into.sh "$(pwd)" \
  --profile=full-skeleton \
  --key=meu-produto
```

Crie Ticket/Project na UI do GLPI **ou**:

```bash
./tools/glpi/bin/glpi-project-create --name="Meu produto" --code=MEU --state=gep1 --priority=3
./tools/glpi/bin/glpi-project-create --name="Meu produto" --code=MEU --state=gep1 --priority=3 --apply
```

Atualize `.glpi/project.yaml` com os IDs. Plano local: `docs/05_progresso/geral/PLANO_IMPLEMENTACAO.md`.

---

## 11. Configurar o produto (`.glpi/`)

```yaml
# .glpi/project.yaml
key: meu-produto
ticket_id: 0
project_id: 0
entity_hint: "Prefeitura de Franca"
location_hint: ""
phase_template: corporate-phases
followup_private: false
```

| Template | Uso |
|----------|-----|
| `corporate-phases.json` | Discovery → Evolução (padrão corporativo) |
| `product-s-phases.example.json` | Exemplo S0–S7 (adaptar ao produto) |

`workspace.yaml` lista clones para polyrepo/retro-scan. Estados GEP: `.glpi/maps/states.json`.

---

## 12. Validar e ativar no GLPI

Na **raiz do produto**:

```bash
./tools/glpi/glpi auth
./tools/glpi/glpi ticket get
./tools/glpi/glpi project get
./tools/glpi/glpi project tasks

./tools/glpi/glpi states discover --apply
./tools/glpi/bin/glpi-seed-phases --template=corporate-phases

./tools/glpi/bin/glpi-retro-scan
./tools/glpi/bin/glpi-retro-apply --from=docs/06_glpi/retro-scans/ARQUIVO.json
./tools/glpi/bin/glpi-retro-apply --from=docs/06_glpi/retro-scans/ARQUIVO.json --apply
```

### Checklist de ativação

- [ ] `~/.secrets/GLPI-tokens.txt` (Pessoal, Grupo, URL-API)
- [ ] Dependências `bash curl jq python3`
- [ ] Bootstrap aplicado
- [ ] `.glpi/project.yaml` com IDs corretos
- [ ] `glpi auth` OK
- [ ] Seed revisado (dry-run) e aplicado se autorizado
- [ ] Skills `glpi-*` no Cursor

---

## 13. Uso diário

| Ação | Como |
|------|------|
| Follow-up | `./tools/glpi/bin/glpi-followup` / skill `acompanhar-chamado` (alias `glpi-followup`) |
| Upsert S/P | `./tools/glpi/bin/glpi-task-upsert --code=S4.P1 ...` |
| Consulta | `./tools/glpi/glpi project get` / `project tasks` |

```bash
./tools/glpi/glpi ticket followup - "[S4] Validacao OK. sha:abc1234. Proximo: offline sync."
```

`ticket followup` e `* --apply` **gravam** no GLPI. Detalhes: [`docs/06_glpi/MANUAL_USO_GLPI.md`](docs/06_glpi/MANUAL_USO_GLPI.md).

---

## 14. Atualizar o kit no projeto

```bash
cd ~/projetos/pmf-dev-kit && git pull
./scripts/upgrade-into.sh /caminho/do/produto --profile=pmf-core
```

---

## 15. Perfis e numeração de docs

| Perfil | Inclui |
|--------|--------|
| `glpi-only` | `tools/glpi`, skills `glpi-*`, `docs/06_glpi`, skeleton `.glpi` |
| `pmf-core` | + skills Git/sessão + `docs/05_progresso` |
| `full-skeleton` | + árvore `docs/00`…`09` + workflow example + `AGENTS.md.example` |

| Pasta | Conteúdo |
|-------|----------|
| `00_visao_geral` … `05_progresso` | Produto / plano |
| **`06_glpi`** | Integração GLPI (não usa mais `00-GLPI`) |
| `07_doc_academica` … `09_dados_e_tabelas` | Demais |

---

## 16. Troubleshooting

| Sintoma | Ação |
|---------|------|
| `ERROR_APP_TOKEN_*` | Conferir `Grupo API-GLPI` / `GLPI_APP_TOKEN` |
| `ERROR_GLPI_LOGIN_USER_TOKEN` | Conferir `Pessoal API-GLPI` |
| Secrets não encontrados | `ls ~/.secrets/GLPI-tokens.txt` ou `GLPI_SECRETS_FILE` |
| `ticket_id nao informado` | Preencher `.glpi/project.yaml` |
| `rsync: command not found` | Usar WSL ou cópia manual |
| `project tasks` → `[]` | Seed + `state-project-*.json` |
| `states discover` 403 | Sem permissão GET /ProjectState/ — usar mapa do preset |

---

## 17. Referências

| Recurso | Path |
|---------|------|
| Manual de integração (cópia em docs) | [`docs/06_glpi/MANUAL_INTEGRACAO_GLPI.md`](docs/06_glpi/MANUAL_INTEGRACAO_GLPI.md) |
| Manual de uso do CLI | [`docs/06_glpi/MANUAL_USO_GLPI.md`](docs/06_glpi/MANUAL_USO_GLPI.md) |
| Visão de gestão | [`docs/06_glpi/INTEGRACAO_GLPI_GESTAO_PROJETOS.md`](docs/06_glpi/INTEGRACAO_GLPI_GESTAO_PROJETOS.md) |
| Hierarquia S/P | [`docs/06_glpi/HIERARQUIA_S_P_GLPI.md`](docs/06_glpi/HIERARQUIA_S_P_GLPI.md) |
| CLI | [`tools/glpi/`](tools/glpi/) |
| Assistentes | [`scripts/install-glpi.sh`](scripts/install-glpi.sh) · [`scripts/install_glpi.py`](scripts/install_glpi.py) |
| Bootstrap / Upgrade | [`scripts/bootstrap-into.sh`](scripts/bootstrap-into.sh) · [`scripts/upgrade-into.sh`](scripts/upgrade-into.sh) |
| Autoria e citação | [`AUTHORS.md`](AUTHORS.md) · [`CITATION.bib`](CITATION.bib) |
| Licença | [`LICENSE`](LICENSE) (MIT) |

---

## Autoria e publicação

| | |
|---|---|
| **Autor principal** | **Dr. Ricardo David** |
| **E-mail pessoal** | [rdavid38@hotmail.com](mailto:rdavid38@hotmail.com) |
| **E-mail corporativo** | [ricardodavid@franca.sp.gov.br](mailto:ricardodavid@franca.sp.gov.br) |
| **Instituição patrocinadora** | Prefeitura Municipal de Franca (**PMF**) — **DTI** |
| **Obra** | Concepção, arquitetura, implementação e documentação do **pmf-dev-kit** e do preset **API-VSCode-GLPI** |
| **Origem** | Generalizado a partir de **samu-operacional** (SIGS-Samu); exemplos PMF na documentação |
| **Licença** | [MIT](LICENSE) — uso, modificação e redistribuição com atribuição |
| **Citação** | Ver [`AUTHORS.md`](AUTHORS.md) e [`CITATION.bib`](CITATION.bib) |

> Publicação pública: inclua o aviso de copyright e a licença MIT ao redistribuir forks ou derivados.

---

*Secrets nunca neste repositório.*
