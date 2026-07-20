# Integração GLPI — SAMU Operacional

> Gestão de chamados/tarefas via API REST GLPI para o projeto SIGS-Samu.  
> Ferramentas (`tools/glpi`, skill `glpi-followup`) são **locais a este repositório** (duplicadas em outros produtos PMF para uso independente).  
> Hierarquia e docs do **Bot_Pan** ficam no repositório `Bot_Pan` — não neste clone.

**Manual operacional detalhado:** [`MANUAL_USO_GLPI.md`](MANUAL_USO_GLPI.md) (comandos, env, configs, conceitos, troubleshooting).  
**Reavaliação VSCode ↔ Git ↔ GLPI:** [`REAVALIACAO_VSCODE_GIT_GLPI.md`](REAVALIACAO_VSCODE_GIT_GLPI.md) (gap vs estrutura completa de Projeto/Tarefa e skills alvo).

---

## 1. Objetivo

Automatizar registro e acompanhamento de:

- chamado institucional do SAMU Operacional;
- `Project` / `ProjectTask` do projeto GLPI 72;
- follow-ups (`ITILFollowup`) alinhados ao plano `PLANO_IMPLEMENTACAO.md`;

com suporte futuro a polyrepo (`samu-operacional`, `SAMU_CRU`, variante Windows).

---

## 2. Inventário GLPI (este produto)

| Elemento | Valor |
|----------|--------|
| Ticket | **10554** — Samu Operacional |
| Projeto | **72** — Desenvolvimento PMF SIGS-Samu |
| Entidade | Prefeitura de Franca |
| Localização | Paço > SMS > SAMU |

Config: `.glpi/project.yaml`  
Polyrepo: `.glpi/workspace.yaml`  
Template de fases: `.glpi/templates/corporate-phases.json`  
Estado do seed: `.glpi/state-project-72.json`

### ProjectTasks seedadas (projeto 72)

| Fase | ProjectTask id |
|------|----------------|
| 1. Discovery | 800 |
| 2. Análise | 801 |
| 3. Projeto | 802 |
| 4.1 Implementação Front-end | 803 |
| 4.2 Implementação Back-end | 804 |
| 5. Evolução | 805 |

Follow-up de ativação do MVP CLI: ITILFollowup **#12034**.

---

## 3. Acesso API

| Item | Valor |
|------|--------|
| URL | `https://suporte.franca.sp.gov.br/apirest.php` |
| Secrets | `~/.secrets/GLPI-tokens.txt` (**nunca** versionar) |
| Pessoal | `user_token` |
| Grupo | `App-Token` (obrigatório nesta instância) |

Referência técnica: `docs/06_glpi/GLPI-rest-API-documentationmd`.

---

## 4. Modelo

| Camada | Itemtype | Papel |
|--------|----------|--------|
| Institucional | `Ticket` | Canal oficial (#10554) |
| Entrega | `Project` + `ProjectTask` | Fases Discovery→Evolução / plano S0–S7 |
| Diário | `ITILFollowup` | Commits, deploys, checkpoints |

Integração é de **gestão de projeto**, não do domínio regulatório 195 — não misturar cliente GLPI em `apps/backend`.

---

## 5. CLI e skill (neste repo)

```bash
./tools/glpi/glpi auth
./tools/glpi/glpi ticket get
./tools/glpi/glpi ticket followup - "[S1.1] resumo + sha + proximo"
./tools/glpi/glpi project get
./tools/glpi/glpi project tasks
./tools/glpi/glpi seed-phases              # dry-run (corporate-phases)
./tools/glpi/glpi seed-phases --apply
```

Skill: `.github/skills/glpi-followup/SKILL.md`  
Checklist: *follow-up GLPI enviado?* em `docs/05-gestao-projeto/geral/FLUXO_COMMIT_CHECKLIST.md`.

---

## 6. Automação (visão)

| Meio | Uso |
|------|-----|
| Skills Cursor | `glpi-followup`, futuro `encerrar-sessao` / `glpi-retro-scan` |
| CLI | Operação manual e scripts |
| CI | Job `glpi-notify` pós-deploy (pendente) |
| Polyrepo | `.glpi/workspace.yaml` → retro-scan futuro |

---

## 7. Independência entre repositórios

| Artefato | samu-operacional | Bot_Pan |
|----------|------------------|---------|
| CLI + skill | cópia local | cópia local |
| `.glpi/project.yaml` | ticket 10554 / project 72 | project 12 + hierarquia |
| Docs hierarquia Bot_Pan | **não** | **sim** (`docs/06_glpi/`, `.glpi/hierarchy.yaml`) |
| Secrets | `~/.secrets/` (máquina) | idem |

Não referenciar paths do clone Bot_Pan para executar o CLI deste repo.

---

## 8. Roadmap

1. ~~CLI + skill follow-up + seed fases no 72~~ feito
2. Job CI `glpi-notify` após health OK
3. `glpi-retro-scan` no bundle `samu` (workspace.yaml)
4. `glpi-sync-plano` contínuo com `PLANO_IMPLEMENTACAO.md`

---

## 9. Plano de produto (contexto)

Ver `docs/05-gestao-projeto/geral/PLANO_IMPLEMENTACAO.md`.  
**Próximo item ativo:** S1.1 — tela TARM web.

---

*Ajustado em 17/07/2026: docs Bot_Pan removidos deste repo; ferramentas mantidas localmente.*
