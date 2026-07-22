---
name: glpi-followup
description: "Envia ITILFollowup no chamado GLPI configurado em .glpi/project.yaml (auditoria institucional). Opcional: anexar evidência (SESSAO_*, plano)."
---

# Skill: glpi-followup

Registra acompanhamento no chamado GLPI via CLI **deste** repositório.

## Pre-requisitos

- `curl`, `jq`
- Secrets (`~/.secrets/GLPI-tokens.txt` ou variáveis `GLPI_*`)
- `.glpi/project.yaml` com `ticket_id` válido
- `.glpi/instance.yaml` (preset `api-vscode-glpi` na equipe PMF)

## Comando — follow-up (texto)

```bash
./tools/glpi/bin/glpi-followup - "<texto>"
# equivalente:
./tools/glpi/glpi ticket followup - "<texto>"
./tools/glpi/glpi ticket followup <ticket_id> "<texto>"
```

## Anexo opcional (após o follow-up)

Evidência periódica (`SESSAO_*`, plano, relatório) no **mesmo Ticket**:

```bash
# dry-run
./tools/glpi/bin/glpi-document-attach --file=docs/05_progresso/geral/SESSAO_....md --ticket

# gravar
./tools/glpi/bin/glpi-document-attach --file=docs/05_progresso/geral/SESSAO_....md --ticket --apply
```

Perguntar ao usuário antes de `--apply` no anexo.

## Conteudo sugerido (texto)

1. Item do plano (ex.: S1.P1)
2. Resumo objetivo
3. Evidencia (commit sha, PR, health OK)
4. Proximo passo

## Regras

- Nao enviar senhas, tokens ou dados clinicos.
- Nao anexar `.env`, `*token*`, `*secret*`, `*credential*`.
- Apos sucesso, marcar *follow-up GLPI enviado?* em `FLUXO_COMMIT_CHECKLIST.md`.
- Usar wrappers `tools/glpi/bin/` deste clone.

## Auxiliares

```bash
./tools/glpi/glpi ticket get
./tools/glpi/glpi project tasks
./tools/glpi/glpi states discover --apply
```

## Referencias

- `docs/06_glpi/MANUAL_USO_GLPI.md`
- `docs/06_glpi/MANUAL_INTEGRACAO_GLPI.md`
- `tools/glpi/README.md`
