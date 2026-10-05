---
name: documente-o-plano
description: >-
  Cria ou atualiza plano F/S/P com timestamps GLPI. Grava em
  docs/05_progresso/planos_ativos/ (+ anexos). Encerrado/paralelo -> legados/
  no mesmo ciclo. Use em documente o plano, criar plano, planejar sprint,
  planejar sessao, atualizar plano.
argument-hint: "Titulo curto do plano."
---

# Skill: documente-o-plano

Planos Markdown para humanos **e** agentes, alinhados a `docs/01_requisitos`
(ou `docs/01-requisitos`) e ao padrao GLPI
**F = fase · S = sessao/sprint/semana · P = tarefa (commit)**.

O plano e a fonte de verdade do que **vai** acontecer (`todo`); os commits sao a
fonte do que **aconteceu** (`done`). As duas se encontram no mesmo code.

## Linha de producao

`docs/05_progresso/planos_ativos/` contem **só** o plano vigente + os anexos
**desse** plano (regra `.cursor/rules/planos-linha-producao.mdc` se existir).

- Gravar aqui **somente** se o usuario declarar linha vigente, ou segunda linha
  **concorrente e explicita**.
- Rascunho, spike, ideia fechada, plano ja `[x]` -> `docs/05_progresso/legados/`.
- Encerrar/substituir/paralelizar -> `git mv` para `legados/` **no mesmo ciclo**,
  levando os anexos junto.
- Pendencias atemporais -> `docs/05_progresso/pendencias/` (skill `inserir-pendencia`).

Se `planos_ativos/` nao existir: **criar** a pasta + `README.md` + `anexos/`
(nao voltar ao layout antigo `docs/05_progresso/<modulo>/`).

## Fluxo

1. Ler requisitos. Vazios/incoerentes -> **recomendar atualiza-los**; nao inventar RN.
2. Identificar a **fase** (F1..F5) a que o plano pertence. Um plano pode cobrir
   mais de uma fase, mas cada S pertence a **exatamente uma**.
3. Nomear:
   ~~~text
   docs/05_progresso/planos_ativos/<nome_do_plano>-DD_MM_AA-hh_mm.md
   docs/05_progresso/planos_ativos/anexos/F2_S1_<slug>-DD_MM_AA.md
   ~~~
4. Cada F -> secao propria. Cada S -> paragrafo no plano + link ao anexo.
5. Aplicar o template e os timestamps (abaixo). Atualizar `planos_ativos/README.md`.
6. **Sugerir** (nao executar sem pedido): `glpi-retro-scan`, `glpi-tree-validate`.

## Hierarquia e codificacao

| Nivel | Code | Significado | Vira chamado? |
|-------|------|-------------|---------------|
| F (fase) | `F1`..`F5` | PLAN · IMPL · TINT · HOMO · APRO (fixo) | sim — 1o nivel |
| S (sessao) | `F2.S1`, `F2.S2` | sessao / sprint / semana | sim — 2o nivel |
| P (tarefa) | `F2.S1.P1` | ~2h, ancorada em commit | sim — 3o nivel |
| Atomo | — | bullet interno | **nao** — só `content` do P |

Fases canonicas: **F1** Planejamento · **F2** Implementacao ·
**F3** Testes Internos · **F4** Homologacao · **F5** Aprovacao.

Codes legados `PR/PH/R/H/I` e `S4` (sem fase) estao **descontinuados**:

~~~bash
./tools/glpi/bin/glpi-migrate-codes --dry-run
~~~

## Marcadores e estados

| Marcador | Papel | plan_* | real_start | real_end |
|----------|-------|--------|------------|----------|
| `- [ ]` | `todo` | obrigatorio | omitir | omitir |
| `- [~]` | `doing` | obrigatorio | obrigatorio | omitir |
| `- [t]` | `testing` | obrigatorio | obrigatorio | omitir |
| `- [x]` | `done` | obrigatorio | obrigatorio | obrigatorio |
| `- [A]` | `closed` | obrigatorio | obrigatorio | obrigatorio + `accept_ref` |

~~~html
<!-- glpi: code="F2.S1.P1" plan_start="..." plan_end="..." real_start="..." real_end="..." -->
~~~

`- [t]` e `- [A]` sao **novidades**: existem porque a instancia tem estados
proprios de "Testando" e "Fechado" que o modelo antigo nao usava.

## Regras duras

- **Nao inventar `real_*`.** Sem dado -> omitir o atributo.
- **Nao inventar RN** (regra de negocio). Requisito faltante -> acao de documentar.
- **Nao commitar secrets** no plano nem nos anexos.
- Plano principal **curto** (organograma + 1 paragrafo por S); detalhe nos anexos.
- Janela do filho contida na do pai (sera cobrado por V04 no validate).
- P com mais de 4h -> quebrar (sera cobrado por V11).
- Numeracao de S continua **por fase**: a 1a sessao de F3 e `F3.S1`, nao `F3.S8`.

## Template

Ver `docs/05_progresso/planos_ativos/README.md` e o exemplo canonico
`.glpi/templates/template-exemplo.md`.

## Integracao com o GLPI

~~~text
documente-o-plano   ->  plano com codes F/S/P e estados todo
        |
        v
glpi-retro-scan     ->  JSON de candidatos (le os codes do plano)
        |
        v
glpi-tree-validate  ->  exit 0 obrigatorio
        |
        v
glpi-retro-apply    ->  cria F/S/P no GLPI
        |
        v
glpi-commit-harvest ->  commits fecham os P (todo -> done)
        |
        v
glpi-progress-rollup -> consolida % e estados para cima
~~~