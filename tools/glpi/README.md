# CLI GLPI (MVP) — samu-operacional

Cópia **local** do CLI de gestão GLPI.  
Cada repositório PMF mantém sua própria cópia (não usar o CLI de outro clone).

Hierarquia: **S = tarefa pai** · **P = subtarefa filho** → `docs/06_glpi/HIERARQUIA_S_P_GLPI.md`

## Execução direta (sem skill)

Wrappers em `tools/glpi/bin/` — as skills **chamam estes scripts**:

| Script | Função |
|--------|--------|
| `bin/glpi-project-create` | Cria Project |
| `bin/glpi-seed-phases` | Seed pais S0–S7 |
| `bin/glpi-retro-scan` | Levantamento S/P (dedupe por code) |
| `bin/glpi-retro-apply` | Aplica JSON pai→filho |
| `bin/glpi-task-upsert` | Upsert uma task |
| `bin/glpi-followup` | Follow-up no Ticket |

```bash
./tools/glpi/bin/glpi-retro-scan
./tools/glpi/bin/glpi-retro-apply --from=docs/06_glpi/retro-scans/ARQUIVO.json
./tools/glpi/bin/glpi-retro-apply --from=... --kinds=phase --limit=8
./tools/glpi/bin/glpi-task-upsert --code=S4.P5 --parent-code=S4 --name="..." --apply
```

## Pré-requisitos

- `bash`, `curl`, `jq`, `python3`
- `~/.secrets/GLPI-tokens.txt` (Pessoal=user_token, Grupo=App-Token)

## Config

- `.glpi/project.yaml` — ticket 10554, project 72, template `samu-s-phases`
- `.glpi/templates/samu-s-phases.json` — pais S0–S7
- `.glpi/workspace.yaml` — polyrepo
- `.glpi/state-project-72.json` — ids locais

## CLI completo

```bash
./tools/glpi/glpi --help
./tools/glpi/glpi seed-phases --template=samu-s-phases
./tools/glpi/glpi retro-scan
./tools/glpi/glpi retro-apply --from=...json
```

Skills: `glpi-followup`, `glpi-task-upsert`, `glpi-project-create`, `glpi-retro-scan`  
Docs: `docs/06_glpi/MANUAL_USO_GLPI.md`, `HIERARQUIA_S_P_GLPI.md`
