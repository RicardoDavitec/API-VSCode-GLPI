---
name: glpi-retro-scan
description: >-
  Varre planos markdown e historico git (mono/polyrepo) e propoe a arvore
  F/S/P retroativa para o GLPI, com inferencia de fase e nivel de confianca.
  Com --pack, atomos só no content. Saida JSON revisavel.
  Use em retro-scan, glpi retro-scan, reconstruir historico glpi,
  importar projeto existente.
---

# Skill: glpi-retro-scan

Reconstroi, a partir de um repositorio **ja em andamento sem acompanhamento**,
a arvore completa de chamados do inicio do projeto ate o momento atual.

Fontes: `.glpi/workspace.yaml` (repos), `.glpi/model.defaults.yaml` + overlays
(modelo), `.glpi/maps/phase-map.json` (taxonomia legada).
Execucao: `tools/glpi/bin/` **deste** clone (nunca de outro).

## Comandos

~~~bash
./tools/glpi/bin/glpi-retro-scan
./tools/glpi/bin/glpi-retro-scan --with-git --since=2026-01-01
./tools/glpi/bin/glpi-retro-scan --repo=repo-antigo --phase-hint=F1
./tools/glpi/bin/glpi-retro-scan --plans-only
./tools/glpi/bin/glpi-retro-scan --git-only --session-window=week
./tools/glpi/glpi retro-scan --pack --pack-target-min=120
./tools/glpi/bin/glpi-retro-scan --out=docs/06_glpi/retro-scans/scan.json
~~~

Saida em `docs/06_glpi/retro-scans/scan-<YYYYMMDD-HHmm>.json` (+ `.md` legivel).
O sufixo `_pack` **nao sobrescreve** o artefato anterior.

## Mapa de niveis

| Nivel | GLPI | Fonte primaria |
|-------|------|----------------|
| F | `Project` filho ou `ProjectTask` n1 | `lifecycle.phases` — fixo F1..F5 |
| S | `ProjectTask` | secoes `### F2.S4` dos planos + janelas de commit |
| P (~2h) | `ProjectTask` | itens `- [ ]` dos planos + commits individuais |
| Atomo | só `content` | bullets internos, arquivos tocados |

## Inferencia de fase (precedencia decrescente)

1. **Code explicito** — `### F2.S4 …` ou `<!-- glpi: code="F2.S4" -->`.
   `phase_source=explicit`, `confidence=1.00`. **Vence sempre.**
2. **Taxonomia legada** — titulo casa `legacy_taxonomy[*].label`
   (ex.: "4.1 Implementação Front-end" -> F2, sugere `F2.S1`).
   `phase_source=legacy`, `confidence=0.90`.
3. **Conventional commit** — `commit_rules` do modelo
   (`docs|spec` -> F1 · `feat|fix|refactor|perf` -> F2 · `test|ci` -> F3 ·
   `deploy(homolog)` -> F4 · `release` -> F5).
   `phase_source=commit`, `confidence=0.75`.
4. **Branch** — `branch_rules` (`homolog`, `release/*` -> F4; `main` -> F5).
   `phase_source=branch`, `confidence=0.65`.
5. **Caminho tocado** — `evidence[F<n>]` do modelo.
   `phase_source=path`, `confidence=0.60`.
6. **`phase_hint`** do repo em `workspace.yaml`.
   `phase_source=hint`, `confidence=0.40`.
7. Nada casou -> `phase: "?"`, `confidence: 0`, `phase_source=unknown`.
   **Exige revisao humana**; a regra V10 do validate **bloqueia `--apply`**.

Cada no do JSON carrega `phase`, `phase_source`, `confidence` e `rationale`
para auditoria. `--min-confidence=0.7` rebaixa a `?` tudo abaixo do limiar.

## Agrupamento em sessoes

`sessions.window` (`day|week|sprint|branch`, default `week` com
`week_start: monday`) define o recorte de S. Cada S recebe:
`plan_start`/`plan_end` = limites da janela;
`real_start`/`real_end` = primeiro/ultimo commit efetivo da janela.

## Multi-repo e deduplicacao

`role` e `weight` de `workspace.yaml`:

| `role` | Tratamento |
|--------|------------|
| `primary` | gera S e P proprios |
| `variant` | commit equivalente entra como **atomo** no P do primary |
| `historical` | gera P só se nao houver equivalente no primary |

Equivalencia por similaridade de mensagem + conjunto de arquivos
(`--dedupe-threshold=0.85`).

## Modo `--pack`

Agrega atomos para que cada P atinja `--pack-target-min` minutos
(default = `effort.task_hours_default` x 60). Evita centenas de P de 5 minutos.
Atomos agregados ficam **só** no `content`.

## Fluxo canonico

~~~text
retro-scan  ->  revisar JSON (humano)  ->  glpi-tree-validate --from=JSON
          ->  glpi-phase-ensure --all --apply
          ->  glpi-retro-apply --from=JSON --apply
          ->  glpi-progress-rollup --apply
          ->  acompanhar-chamado --code=... (registro institucional)
~~~

## Regras

- **Nunca aplica nada.** Só produz artefato revisavel.
- Nao inventa `real_*`: só datas de `git log --date=iso-strict` ou dos planos.
- Respeita `safety.deny_content_regex` (nao copia segredo para o JSON).
- Planos em `legados/` entram com `archived: true` e nao geram S nova.

Refs: `docs/06_glpi/HIERARQUIA_F_S_P_GLPI.md` · `docs/06_glpi/MIGRACAO_V1_V2.md`