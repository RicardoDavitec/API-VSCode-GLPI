---
name: glpi-followup
description: "Envia ITILFollowup no chamado GLPI do SAMU Operacional (auditoria institucional)."
---

# Skill: glpi-followup (samu-operacional)

Registra acompanhamento no chamado GLPI via CLI **deste** repositório.

## Pre-requisitos

- `curl`, `jq`
- `~/.secrets/GLPI-tokens.txt`: Pessoal → user_token; Grupo → App-Token
- Config `.glpi/project.yaml` (`ticket_id: 10554`, `project_id: 72`)

## Comando

```bash
./tools/glpi/bin/glpi-followup - "<texto>"
# equivalente:
./tools/glpi/glpi ticket followup - "<texto>"
./tools/glpi/glpi ticket followup 10554 "<texto>"
```

## Conteudo sugerido

1. Item do plano (ex.: S1.1)
2. Resumo objetivo
3. Evidencia (commit sha, PR, health OK)
4. Proximo passo

## Regras

- Nao enviar senhas, tokens ou dados clinicos.
- Apos sucesso, marcar *follow-up GLPI enviado?* em `FLUXO_COMMIT_CHECKLIST.md`.
- Usar `./tools/glpi/bin/glpi-followup` (ou `./tools/glpi/glpi` deste clone).
- Docs/hierarquia Bot_Pan nao pertencem a este repo.

## Auxiliares

```bash
./tools/glpi/glpi ticket get
./tools/glpi/glpi project tasks
./tools/glpi/glpi seed-phases
```

## Referencias

- `docs/06_glpi/MANUAL_USO_GLPI.md` (manual completo)
- `docs/06_glpi/INTEGRACAO_GLPI_GESTAO_PROJETOS.md`
- `tools/glpi/README.md`
