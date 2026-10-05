---
name: glpi-phase-ensure
description: >-
  Garante as 5 fases do ciclo de vida no GLPI (F1 Planejamento, F2 Implementacao,
  F3 Testes Internos, F4 Homologacao, F5 Aprovacao) como subprojeto ou
  ProjectTask conforme topology.phase_as. Idempotente. Pode adotar fases legadas.
  Use em criar fases, semear fases, garantir fases, glpi-seed-phases.
---

# Skill: glpi-phase-ensure

Materializa o **primeiro nivel de chamado** (a fase) sob o projeto raiz.
O operador **nao precisa saber** se a fase sera `Project` filho ou
`ProjectTask` nivel 1: isso vem de `topology.phase_as` resolvido nas camadas.

## Fases canonicas

| Code | Alias | Nome neutro | Peso default |
|------|-------|-------------|--------------|
| F1 | PLAN | Planejamento | 0.10 |
| F2 | IMPL | Implementacao | 0.40 |
| F3 | TINT | Testes Internos | 0.20 |
| F4 | HOMO | Homologacao | 0.20 |
| F5 | APRO | Aprovacao | 0.10 |

Nomes e estados podem ser sobrescritos pelo preset (ex.: acentuacao, estados GEP).

## Resolucao de template (NAO fixar nome de instituicao)

1. `--template=<id>` explicito;
2. `project.yaml:overrides.lifecycle.template`;
3. `presets/<preset>/model.overlay.yaml:lifecycle.template`;
4. `model.defaults.yaml:lifecycle.template` -> `lifecycle-5-phases`.

## Comandos

~~~bash
./tools/glpi/bin/glpi-phase-ensure --all
./tools/glpi/bin/glpi-phase-ensure --all --apply
./tools/glpi/bin/glpi-phase-ensure --only=F3,F5 --apply
./tools/glpi/bin/glpi-phase-ensure --all --adopt-legacy --apply
./tools/glpi/bin/glpi-phase-ensure --all --plan-from-children --apply
./tools/glpi/bin/glpi-phase-ensure --all --template=lifecycle-5-phases --dry-run
./tools/glpi/bin/glpi-phase-ensure --show-plan
~~~

## Parametros

| Flag | Default | Descricao |
|------|---------|-----------|
| `--all` | — | Garante F1..F5 |
| `--only=F2,F3` | — | Subconjunto |
| `--template=<id>` | resolvido | Override do template |
| `--adopt-legacy` | off | Reaproveita objeto legado em vez de criar novo |
| `--plan-from-children` | off | Datas da fase = min/max das sessoes filhas |
| `--plan-from-plan=FILE` | — | Datas a partir de um plano markdown |
| `--weights=F2:0.5,F3:0.1` | — | Override de pesos (soma deve dar 1.0) |
| `--show-plan` | — | Tabela antes/depois sem tocar na API |
| `--apply` | off | Efetiva (confirmacao) |

## Idempotencia

- Busca por `code` (se `Project`) ou por prefixo `[F<n>]` no `name`
  (se `ProjectTask`), restrito ao raiz do produto.
- Existe -> **atualiza** campos divergentes; nao existe -> **cria**.
- Nunca duplica. Nunca apaga.

## `--adopt-legacy` (migracao sem perda)

Le `legacy_taxonomy` (preset) + `legacy_phases` (produto) e, para cada fase
legada mapeada, **renomeia e reaponta** o objeto existente ao code novo,
preservando historico, tarefas, anexos e followups.

- Relacao legado -> F e **muitos-para-um**: a distincao perdida desce ao nivel S
  via `demote_to` (ex.: `4.1 Front-end` -> `F2.S1`).
- Exige `--apply` + **confirmacao dupla** (digitar o code do produto).
- Gera relatorio em `docs/06_glpi/retro-scans/adopt-legacy-<ts>.md`.
- `legacy.reverse_policy: forbid` -> a volta (F -> legado) e bloqueada.

## Validacoes pre-apply

- Soma dos pesos = 1.0 (tolerancia `weight_sum_tolerance`); senao aborta.
- Projeto raiz deve existir (`project_id` != null); senao sugere `glpi-project-upsert`.
- Se `phase_as: subproject`, verifica permissao de criar `Project`; na falta,
  sugere `--fallback=projecttask`.
- Janela de cada fase contida na janela do raiz.

## Efeitos colaterais

Grava `phases.F<n>.id` em `.glpi/project.yaml` e atualiza `.glpi/index.json`.

## Depreciacao

`glpi-seed-phases --template=samu-s-phases` fica **deprecated**: aquele template
semeia `S0..S7` como "fases", que no modelo atual sao **sessoes**. Equivalente:

~~~bash
./tools/glpi/bin/glpi-phase-ensure --all --apply
./tools/glpi/bin/glpi-session-seed --from=sessions-seed.example.json --phase=F2 --apply
~~~

Codigos de saida: `0` ok · `2` pesos invalidos · `4` raiz ausente ·
`5` API/permissao · `6` abortado.
