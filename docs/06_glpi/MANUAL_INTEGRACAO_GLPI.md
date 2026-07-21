# Manual de integração GLPI — pmf-dev-kit

> Guia passo a passo para implantar a integração GLPI em **projetos novos** e **pré-existentes**, a partir deste repositório-fonte.  
> **Página de rosto (Gitness):** o mesmo conteúdo está no [`README.md`](../../README.md) da raiz.

| | |
|---|---|
| **Repositório** | [PMF-Integracao_GLPI/pmf-dev-kit](https://gitness.franca.sp.gov.br/PMF-Integracao_GLPI/pmf-dev-kit) |
| **Clone** | `https://gitness.franca.sp.gov.br/git/PMF-Integracao_GLPI/pmf-dev-kit.git` |
| **API GLPI** | `https://suporte.franca.sp.gov.br/apirest.php` |
| **Última atualização** | 21/07/2026 |

---

## Sumário

1. [O que é este kit](#1-o-que-é-este-kit)
2. [Pré-requisitos](#2-pré-requisitos)
3. [Secrets e variáveis de acesso](#3-secrets-e-variáveis-de-acesso)
4. [Ambiente Linux / WSL](#4-ambiente-linux--wsl)
5. [Ambiente Windows](#5-ambiente-windows)
6. [Clonar o kit](#6-clonar-o-kit)
7. [Projeto pré-existente (bootstrap)](#7-projeto-pré-existente-bootstrap)
8. [Projeto novo](#8-projeto-novo)
9. [Configurar o produto (`.glpi/`)](#9-configurar-o-produto-glpi)
10. [Validar e ativar no GLPI](#10-validar-e-ativar-no-glpi)
11. [Uso diário](#11-uso-diário)
12. [Atualizar o kit no projeto (`upgrade`)](#12-atualizar-o-kit-no-projeto-upgrade)
13. [Perfis de bootstrap](#13-perfis-de-bootstrap)
14. [Troubleshooting](#14-troubleshooting)
15. [Referências](#15-referências)

---

## 1. O que é este kit

O **pmf-dev-kit** é o repositório **fonte** (template) da Prefeitura de Franca / PMF para gestão de projeto com:

| Artefato | Função |
|----------|--------|
| `tools/glpi/` | CLI + wrappers (`bin/glpi-*`) para API REST do GLPI |
| `.glpi/` | Config versionável do produto (sem secrets) + templates de fases |
| `.github/skills/glpi-*` | Skills Cursor (follow-up, upsert, project-create, retro-scan) |
| `docs/06_glpi/` | Documentação da integração |
| `scripts/bootstrap-into.sh` | Aplica o kit em um clone de produto |
| `scripts/upgrade-into.sh` | Atualiza tools/skills/docs sem apagar a config do produto |

**Modelo de distribuição:** cada projeto **vendoriza** (copia) o CLI, skills e docs. Não se executa o CLI “de outro repositório”. Secrets ficam **fora do git**, na máquina do desenvolvedor.

```text
pmf-dev-kit (fonte)
        │  bootstrap-into / upgrade-into
        ▼
produto-X/                  produto-Y/
  tools/glpi/   (cópia)       tools/glpi/   (cópia)
  .glpi/project.yaml          .glpi/project.yaml
  docs/06_glpi/               docs/06_glpi/
        │                           │
        └───────────┬───────────────┘
                    ▼
         ~/.secrets/GLPI-tokens.txt
                    ▼
    suporte.franca.sp.gov.br (API GLPI)
```

Entidades usadas:

| Camada | Itemtype GLPI | Papel |
|--------|---------------|--------|
| Institucional | `Ticket` | Canal oficial + `ITILFollowup` |
| Entrega | `Project` + `ProjectTask` | Fases (S=pai) e itens (P=filho) |
| Diário | `ITILFollowup` | Checkpoints, commits, deploys |

Hierarquia: [`HIERARQUIA_S_P_GLPI.md`](HIERARQUIA_S_P_GLPI.md).  
Uso operacional do CLI: [`MANUAL_USO_GLPI.md`](MANUAL_USO_GLPI.md).

---

## 2. Pré-requisitos

### 2.1 Software

| Ferramenta | Obrigatório | Notas |
|------------|-------------|--------|
| `bash` | Sim | Shell do CLI |
| `curl` | Sim | HTTP |
| `jq` | Sim | Parse JSON |
| `python3` | Sim | Utilitários do CLI / retro-scan |
| `rsync` | Sim (bootstrap) | Cópia no `bootstrap-into.sh` |
| `git` | Sim | Clone / fluxo de trabalho |
| Cursor (ou VS Code + Agent) | Recomendado | Skills em `.github/skills/` |

### 2.2 Acesso GLPI

1. Conta no [suporte.franca.sp.gov.br](https://suporte.franca.sp.gov.br) com permissão de API.
2. **User token** (pessoal) e **App-Token** (grupo/cliente API) — obrigatórios nesta instância.
3. IDs do **Ticket** e/ou **Project** do produto (criar na UI se ainda não existirem), ou usar `project create` do CLI (dry-run → `--apply`).

### 2.3 Instalação rápida das dependências

**Debian/Ubuntu (WSL incluso):**

```bash
sudo apt update
sudo apt install -y bash curl jq python3 rsync git
```

**Windows (Git Bash / ambiente nativo):** ver [seção 5](#5-ambiente-windows). Preferência institucional: rodar o CLI **dentro do WSL**.

---

## 3. Secrets e variáveis de acesso

### 3.1 Onde ficam os secrets

| Ambiente | Caminho padrão |
|----------|----------------|
| **Linux / WSL** | `$HOME/.secrets/GLPI-tokens.txt` → tipicamente `/home/<usuario>/.secrets/GLPI-tokens.txt` |
| **Windows (nativo)** | `%USERPROFILE%\.secrets\GLPI-tokens.txt` (ex.: `C:\Users\<usuario>\.secrets\GLPI-tokens.txt`) |
| Override | Variável `GLPI_SECRETS_FILE` com path absoluto |

> A pasta `.secrets` fica na **raiz do home do usuário** (`~/.secrets`), **fora** de qualquer repositório. Nunca versionar tokens.

### 3.2 Formato do arquivo `GLPI-tokens.txt`

Crie o arquivo com as três linhas obrigatórias (labels reconhecidos pelo CLI):

```text
Pessoal API-GLPI: <SEU_USER_TOKEN>
Grupo   API-GLPI: <SEU_APP_TOKEN>
URL-API: https://suporte.franca.sp.gov.br/apirest.php
```

| Label no arquivo | Header HTTP | Papel |
|------------------|-------------|--------|
| `Pessoal API-GLPI` | `Authorization: user_token …` | Identifica o usuário |
| `Grupo API-GLPI` | `App-Token: …` | Cliente API (obrigatório na PMF) |
| `URL-API` | base do CLI | Endpoint legacy `/apirest.php` |

O restante do arquivo pode conter anotações (IDs de ticket/projeto, URLs da UI) — o parser ignora linhas sem esses labels.

**Como obter os tokens no GLPI**

1. Faça login em `https://suporte.franca.sp.gov.br`.
2. Preferências do usuário → **Remote access keys** / token de API pessoal → copie o **user token**.
3. Solicite ao administrador do GLPI o **App-Token** do cliente API autorizado (grupo/aplicação PMF).

### 3.3 Variáveis de ambiente (opcionais)

Todas são opcionais se o arquivo de secrets + `.glpi/project.yaml` estiverem corretos.

| Variável | Default | Descrição |
|----------|---------|-----------|
| `GLPI_USER_TOKEN` | Pessoal no secrets | Token de usuário |
| `GLPI_APP_TOKEN` | Grupo no secrets | App-Token |
| `GLPI_API_URL` | URL do secrets ou `https://suporte.franca.sp.gov.br/apirest.php` | Base da API (sem barra final) |
| `GLPI_SECRETS_FILE` | `$HOME/.secrets/GLPI-tokens.txt` | Path do arquivo de tokens |
| `GLPI_PROJECT_FILE` | `<repo>/.glpi/project.yaml` | Config do produto |
| `GLPI_STATES_FILE` | `<repo>/.glpi/maps/states.json` | Alias → `projectstates_id` |
| `GLPI_DRY_RUN` | (vazio) | Se `1`, força dry-run em task create/patch/upsert |

Exemplo só por env (sem ler o arquivo):

```bash
export GLPI_USER_TOKEN='...'
export GLPI_APP_TOKEN='...'
export GLPI_API_URL='https://suporte.franca.sp.gov.br/apirest.php'
./tools/glpi/glpi auth
```

### 3.4 Segurança

- Nunca commitiar `GLPI-tokens.txt`, `.env` com tokens, dumps de `session_token`.
- No kit, `.glpi/project.yaml`, `.glpi/workspace.yaml` e `state-project-*.json` estão no `.gitignore` do produto (config local / IDs); templates e maps são versionáveis.
- Não colocar PII sensível ou dados clínicos em follow-ups.
- Preferir comandos de **leitura** e dry-run até validar o ambiente.

---

## 4. Ambiente Linux / WSL

### 4.1 Criar a pasta de secrets

```bash
mkdir -p ~/.secrets
chmod 700 ~/.secrets
nano ~/.secrets/GLPI-tokens.txt   # ou: code ~/.secrets/GLPI-tokens.txt
chmod 600 ~/.secrets/GLPI-tokens.txt
```

Cole o formato da [seção 3.2](#32-formato-do-arquivo-glpi-tokenstxt) (substitua pelos tokens reais).

### 4.2 Verificar

```bash
test -f ~/.secrets/GLPI-tokens.txt && echo "OK: secrets presentes"
command -v curl jq python3 rsync git
```

### 4.3 Path WSL ↔ Windows Explorer

O arquivo no WSL é visível no Explorer como:

```text
\\wsl.localhost\<Distro>\home\<usuario>\.secrets\GLPI-tokens.txt
```

Exemplo: `\\wsl.localhost\Ubuntu\home\wsl\.secrets\GLPI-tokens.txt`

Use esse caminho apenas para editar/copiar; o CLI em bash deve usar `~/.secrets/...`.

### 4.4 Repositórios de trabalho

Convenção sugerida:

```text
/home/<usuario>/projetos/pmf-dev-kit     ← clone do kit
/home/<usuario>/projetos/<seu-produto>  ← clone do produto
```

---

## 5. Ambiente Windows

Há dois modos. **Recomendado: WSL** (mesmo fluxo da seção 4).

### 5.1 Modo recomendado — CLI no WSL, editor no Windows

1. Instale [WSL2 + Ubuntu](https://learn.microsoft.com/windows/wsl/install).
2. Configure secrets e clone **dentro do WSL** (seção 4).
3. Abra a pasta do projeto no Cursor/VS Code via *Remote – WSL* ou pelo path `\\wsl.localhost\...`.
4. Terminal integrado: shell bash do WSL → `./tools/glpi/glpi auth`.

### 5.2 Modo nativo Windows (Git Bash)

Só se não houver WSL. Limitações: paths, `rsync` e permissões diferem.

1. Instale [Git for Windows](https://git-scm.com/download/win) (inclui bash + curl).
2. Instale `jq` (ex.: `winget install jqlang.jq` ou Chocolatey).
3. Garanta `python3` no PATH.
4. Para bootstrap, instale `rsync` (ex.: via MSYS2) **ou** copie manualmente as pastas listadas na [seção 7.3](#73-alternativa-cópia-manual).
5. Secrets:

```bat
mkdir %USERPROFILE%\.secrets
notepad %USERPROFILE%\.secrets\GLPI-tokens.txt
```

No Git Bash:

```bash
export HOME="/c/Users/<usuario>"   # se necessário
mkdir -p "$HOME/.secrets"
# editar "$HOME/.secrets/GLPI-tokens.txt"
./tools/glpi/glpi auth
```

Se o home do Git Bash não for o perfil Windows:

```bash
export GLPI_SECRETS_FILE="/c/Users/<usuario>/.secrets/GLPI-tokens.txt"
```

---

## 6. Clonar o kit

```bash
cd ~/projetos   # ou pasta de trabalho
git clone https://gitness.franca.sp.gov.br/git/PMF-Integracao_GLPI/pmf-dev-kit.git
cd pmf-dev-kit
chmod +x scripts/*.sh tools/glpi/glpi tools/glpi/bin/*
```

O kit em si **não** substitui o `project.yaml` de um produto; ele é a fonte para `bootstrap-into` / `upgrade-into`.

---

## 7. Projeto pré-existente (bootstrap)

Use quando o repositório do produto **já existe** (código, histórico git) e você quer adicionar a integração GLPI.

### 7.1 Escolher o perfil

| Perfil | Inclui |
|--------|--------|
| `glpi-only` | `tools/glpi`, skills `glpi-*`, `docs/06_glpi`, skeleton `.glpi` |
| `pmf-core` (padrão) | + skills commit/exporte/importe/atualizar/backup/documentar/encerrar-sessao/oncoto-oncovo + `docs/05_progresso` |
| `full-skeleton` | + árvore `docs/00`…`09` + workflow example + `AGENTS.md.example` |

### 7.2 Comando

```bash
# A partir do clone do kit
./scripts/bootstrap-into.sh /caminho/absoluto/do/produto \
  --profile=pmf-core \
  --key=nome-do-produto \
  --ticket=ID_DO_TICKET \
  --project=ID_DO_PROJECT
```

Exemplos:

```bash
# Só GLPI
./scripts/bootstrap-into.sh ~/projetos/meu-app --profile=glpi-only --key=meu-app

# Core PMF + IDs já conhecidos
./scripts/bootstrap-into.sh ~/projetos/meu-app \
  --profile=pmf-core \
  --key=meu-app \
  --ticket=10554 \
  --project=72

# Árvore docs completa
./scripts/bootstrap-into.sh ~/projetos/meu-app --profile=full-skeleton --key=meu-app
```

O que o script faz:

- Copia `tools/glpi` (e torna executáveis).
- Copia maps/templates `.glpi/` (não sobrescreve `project.yaml` / `workspace.yaml` se já existirem).
- Cria `.glpi/project.yaml` e `.glpi/workspace.yaml` a partir dos examples se ainda não houver.
- Instala skills conforme o perfil.
- Copia `docs/06_glpi/` (e `docs/05_progresso/` nos perfis core/full).

Com `--force`, sobrescreve tools/skills/docs do kit; a config `project.yaml` existente **continua preservada**.

### 7.3 Alternativa: cópia manual

Se `rsync`/bootstrap não estiver disponível:

```text
kit/tools/glpi/          →  produto/tools/glpi/
kit/.glpi/maps/          →  produto/.glpi/maps/
kit/.glpi/templates/     →  produto/.glpi/templates/
kit/.glpi/project.yaml.example  →  produto/.glpi/project.yaml  (editar)
kit/docs/06_glpi/        →  produto/docs/06_glpi/
kit/.github/skills/glpi-* →  produto/.github/skills/
```

Depois: `chmod +x produto/tools/glpi/glpi produto/tools/glpi/bin/*`

### 7.4 Próximos passos após o bootstrap

Siga as [seções 9 e 10](#9-configurar-o-produto-glpi).

---

## 8. Projeto novo

### 8.1 Criar o repositório do produto

```bash
mkdir -p ~/projetos/meu-produto && cd ~/projetos/meu-produto
git init
# (opcional) criar remote no Gitness e git remote add origin ...
```

### 8.2 Aplicar o kit

```bash
~/projetos/pmf-dev-kit/scripts/bootstrap-into.sh "$(pwd)" \
  --profile=full-skeleton \
  --key=meu-produto
```

### 8.3 Criar Ticket / Project no GLPI

**Opção A — UI:** abra um chamado e/ou projeto em `https://suporte.franca.sp.gov.br` e anote os IDs.

**Opção B — CLI (dry-run primeiro):**

```bash
./tools/glpi/bin/glpi-project-create --name="Meu produto" --code=MEU --state=gep1 --priority=3
./tools/glpi/bin/glpi-project-create --name="Meu produto" --code=MEU --state=gep1 --priority=3 --apply
```

Atualize `.glpi/project.yaml` com o `project_id` (e `ticket_id` se houver chamado).

### 8.4 Plano local

Com perfil `pmf-core` / `full-skeleton`, use:

- `docs/05_progresso/geral/PLANO_IMPLEMENTACAO.md` (copie do `.example` se necessário)
- Convenção **S** (fase/pai) / **P** (item/filho) — ver hierarquia

---

## 9. Configurar o produto (`.glpi/`)

### 9.1 `project.yaml` (obrigatório)

```yaml
key: meu-produto
ticket_id: 0          # ID do Ticket institucional (0 = informar na CLI)
project_id: 0         # ID do Project GLPI
entity_hint: "Prefeitura de Franca"
location_hint: ""
phase_template: corporate-phases   # ou samu-s-phases / template customizado
followup_private: false
```

| Campo | Função |
|-------|--------|
| `key` | Identificador lógico do produto |
| `ticket_id` | Default de `ticket get` / `followup` |
| `project_id` | Default de `project get` / `tasks` / `seed-phases` |
| `phase_template` | Nome do JSON em `.glpi/templates/` |
| `followup_private` | Se `true`, follow-up privado no GLPI |

Sobrescrita pontual: `./tools/glpi/glpi ticket get 99999`

### 9.2 Templates de fases

| Arquivo | Uso |
|---------|-----|
| `corporate-phases.json` | Fases corporativas Discovery → Evolução |
| `product-s-phases.example.json` | Exemplo S0–S7 (renomear/adaptar para o produto; id interno `samu-s-phases`) |

```bash
# Copiar exemplo e ajustar nomes/códigos ao seu plano
cp .glpi/templates/product-s-phases.example.json .glpi/templates/meu-produto-s-phases.json
# Ajuste template_id e phases; aponte phase_template no project.yaml
```

### 9.3 `workspace.yaml` (polyrepo / retro-scan)

Lista clones do programa. Ajuste `path` absoluto de cada repo.

### 9.4 Maps

`.glpi/maps/states.json` — aliases GEP (`gep1`, `gep3`, …) → `projectstates_id` da instância Franca.

---

## 10. Validar e ativar no GLPI

Execute **na raiz do produto** (não na raiz do kit, salvo testes).

### 10.1 Autenticação

```bash
./tools/glpi/glpi auth
# ou: ./tools/glpi/bin/glpi-auth   # se o wrapper existir no produto
```

Esperado: JSON/session ok e saída sem erro de App-Token / user_token.

### 10.2 Leitura segura

```bash
./tools/glpi/glpi ticket get
./tools/glpi/glpi project get
./tools/glpi/glpi project tasks
```

### 10.3 Seed das fases (pais)

```bash
./tools/glpi/bin/glpi-seed-phases --template=corporate-phases          # dry-run
./tools/glpi/bin/glpi-seed-phases --template=corporate-phases --apply   # grava
```

### 10.4 Retro-scan e apply (itens S/P)

```bash
./tools/glpi/bin/glpi-retro-scan
# Revisar docs/06_glpi/retro-scans/*.md e *.json
./tools/glpi/bin/glpi-retro-apply --from=docs/06_glpi/retro-scans/ARQUIVO.json
./tools/glpi/bin/glpi-retro-apply --from=docs/06_glpi/retro-scans/ARQUIVO.json --apply
```

### 10.5 Checklist de ativação

- [ ] `~/.secrets/GLPI-tokens.txt` com Pessoal, Grupo e URL-API
- [ ] Dependências `bash curl jq python3`
- [ ] Bootstrap aplicado no produto
- [ ] `.glpi/project.yaml` com `ticket_id` / `project_id` corretos
- [ ] `./tools/glpi/glpi auth` OK
- [ ] Seed de fases revisado (dry-run) e aplicado se autorizado
- [ ] Skills `glpi-*` visíveis no Cursor
- [ ] (Opcional) primeiro follow-up de ativação no Ticket

---

## 11. Uso diário

| Ação | Comando / skill |
|------|-----------------|
| Follow-up no chamado | `./tools/glpi/bin/glpi-followup` ou skill `glpi-followup` |
| Atualizar fase/item | `./tools/glpi/bin/glpi-task-upsert --code=S4.P1 ...` ou skill `glpi-task-upsert` |
| Consultar projeto | `./tools/glpi/glpi project get` / `project tasks` |
| Encerrar sessão | skill `encerrar-sessao` + follow-up opcional |

Exemplo de follow-up:

```bash
./tools/glpi/glpi ticket followup - "[S4] Validacao OK. sha:abc1234. Proximo: offline sync."
```

> `ticket followup` e `* --apply` **gravam** no GLPI. Demais comandos de get/auth/seed sem `--apply` são seguros.

Detalhes: [`MANUAL_USO_GLPI.md`](MANUAL_USO_GLPI.md).

---

## 12. Atualizar o kit no projeto (`upgrade`)

Quando o `pmf-dev-kit` evoluir (CLI, skills, docs):

```bash
cd ~/projetos/pmf-dev-kit
git pull

./scripts/upgrade-into.sh /caminho/do/produto --profile=pmf-core
```

Preserva `.glpi/project.yaml` / `workspace.yaml` existentes; atualiza tools, skills e docs do kit.

---

## 13. Perfis de bootstrap

| Perfil | GLPI | Skills fluxo Git | `docs/05_progresso` | `docs/00`…`09` |
|--------|------|------------------|---------------------|----------------|
| `glpi-only` | Sim | Não | Não | Só `06_glpi` |
| `pmf-core` | Sim | Sim | Sim | `05` + `06` |
| `full-skeleton` | Sim | Sim | Sim | Completa |

Numeração de pastas: [`../00_visao_geral/NUMERACAO_DOCS.md`](../00_visao_geral/NUMERACAO_DOCS.md) — GLPI é **`06_glpi`** (não `00`).

---

## 14. Troubleshooting

| Sintoma | Causa provável | Ação |
|---------|----------------|------|
| `ERROR_APP_TOKEN_PARAMETERS_MISSING` | Sem App-Token | Conferir `Grupo API-GLPI` ou `GLPI_APP_TOKEN` |
| `ERROR_WRONG_APP_TOKEN_PARAMETER` | App-Token inválido | Trocar: Grupo = App, Pessoal = user |
| `ERROR_GLPI_LOGIN_USER_TOKEN` | user_token errado | Conferir Pessoal |
| Arquivo de secrets não encontrado | Path errado | `ls ~/.secrets/GLPI-tokens.txt` ou `GLPI_SECRETS_FILE` |
| `ticket_id nao informado` | yaml sem ID | Preencher `.glpi/project.yaml` ou passar ID |
| `project tasks` → `[]` | Sub-API vazia / state ausente | Rodar seed; verificar `state-project-*.json` |
| `template nao encontrado` | Nome errado | Conferir `phase_template` e arquivos em `templates/` |
| `rsync: command not found` | Sem rsync no Windows nativo | Usar WSL ou [cópia manual](#73-alternativa-cópia-manual) |
| Follow-up sem permissão | Perfil GLPI | Ajustar perfil/entidade no suporte |

---

## 15. Referências

| Recurso | Path / URL |
|---------|------------|
| Este manual | `docs/06_glpi/MANUAL_INTEGRACAO_GLPI.md` |
| Uso do CLI | `docs/06_glpi/MANUAL_USO_GLPI.md` |
| Visão de gestão | `docs/06_glpi/INTEGRACAO_GLPI_GESTAO_PROJETOS.md` |
| Hierarquia S/P | `docs/06_glpi/HIERARQUIA_S_P_GLPI.md` |
| API REST (cópia) | `docs/06_glpi/GLPI-rest-API-documentationmd` |
| CLI | `tools/glpi/` · wrappers `tools/glpi/bin/` |
| Bootstrap | `scripts/bootstrap-into.sh` |
| Upgrade | `scripts/upgrade-into.sh` |
| Gitness | https://gitness.franca.sp.gov.br/PMF-Integracao_GLPI/pmf-dev-kit |

---

*Kit fonte PMF — Integração GLPI. Secrets nunca neste repositório.*
