# CLI GLPI — pmf-dev-kit

CLI **genérico** para API REST GLPI + preset **`api-vscode-glpi`** (exemplo PMF Franca).

Integração passo a passo: `docs/06_glpi/MANUAL_INTEGRACAO_GLPI.md`  
Assistentes: `scripts/install-glpi.sh` · `scripts/install_glpi.py`

## Comandos principais

```bash
./tools/glpi/glpi auth
./tools/glpi/glpi states discover --apply    # v1: mapa de estados via API
./tools/glpi/glpi ticket followup - "texto"
./tools/glpi/glpi task upsert --code=S4.P1 --parent-code=S4 --apply
./tools/glpi/glpi seed-phases --template=corporate-phases
./tools/glpi/glpi retro-scan
```

## Presets

| Preset | Descrição |
|--------|-----------|
| `api-vscode-glpi` (default) | VSCode ↔ Git ↔ GLPI — exemplo PMF |
| `generic` | Qualquer instância GLPI |

Config: `.glpi/instance.yaml` + `.glpi/project.yaml`

## Wrappers (`tools/glpi/bin/`)

`glpi-followup` · `glpi-seed-phases` · `glpi-task-upsert` · `glpi-retro-scan` · `glpi-retro-apply` · `glpi-project-create`

## Secrets

| Formato | Labels |
|---------|--------|
| `pmf` | Pessoal API-GLPI · Grupo API-GLPI · URL-API |
| `generic` | USER_TOKEN · APP_TOKEN · API_URL |

Path: `~/.secrets/GLPI-tokens.txt` (override: `GLPI_SECRETS_FILE`)

## Estados

`.glpi/maps/states.json` — gerado por `glpi states discover --apply` ou seed do preset.

Exemplo PMF: aliases `gep1`, `gep3`, `gep7`…
