# 06_glpi — Integração GLPI

Gestão de Ticket / Project / ProjectTask (hierarquia **S**=pai, **P**=filho) via o kit fonte **pmf-dev-kit**.

## Documentos

| Documento | Conteúdo |
|-----------|----------|
| **[`MANUAL_INTEGRACAO_GLPI.md`](MANUAL_INTEGRACAO_GLPI.md)** | Manual passo a passo (projetos novos e pré-existentes, secrets, WSL/Windows) — também na [página de rosto](../../README.md) |
| [`MANUAL_USO_GLPI.md`](MANUAL_USO_GLPI.md) | CLI, configs `.glpi/`, env, skills, troubleshooting |
| [`INTEGRACAO_GLPI_GESTAO_PROJETOS.md`](INTEGRACAO_GLPI_GESTAO_PROJETOS.md) | Visão de gestão e modelo de distribuição do kit |
| [`HIERARQUIA_S_P_GLPI.md`](HIERARQUIA_S_P_GLPI.md) | Mapeamento plano ↔ ProjectTask (S/P) |
| [`REAVALIACAO_VSCODE_GIT_GLPI.md`](REAVALIACAO_VSCODE_GIT_GLPI.md) | Gap VSCode ↔ Git ↔ GLPI |
| `GLPI-rest-API-documentationmd` | Referência API REST (cópia) |

## Ferramentas

- CLI: `tools/glpi/glpi`
- Wrappers: `tools/glpi/bin/glpi-*`
- Bootstrap: `scripts/bootstrap-into.sh` / `scripts/upgrade-into.sh`
- Secrets: `~/.secrets/GLPI-tokens.txt` (fora do git)

## Gitness

[PMF-Integracao_GLPI/pmf-dev-kit](https://gitness.franca.sp.gov.br/PMF-Integracao_GLPI/pmf-dev-kit)
