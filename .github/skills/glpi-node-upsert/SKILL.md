---
name: glpi-node-upsert
description: >-
  Cria ou atualiza no S (sessao) ou P (tarefa) no GLPI resolvendo o pai pelo
  code F/S/P: estado, percentual, datas planejadas e reais, horas, commit de
  origem, anexo. Dry-run por padrao.
  Use em glpi-node-upsert, glpi-task-upsert, criar sessao, criar tarefa,
  atualizar tarefa, editar chamado de tarefa.
---

# Skill: glpi-node-upsert

Alias legado aceito: `glpi-task-upsert`. O **nivel e inferido do `--code`**:

| `--code` | Nivel | Itemtype | Vinculo do pai |
|----------|-------|----------|----------------|
| `F2` | F | conforme `phase_as` | delega a `glpi-phase-ensure` / `glpi-project-upsert` |
| `F2.S4` | S | `ProjectTask` | `projects_id` = id da fase; `projecttasks_id` = 0 |
| `F2.S4.P5` | P | `ProjectTask` | `projecttasks_id` = id de `[F2.S4]` |

Prefixo de produto opcional: `MEUPROD:F2.S4.P5` (multi-produto no mesmo clone).

## Comandos

~~~bash
# Sessao (2o nivel de chamado)
./tools/glpi/bin/glpi-node-upsert --code=F2.S4 \
  --name="Sprint 04 — fila offline" --state=doing --percent=60 \
  --plan-start="2026-07-20 08:00" --plan-end="2026-07-24 18:00" \
  --real-start="2026-07-20 09:05"

# Tarefa ancorada em commit (3o nivel)
./tools/glpi/bin/glpi-node-upsert --code=F2.S4.P5 \
  --name="Prototipo fila local" --state=done --percent=100 \
  --hours=2 --commit=9f3ac1e --apply

# Tarefa em teste interno
./tools/glpi/bin/glpi-node-upsert --code=F3.S1.P2 \
  --name="Regressao da fila" --state=testing --percent=90 --apply

# Atomos (nao viram objeto; entram no content do P)
./tools/glpi/bin/glpi-node-upsert --code=F2.S4.P5 \
  --atoms="enqueue;dequeue;teste manual SQLite" --apply

# Anexo junto do upsert
./tools/glpi/bin/glpi-node-upsert --code=F2.S4 \
  --attach=docs/05_progresso/planos_ativos/anexos/F2_S4_fila-24_07_26.md --apply

# Lote a partir de JSON (saida de retro-scan / commit-harvest)
./tools/glpi/bin/glpi-node-upsert --from=docs/06_glpi/retro-scans/scan.json --apply

# Inspecao / remocao de vinculo
./tools/glpi/bin/glpi-node-upsert --code=F2.S4.P5 --show
./tools/glpi/bin/glpi-node-upsert --code=F2.S4.P5 --move-to=F3.S1 --apply
~~~

## Parametros

| Flag | Tipo | Default | Descricao |
|------|------|---------|-----------|
| `--code` | code | — | **Obrigatorio** (ou `--from`) |
| `--name` | str | — | Titulo curto, sem o prefixo `[code]` |
| `--parent-code` | code | auto | Override da resolucao automatica |
| `--content` / `--describe` | str/@file | — | Corpo; `@arquivo` le do disco |
| `--atoms` | str`;`str | — | Itens atomicos -> bullets no `content` |
| `--state` | papel | — | `todo`\|`doing`\|`testing`\|`done`\|`closed` |
| `--percent` | 0..100 | derivado | `percent_done` |
| `--hours` | num | 2 | Peso `w_i` do rollup |
| `--plan-start` / `--plan-end` | ISO | — | Janela planejada |
| `--real-start` / `--real-end` | ISO | — | Janela real (**nunca inventar**) |
| `--commit` | sha | — | Grava `src="git:<sha>"` no meta; deriva datas reais |
| `--attach` | path | — | Anexa documento (delega a `glpi-document-attach`) |
| `--move-to` | code | — | Reparenta o no |
| `--from` | json | — | Processamento em lote |
| `--milestone` | flag | off | `is_milestone=1` |
| `--apply` | flag | off | Efetiva (confirmacao) |

## Nomenclatura gravada

~~~text
name    = "[F2.S4.P5] Prototipo fila local"
content = "<!-- glpi-meta: code=\"F2.S4.P5\" level=\"P\" src=\"git:9f3ac1e\" hours=\"2\" -->\n\n<descricao>\n\n- enqueue\n- dequeue"
~~~

O marcador `glpi-meta` e a fonte de verdade do code quando o itemtype nao tem
campo `code`. Nunca editar o `name` manualmente na UI do GLPI.

## Estados (papeis semanticos, nunca IDs)

| `--state` | Papel | real_start | real_end | percent | Fase tipica |
|-----------|-------|------------|----------|---------|-------------|
| `todo` | nao iniciado | vazio | vazio | 0 | qualquer |
| `doing` | em andamento | obrigatorio | vazio | 1..99 | F1, F2 |
| `testing` | em teste | obrigatorio | vazio | 80..99 | F3, F4 |
| `done` | concluido | obrigatorio | obrigatorio | 100 | qualquer |
| `closed` | aceito/fechado | obrigatorio | obrigatorio | 100 | F5 (exige `--accept-ref`) |

Aliases locais (`gep1`, `gep3`, `gep4`, `gep7`, `gep9`, `in_progress`) continuam
aceitos por retrocompatibilidade, **com aviso**. Transicoes fora de
`transitions` exigem `--force-transition` e sao registradas em followup.

## Regras

- **Dry-run por padrao**; `--apply` só com confirmacao. `GLPI_DRY_RUN=1` forca.
- Profundidade maxima 3 (F/S/P). **Atomos nao viram objeto** (`atom_as: content`).
- **Sem orfaos**: pai inexistente aborta com sugestao do comando que o cria.
- Contencao de datas: filho dentro da janela do pai; violacao = erro ou
  `--force-window` (estica o pai e registra aviso).
- `--hours > task_hours_max` (4h) -> aviso V11 sugerindo quebra do P.
- **Nao inventar `real_*`**: usar `git log --date=iso-strict`, dado do usuario
  ou deixar vazio.
- Nao enviar secrets (`safety.deny_content_regex`).
- Apos lotes: `glpi-progress-rollup --apply`.

## Pos-condicao recomendada

~~~bash
./tools/glpi/bin/glpi-tree-validate --remote --project-code=MEUPROD
./tools/glpi/bin/glpi-progress-rollup --apply
~~~

Anexo avulso: `glpi-document-attach --file=PATH --code=F2.S4.P5 --apply`.

Codigos de saida: `0` ok · `2` validacao · `3` code duplicado ·
`4` pai inexistente · `5` API · `6` abortado · `7` transicao invalida.