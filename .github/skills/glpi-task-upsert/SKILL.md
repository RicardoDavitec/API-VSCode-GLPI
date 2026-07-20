---
name: glpi-task-upsert
description: "Cria/atualiza ProjectTask no GLPI com hierarquia S(pai)/P(filho). Estado GEP, %, datas."
---

# Skill: glpi-task-upsert (samu-operacional)

Atualiza a **tarefa de projeto** (`ProjectTask`) no GLPI.

**Execução preferencial:** `./tools/glpi/bin/glpi-task-upsert` (wrapper; a skill só orquestra).

## Hierarquia

| Plano | Código | GLPI | Flag |
|-------|--------|------|------|
| Fase / semana | `S4` | Tarefa **pai** | `--code=S4` |
| Item | `S4.P5` | **Subtarefa** | `--code=S4.P5 --parent-code=S4` |

## Comandos

```bash
# Pai
./tools/glpi/bin/glpi-task-upsert --code=S4 --name="S4 — Unidade móvel" --state=gep3 --percent=60

# Filho
./tools/glpi/bin/glpi-task-upsert --code=S4.P5 --parent-code=S4 \
  --name="Fila offline sync" --state=gep1 --percent=0

# Gravar
./tools/glpi/bin/glpi-task-upsert --code=S4.P5 --parent-code=S4 --name="..." --apply
```

Lote a partir do retro-scan: `./tools/glpi/bin/glpi-retro-apply --from=JSON [--apply]`.

## Regras

- Dry-run por padrão; `--apply` só com confirmação.
- `GLPI_DRY_RUN=1` força dry-run.
- Pais S0–S7: `./tools/glpi/bin/glpi-seed-phases --template=samu-s-phases`

## Referências

- `docs/06_glpi/HIERARQUIA_S_P_GLPI.md`
- `tools/glpi/bin/glpi-task-upsert`
- `.glpi/maps/states.json`
