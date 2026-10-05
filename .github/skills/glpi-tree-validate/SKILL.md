---
name: glpi-tree-validate
description: >-
  Lint da arvore F/S/P (codes, profundidade, orfaos, janelas de data, coerencia
  estado/percentual, transicoes, pesos, secrets) antes de aplicar no GLPI.
  Exit code != 0 bloqueia o --apply das demais skills.
  Use em validar arvore glpi, lint glpi, conferir projeto glpi.
---

# Skill: glpi-tree-validate

Porteiro obrigatorio do fluxo. Valida **JSON local** (saida de scan/harvest)
ou o **estado remoto** no GLPI.

## Comandos

~~~bash
./tools/glpi/bin/glpi-tree-validate --from=docs/06_glpi/retro-scans/scan.json
./tools/glpi/bin/glpi-tree-validate --remote --project-code=MEUPROD
./tools/glpi/bin/glpi-tree-validate --from=JSON --strict
./tools/glpi/bin/glpi-tree-validate --remote --only=V04,V07,V08
./tools/glpi/bin/glpi-tree-validate --from=JSON --format=json --out=report.json
./tools/glpi/bin/glpi-tree-validate --from=JSON --fix-safe --apply
~~~

## Catalogo de regras

| ID | Regra | Sev. |
|----|-------|------|
| V01 | `code` casa com `codes.pattern` do modelo | erro |
| V02 | Profundidade <= `topology.max_depth` (3: F/S/P) | erro |
| V03 | Sem orfaos: todo S tem F; todo P tem S | erro |
| V04 | `plan_start(filho) >= plan_start(pai)` e `plan_end(filho) <= plan_end(pai)` | erro |
| V05 | `plan_start <= plan_end` e `real_start <= real_end` | erro |
| V06 | Coerencia estado x datas x percentual (`state_rules`) | erro |
| V07 | Pai `done`/`closed` só se **todos** os filhos `done`/`closed` | erro |
| V08 | `percent_done` do pai == rollup ponderado (tol. `tolerance_pp`) | aviso |
| V09 | Codes duplicados no mesmo projeto | erro |
| V10 | Fase `?` / `confidence` abaixo do minimo | **bloqueia apply** |
| V11 | P com `hours` > `effort.task_hours_max` | aviso |
| V12 | Secret em `name`/`content` (`safety.deny_content_regex`) | erro |
| V13 | Transicao de estado fora de `transitions` | erro |
| V14 | Soma de pesos das fases != 1.0 | erro |
| V15 | `closed` sem `accept_ref` | erro |
| V16 | Fase fora de F1..F5 do `lifecycle` | erro |
| V17 | S sem nenhum P (sessao vazia) | aviso |
| V18 | `name` de ProjectTask sem prefixo `[code]` | erro |
| V19 | `glpi-meta` ausente ou com code divergente do `name` | erro |
| V20 | Objeto legado referenciado sem entrada em `phase-map.json` | aviso |
| V21 | `real_end` no futuro em relacao a agora | erro |
| V22 | `real_start` anterior a `plan_start` em mais de `--date-slack` dias | aviso |
| V23 | S cujo somatorio de `hours` excede `effort.session_hours_target` x2 | aviso |
| V24 | Fase sem nenhuma S (fase vazia) com estado != `todo` | aviso |
| V25 | `project_id` ou `phases.F*.id` nulo em `project.yaml` apos apply | erro |
| V26 | Numeracao de S/P com lacuna (ex.: S1, S2, S5) | aviso |
| V27 | Dois P com o mesmo `src="git:<sha>"` (commit duplicado) | aviso |
| V28 | `hours` ausente em P (impede rollup ponderado) | aviso |
| V29 | Anexo referenciado inexistente no disco | erro |
| V30 | `accept_ref` apontando para arquivo ausente | erro |

## Severidades e efeito

| Severidade | Efeito |
|------------|--------|
| `erro` | exit code `2`; bloqueia `--apply` das demais skills |
| `bloqueia apply` | exit code `10`; especifico de V10 (fase nao inferida) |
| `aviso` | exit code `0`, mas listado no relatorio; com `--strict` vira erro |

## Parametros

| Flag | Default | Descricao |
|------|---------|-----------|
| `--from=FILE` | — | Valida JSON local (scan/harvest) |
| `--remote` | — | Valida o estado atual no GLPI |
| `--project-code=CODE` | `project.yaml` | Projeto alvo no modo remoto |
| `--only=V04,V07` | todas | Subconjunto de regras |
| `--skip=V08,V17` | — | Exclui regras |
| `--strict` | off | Promove todo aviso a erro |
| `--min-confidence=0.7` | 0.0 | Rebaixa a `?` nos abaixo do limiar (alimenta V10) |
| `--date-slack=2` | 2 | Dias de tolerancia em V22 |
| `--format=text\|json\|md` | `text` | Formato do relatorio |
| `--out=FILE` | stdout | Arquivo de saida |
| `--fix-safe` | off | Corrige apenas o que e inequivoco (ver abaixo) |
| `--quiet` | off | Só o exit code (uso em CI) |

## `--fix-safe` (correcoes inequivocas)

Corrige **somente** o que nao exige julgamento humano:

| Regra | Correcao automatica |
|-------|---------------------|
| V08 | recalcula `percent_done` do pai pelo rollup |
| V18 | reinsere o prefixo `[code]` no `name` |
| V19 | regrava o marcador `glpi-meta` a partir do `name` |
| V26 | **nao** corrige (renumerar quebraria rastreio) |
| V28 | aplica `effort.task_hours_default` ao P sem `hours` |

Nunca inventa `real_*`, nunca altera fase, nunca muda estado. Exige `--apply`.

## Exemplo de relatorio

~~~text
glpi-tree-validate · projeto MEUPROD · 2026-10-05 10:52
fonte: docs/06_glpi/retro-scans/scan-20261005-1030.json
nos: 1 raiz · 5 fases · 23 sessoes · 187 tarefas

ERROS (2)
  V03  F3.S2.P7   orfao: sessao F3.S2 nao existe no JSON nem no GLPI
  V06  F2.S9.P3   state=done sem real_end

BLOQUEIOS (1)
  V10  (4 nos)    fase "?" — revisar: ver campo rationale no JSON

AVISOS (5)
  V08  F2         percent 62 != rollup 58.4 (delta 3.6 p.p. > 1)
  V11  F2.S4.P1   hours=9 > task_hours_max=4 — quebrar em P menores
  V17  F5.S1      sessao sem nenhuma tarefa
  V26  F2         lacuna na numeracao: S1 S2 S3 S5 (falta S4)
  V27  F2.S7.P2   commit 9f3ac1e tambem em F2.S6.P8

RESULTADO: FALHOU (2 erros, 1 bloqueio)  ->  --apply BLOQUEADO
Sugestao: ./tools/glpi/bin/glpi-tree-validate --from=... --fix-safe --apply
~~~

## Uso em CI

~~~bash
./tools/glpi/bin/glpi-tree-validate --remote --project-code=MEUPROD --strict --quiet \
  || { echo "::error::arvore GLPI inconsistente"; exit 1; }
~~~

Codigos de saida: `0` ok · `2` erro(s) · `6` abortado · `10` V10 (fase `?`) ·
`11` fonte ilegivel · `5` API.
