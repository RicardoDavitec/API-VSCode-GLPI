# CLI GLPI (MVP) — pmf-dev-kit

Cópia **local** do CLI de gestão GLPI, distribuída pelo kit  
[PMF-Integracao_GLPI/pmf-dev-kit](https://gitness.franca.sp.gov.br/PMF-Integracao_GLPI/pmf-dev-kit).

Cada produto PMF mantém sua própria cópia (não usar o CLI de outro clone).

Hierarquia: **S = tarefa pai** · **P = subtarefa filho** → `docs/06_glpi/HIERARQUIA_S_P_GLPI.md`  
Integração passo a passo: `docs/06_glpi/MANUAL_INTEGRACAO_GLPI.md`

## Wrappers (`tools/glpi/bin/`)

As skills **chamam estes scripts**:

| Script | Função |
|--------|--------|
| `bin/glpi-project-create` | Cria Project |
| `bin/glpi-seed-phases` | Seed de fases (pais) |
| `bin/glpi-retro-scan` | Levantamento S/P (dedupe por code) |
| `bin/glpi-retro-apply` | Aplica JSON pai→filho |
| `bin/glpi-task-upsert` | Upsert uma task |
| `bin/glpi-followup` | Follow-up no Ticket |

```bash
./tools/glpi/bin/glpi-retro-scan
./tools/glpi/bin/glpi-retro-apply --from=docs/06_glpi/retro-scans/ARQUIVO.json
./tools/glpi/bin/glpi-task-upsert --code=S4.P5 --parent-code=S4 --name="..." --apply
```

## Pré-requisitos

- `bash`, `curl`, `jq`, `python3`
- `~/.secrets/GLPI-tokens.txt` (Pessoal=user_token, Grupo=App-Token, URL-API)
- Ver manual de integração para WSL / Windows e variáveis `GLPI_*`

## Config (no produto)

- `.glpi/project.yaml` — `ticket_id`, `project_id`, `phase_template`
- `.glpi/templates/corporate-phases.json` — Discovery→Evolução
- `.glpi/templates/product-s-phases.example.json` — exemplo S0–S7 (adaptar)
- `.glpi/workspace.yaml` — polyrepo / retro-scan
- `.glpi/maps/states.json` — aliases GEP

## CLI completo

```bash
./tools/glpi/glpi --help
./tools/glpi/glpi auth
./tools/glpi/glpi seed-phases --template=corporate-phases
./tools/glpi/glpi retro-scan
./tools/glpi/glpi retro-apply --from=...json
```

Skills: `glpi-followup`, `glpi-task-upsert`, `glpi-project-create`, `glpi-retro-scan`  
Docs: `docs/06_glpi/MANUAL_USO_GLPI.md`, `MANUAL_INTEGRACAO_GLPI.md`
