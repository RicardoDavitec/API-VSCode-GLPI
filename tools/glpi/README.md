# CLI GLPI — pmf-dev-kit

CLI **genérico** para API REST GLPI + preset **`api-vscode-glpi`** (exemplo PMF Franca).

Integração passo a passo: `docs/06_glpi/MANUAL_INTEGRACAO_GLPI.md`  
Assistentes: `scripts/install-glpi.sh` · `scripts/install_glpi.py`

## Retro-scan (timestamps e GEP)

O `retro-scan` preenche datas a partir de **commits** e de **checklists/planos sem code S/P**:

- **commits:** mesmo dia encadeia `real_start`←commit anterior; 1º do dia estima duração (`GLPI_RETRO_ESTIMATE_MINUTES`, default 60)
- **checklists/planos `[x]`/`[~]`:** `git blame` na linha do markdown → `real_end`; itens do mesmo arquivo no mesmo dia encadeiam início (`git-blame-chain`)
- **fallback:** similaridade de título checklist↔commit (`GLPI_RETRO_COMMIT_MATCH_MIN`, default 0.35)
- **planos Bot_Pan:** fases `R1`/`P7.1`/`Prioridade N`/`Fase 0` + itens de tabela e `**8.3.a**` em checkboxes
- **comentário HTML em checklist:** `<!-- glpi: plan_start="..." plan_end="..." real_start="..." real_end="..." temporal_source="..." -->` (mesma linha ou linha seguinte ao `- [x]`) tem prioridade sobre blame/commits
- plano/checklist com colunas Plan/Real têm prioridade; commits/blame preenchem `null`
- status: `[x]`/`done` → `gep7`; `[~]` → `gep3`; `[ ]` → `gep1`; só commit → `gep7` (retro)
- **após GEP:** `gep1` zera `real_start`/`real_end`; `gep3` zera `real_end` — **exceto** timestamps confirmados (`temporal_source` `plan` / `checklist-comment`)

```bash
./tools/glpi/glpi retro-scan
# dry-run do apply (não grava GLPI):
./tools/glpi/bin/glpi-retro-apply --from=docs/06_glpi/retro-scans/ARQUIVO.json
```

## Documentos (anexo)

```bash
# dry-run
./tools/glpi/bin/glpi-document-attach --file=docs/05_progresso/geral/SESSAO_....md --ticket
# gravar no Ticket / Project / ProjectTask
./tools/glpi/glpi document attach --file=PATH --ticket --apply
./tools/glpi/glpi document attach --file=PATH --project --apply
./tools/glpi/glpi document attach --file=PATH --code=S4.P1 --apply
# via upsert
./tools/glpi/bin/glpi-task-upsert --code=S4.P1 --name="..." --attach=PATH --apply
```

## Presets

| Preset | Descrição |
|--------|-----------|
| `api-vscode-glpi` (default) | VSCode ↔ Git ↔ GLPI — exemplo PMF |
| `generic` | Qualquer instância GLPI |

Config: `.glpi/instance.yaml` + `.glpi/project.yaml`

## Wrappers (`tools/glpi/bin/`)

`glpi-followup` · `glpi-seed-phases` · `glpi-task-upsert` · `glpi-retro-scan` · `glpi-retro-apply` · `glpi-project-create` · `glpi-document-attach`

## Secrets

| Formato | Labels |
|---------|--------|
| `pmf` | Pessoal API-GLPI · Grupo API-GLPI · URL-API |
| `generic` | USER_TOKEN · APP_TOKEN · API_URL |

Path: `~/.secrets/GLPI-tokens.txt` (override: `GLPI_SECRETS_FILE`)

## Estados

`.glpi/maps/states.json` — gerado por `glpi states discover --apply` ou seed do preset.

Exemplo PMF: aliases `gep1`, `gep3`, `gep7`…
