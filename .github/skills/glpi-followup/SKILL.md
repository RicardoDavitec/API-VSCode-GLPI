---
name: glpi-followup
description: "Envia ITILFollowup no chamado GLPI configurado em .glpi/project.yaml (auditoria institucional)."
---

# Skill: glpi-followup

Registra acompanhamento no chamado GLPI via CLI **deste** repositório.

## Pre-requisitos

- `curl`, `jq`
- Secrets (`~/.secrets/GLPI-tokens.txt` ou variáveis `GLPI_*`)
- `.glpi/project.yaml` com `ticket_id` válido
- `.glpi/instance.yaml` (preset `api-vscode-glpi` na equipe PMF)

## Comando

```bash
./tools/glpi/bin/glpi-followup - "<texto>"
# equivalente:
./tools/glpi/glpi ticket followup - "<texto>"
./tools/glpi/glpi ticket followup <ticket_id> "<texto>"
```

Exemplo PMF: ticket **10554** (Samu Operacional) — ver `project.yaml` do produto.

## Conteudo sugerido

1. Item do plano (ex.: S1.P1)
2. Resumo objetivo
3. Evidencia (commit sha, PR, health OK)
4. Proximo passo

## Regras

- Nao enviar senhas, tokens ou dados clinicos.
- Apos sucesso, marcar *follow-up GLPI enviado?* em `FLUXO_COMMIT_CHECKLIST.md`.
- Usar `./tools/glpi/bin/glpi-followup` deste clone.

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
