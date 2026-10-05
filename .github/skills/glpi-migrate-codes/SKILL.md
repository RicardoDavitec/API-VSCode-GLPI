---
name: glpi-migrate-codes
description: >-
  Migra codes do modelo v1 (S/P, PR/PH/R/H/I) para v2 (F/S/P) em planos markdown
  e no GLPI, com mapa revisavel. Nao apaga nada. Migracao reversa proibida.
  Use em migrar codes, migrar v1 para v2, consolidar fases legadas.
---

# Skill: glpi-migrate-codes

Converte a numeracao do modelo antigo (3 niveis) para o novo (4 niveis),
**sem perder historico**.

## O problema (por que exige revisao humana)

~~~text
phi: legado -> canonico   e SOBREJETIVA, nao INJETIVA

  1. Discovery  ─┐
  2. Analise    ─┼─> F1 Planejamento
  3. Projeto    ─┘
  4.1 Front-end ─┬─> F2 Implementacao
  4.2 Back-end  ─┘
  (nada)        ───> F3 Testes Internos   <-- FASE NOVA, sem origem
  5. Homologacao ──> F4 Homologacao
  6. Evolucao   ───> F5 Aprovacao

Logo NAO existe phi^-1: dado F2, nao se recupera front/back-end.
Por isso 'demote_to' rebaixa a distincao ao nivel S, e
legacy.reverse_policy = forbid bloqueia a volta.
~~~

Codes v1 sem fase (`S4`, `S4.P5`) tambem sao ambiguos: `S4` pode ter sido
planejamento, codigo ou teste. A fase e **inferida** e **proposta**, nunca
aplicada silenciosamente.

## Fluxo em 3 etapas

~~~bash
# 1. PROPOR (nao escreve) — gera mapa revisavel
./tools/glpi/bin/glpi-migrate-codes --dry-run

# 2. REVISAR (humano) — editar o campo "to" onde confidence < 1.0
$EDITOR docs/06_glpi/retro-scans/migrate-codes-20261005-1055.json

# 3. APLICAR
./tools/glpi/bin/glpi-migrate-codes --from=<mapa.json> --apply
~~~

## Comandos

~~~bash
./tools/glpi/bin/glpi-migrate-codes --dry-run
./tools/glpi/bin/glpi-migrate-codes --dry-run --scope=docs   # só markdown
./tools/glpi/bin/glpi-migrate-codes --dry-run --scope=glpi   # só remoto
./tools/glpi/bin/glpi-migrate-codes --from=mapa.json --apply
./tools/glpi/bin/glpi-migrate-codes --from=mapa.json --scope=docs --apply
./tools/glpi/bin/glpi-migrate-codes --legacy-phases --apply   # 7 fases -> 5
./tools/glpi/bin/glpi-migrate-codes --rollback=20261005-1055
~~~

## Parametros

| Flag | Default | Descricao |
|------|---------|-----------|
| `--dry-run` | on | Gera mapa; nunca escreve |
| `--from=FILE` | — | Mapa revisado a aplicar |
| `--scope=docs\|glpi\|all` | `all` | Onde migrar |
| `--legacy-phases` | off | Consolida as 7 fases legadas nas 5 novas |
| `--default-phase=F2` | — | Fase para codes sem inferencia (ultimo recurso) |
| `--min-confidence=0.8` | 0.0 | Abaixo do limiar vira `"to": "?"` |
| `--keep-alias` | on | Mantem o code antigo como alias no `content` |
| `--rollback=TS` | — | Reverte usando o backup daquele timestamp |
| `--apply` | off | Efetiva (confirmacao dupla) |

## Estrutura do mapa

~~~json
{
  "generated_at": "2026-10-05T10:55:00-03:00",
  "schema_from": 1,
  "schema_to": 2,
  "reverse_policy": "forbid",
  "entries": [
    {
      "from": "S1",
      "to": "F1.S1",
      "confidence": 0.95,
      "source": "path",
      "rationale": "plano cita docs/01_requisitos; 12 de 14 arquivos em docs/",
      "occurrences": [
        { "file": "docs/05_progresso/legados/plano-10_02_26.md", "line": 34 }
      ],
      "glpi": { "itemtype": "ProjectTask", "id": 418, "name": "S1 — MVP TARM" }
    },
    {
      "from": "S4.P5",
      "to": "?",
      "confidence": 0.0,
      "source": "unknown",
      "rationale": "titulo 'ajustes gerais' sem commit nem caminho associado",
      "action_required": "definir a fase manualmente antes de --apply"
    },
    {
      "from": "4.1",
      "to": "F2",
      "demote_to": "F2.S1",
      "confidence": 1.0,
      "source": "legacy_taxonomy",
      "rationale": "legacy_taxonomy do preset",
      "glpi": { "itemtype": "Project", "id": 24, "name": "4.1 Implementação Front-end" },
      "note": "distincao front-end desce para a sessao F2.S1"
    }
  ],
  "unresolved": 4,
  "blocking": true
}
~~~

`blocking: true` impede `--apply` enquanto houver `"to": "?"`.

## O que muda em cada escopo

### `--scope=docs` (planos markdown)

~~~diff
- - [x] **S1** Spike + contrato de fila
+ - [x] **F1.S1** Spike + contrato de fila
-   <!-- glpi: plan_start="2026-07-24 09:00" plan_end="2026-07-24 18:00" -->
+   <!-- glpi: code="F1.S1" plan_start="2026-07-24 09:00" plan_end="2026-07-24 18:00" -->
~~~

- Preserva marcadores `[ ]`/`[~]`/`[x]`, indentacao e datas.
- Com `--keep-alias`, insere `<!-- glpi-legacy: was="S1" -->`.
- Atualiza tabelas de organograma e links de anexos.
- Renomeia anexos `S1_*.md` -> `F1_S1_*.md` via `git mv` (preserva historico).

### `--scope=glpi` (remoto)

- `ProjectTask`: reescreve o `name` com o novo prefixo `[F1.S1]` e regrava o
  `glpi-meta`; **reparenta** sob a fase correta.
- `Project` legado (com `--legacy-phases`): renomeia ao code novo e reaponta
  `projects_id`; **nunca apaga**.
- Registra `ITILFollowup` em cada item migrado com o de/para.

## Garantias

- **Nada e apagado** (`legacy.never_delete: true`).
- Backup integral antes de escrever:
  `.glpi/.backups/migrate-<ts>/` (docs) + `migrate-<ts>.json` (estado remoto).
- `--rollback=<ts>` restaura ambos.
- **Confirmacao dupla**: digitar o code do produto.
- Migracao reversa (F -> legado) **recusada** incondicionalmente.
- Idempotente: code ja em v2 e ignorado (`skip: ja migrado`).

## Pos-condicao obrigatoria

~~~bash
./tools/glpi/bin/glpi-tree-validate --remote --project-code=MEUPROD   # exit 0
./tools/glpi/bin/glpi-progress-rollup --apply
~~~

Codigos de saida: `0` ok · `2` mapa invalido · `6` abortado ·
`10` entradas `?` pendentes · `13` tentativa de migracao reversa · `5` API.