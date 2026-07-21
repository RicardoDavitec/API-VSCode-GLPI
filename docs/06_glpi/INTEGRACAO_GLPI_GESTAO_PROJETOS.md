# Integração GLPI — gestão de projetos (pmf-dev-kit)

> Abordagem de integração baseada no repositório fonte  
> [PMF-Integracao_GLPI/pmf-dev-kit](https://gitness.franca.sp.gov.br/PMF-Integracao_GLPI/pmf-dev-kit).  
> Cada produto **vendoriza** CLI, skills e docs; secrets ficam em `~/.secrets/` na máquina.

**Manual de integração (passo a passo):** [`MANUAL_INTEGRACAO_GLPI.md`](MANUAL_INTEGRACAO_GLPI.md)  
**Manual operacional do CLI:** [`MANUAL_USO_GLPI.md`](MANUAL_USO_GLPI.md)  
**Hierarquia S/P:** [`HIERARQUIA_S_P_GLPI.md`](HIERARQUIA_S_P_GLPI.md)  
**Reavaliação VSCode ↔ Git ↔ GLPI:** [`REAVALIACAO_VSCODE_GIT_GLPI.md`](REAVALIACAO_VSCODE_GIT_GLPI.md)

**Última atualização:** 21/07/2026

---

## 1. Objetivo

Padronizar, em qualquer produto PMF:

- registro no **Ticket** institucional (`ITILFollowup`);
- gestão de **Project** / **ProjectTask** (fases S = pai, itens P = filho);
- bootstrap e upgrade a partir do kit, sem acoplar o domínio de negócio ao cliente GLPI.

A integração é de **gestão de projeto / auditoria**, não do domínio de aplicação do produto.

---

## 2. Modelo de distribuição

```text
pmf-dev-kit          ← fonte (este repositório)
      │
      │  bootstrap-into.sh / upgrade-into.sh
      ▼
 produto/            ← cópia local (vendorizada)
   tools/glpi/
   .glpi/project.yaml
   docs/06_glpi/
   .github/skills/glpi-*
      │
      ▼
 ~/.secrets/GLPI-tokens.txt  →  suporte.franca.sp.gov.br
```

| Artefato | Onde vive | Versionar? |
|----------|-----------|------------|
| CLI + wrappers | `tools/glpi/` no produto | Sim |
| Templates / maps | `.glpi/templates/`, `.glpi/maps/` | Sim |
| `project.yaml` / state | `.glpi/` no produto | Local (gitignore no kit) |
| Tokens | `~/.secrets/GLPI-tokens.txt` | **Nunca** |
| Docs GLPI | `docs/06_glpi/` | Sim |

Não referenciar paths de outro clone para executar o CLI do produto.

---

## 3. Acesso API

| Item | Valor |
|------|--------|
| URL | `https://suporte.franca.sp.gov.br/apirest.php` |
| Secrets | `~/.secrets/GLPI-tokens.txt` |
| Pessoal | `user_token` |
| Grupo | `App-Token` (obrigatório nesta instância) |

Detalhes WSL/Windows e variáveis: [`MANUAL_INTEGRACAO_GLPI.md`](MANUAL_INTEGRACAO_GLPI.md) §§3–5.

---

## 4. Modelo de entidades

| Camada | Itemtype | Papel |
|--------|----------|--------|
| Institucional | `Ticket` | Canal oficial |
| Entrega | `Project` + `ProjectTask` | Fases corporativas ou S0–Sn / itens P |
| Diário | `ITILFollowup` | Commits, deploys, checkpoints |

Config por produto: `.glpi/project.yaml` (`ticket_id`, `project_id`, `phase_template`).

---

## 5. Bootstrap rápido

```bash
# Clonar o kit
git clone https://gitness.franca.sp.gov.br/git/PMF-Integracao_GLPI/pmf-dev-kit.git

# Aplicar em projeto existente
./scripts/bootstrap-into.sh /caminho/do/produto --profile=pmf-core --key=meu-produto

cd /caminho/do/produto
# editar .glpi/project.yaml
./tools/glpi/glpi auth
./tools/glpi/bin/glpi-seed-phases --template=corporate-phases
```

Perfis: `glpi-only` | `pmf-core` | `full-skeleton` — ver manual de integração.

---

## 6. CLI e skills

```bash
./tools/glpi/glpi auth
./tools/glpi/glpi ticket get
./tools/glpi/glpi ticket followup - "[Sx] resumo + sha + proximo"
./tools/glpi/glpi project get
./tools/glpi/glpi project tasks
./tools/glpi/bin/glpi-seed-phases
./tools/glpi/bin/glpi-retro-scan
./tools/glpi/bin/glpi-task-upsert --code=S1.P1 --parent-code=S1 --apply
```

Skills: `glpi-followup`, `glpi-task-upsert`, `glpi-project-create`, `glpi-retro-scan`.

---

## 7. Independência entre produtos

| Artefato | Produto A | Produto B |
|----------|-----------|-----------|
| CLI + skill | cópia local | cópia local |
| `.glpi/project.yaml` | ticket/project próprios | ticket/project próprios |
| Secrets | `~/.secrets/` (máquina) | idem |

Exemplo histórico: samu-operacional (Ticket 10554 / Project 72) e Bot_Pan (Project 12) — cada um com sua vendorização; o kit não embute IDs de um produto como default obrigatório.

---

## 8. Roadmap (kit)

| Item | Status |
|------|--------|
| CLI auth / ticket / project / seed / task upsert | Feito |
| Skills glpi-* + wrappers `bin/` | Feito |
| `bootstrap-into` / `upgrade-into` | Feito |
| `retro-scan` + `retro-apply` | Feito |
| `--dry-run` no followup | Pendente |
| CI `glpi-notify` pós-deploy | Pendente |

---

*Atualizado em 21/07/2026: documentação alinhada ao pmf-dev-kit como fonte de integração.*
