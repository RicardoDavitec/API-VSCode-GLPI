---
name: glpi-progress-rollup
description: >-
  Recalcula percent_done e estado de forma ascendente (P -> S -> F -> Projeto)
  com pesos de esforco e pesos de fase. Mostra tabela antes/depois.
  Use em recalcular progresso, rollup glpi, atualizar percentual,
  consolidar andamento.
---

# Skill: glpi-progress-rollup

Mantem a coerencia vertical da arvore: ninguem edita percentual de pai a mao.

## Formulas

~~~text
Sessao (S):   %S = SOMA(w_i * %P_i) / SOMA(w_i)
                w_i   = horas estimadas da tarefa i (--hours; default 2h)

Fase (F):     %F = SOMA(W_j * %S_j) / SOMA(W_j)
                W_j   = SOMA das horas das tarefas da sessao j

Projeto:      %Proj = SOMA(alfa_k * %F_k),  com SOMA(alfa_k) = 1
                alfa_k = lifecycle.phases[k].weight
~~~

A fase agrega por **esforco**; o projeto agrega por **valor da fase**.
Uma fase de Aprovacao com 2 tarefas pode valer 10% do projeto.

## Comandos

~~~bash
./tools/glpi/bin/glpi-progress-rollup --project-code=MEUPROD
./tools/glpi/bin/glpi-progress-rollup --project-code=MEUPROD --apply
./tools/glpi/bin/glpi-progress-rollup --scope=F2 --apply
./tools/glpi/bin/glpi-progress-rollup --mode=simple --apply
./tools/glpi/bin/glpi-progress-rollup --mode=manual            # só relata
./tools/glpi/bin/glpi-progress-rollup --no-state --apply       # só percentual
./tools/glpi/bin/glpi-progress-rollup --from=scan.json --out=rollup.json
./tools/glpi/bin/glpi-progress-rollup --project-code=MEUPROD --format=md \
  --out=docs/06_glpi/retro-scans/rollup-$(date +%Y%m%d).md
~~~

## Modos

| `--mode` | Comportamento |
|----------|---------------|
| `weighted` (default) | media ponderada por `hours` |
| `simple` | media aritmetica dos filhos (todos com peso 1) |
| `manual` | **nao escreve**; só relata divergencias (auditoria) |

O default vem de `rollup.mode` no modelo resolvido.

## Propagacao de estado

Com `rollup.propagate_state: true` (default), o estado do pai e derivado:

| Condicao nos filhos | Estado do pai |
|---------------------|---------------|
| todos `todo` | `todo` |
| algum `doing` ou `0 < % < 100` | `doing` |
| todos `testing`/`done`, nenhum pendente, algum `testing` | `testing` |
| **todos** `done` ou `closed` | `done` |
| todos `closed` **e** fase = F5 **e** ha `accept_ref` | `closed` |

Regra dura (V07): o pai só alcanca `done`/`closed` se **todos** os filhos la
estiverem. Nunca "arredonda" para cima.

## Datas derivadas

Com `--dates` (ou `rollup.derive_dates: true`):

~~~text
plan_start(pai) = min(plan_start dos filhos)
plan_end(pai)   = max(plan_end   dos filhos)
real_start(pai) = min(real_start dos filhos nao vazios)
real_end(pai)   = max(real_end   dos filhos)  -> SÓ se todos tiverem real_end
~~~

`real_end` do pai permanece vazio enquanto houver filho sem `real_end`.

## Saida (tabela antes/depois)

~~~text
glpi-progress-rollup · MEUPROD · mode=weighted · DRY-RUN

code       nivel  filhos  horas   %antes  %depois  delta   estado antes -> depois
---------------------------------------------------------------------------------
F1.S1      S          6     12h    100.0    100.0    0.0   done     -> done
F1.S2      S          4      8h     75.0     75.0    0.0   doing    -> doing
F1         F          2     20h     88.0     90.0   +2.0   doing    -> doing
F2.S4      S          9     18h     60.0     58.3   -1.7   doing    -> doing
F2         F          7    112h     62.0     58.4   -3.6   doing    -> doing
F3         F          1      4h      0.0     12.5  +12.5   todo     -> doing   (*)
F4         F          0      0h      0.0      0.0    0.0   todo     -> todo
F5         F          0      0h      0.0      0.0    0.0   todo     -> todo
MEUPROD    raiz       5    136h     38.5     36.6   -1.9   doing    -> doing

(*) mudanca de estado: F3 deixa de estar "nao iniciado"
pesos de fase: F1=0.10 F2=0.40 F3=0.20 F4=0.20 F5=0.10  (soma=1.000 OK)
7 no(s) seriam atualizados. Use --apply para efetivar.
~~~

## Regras

- **Dry-run por padrao**; `--apply` só com confirmacao. `GLPI_DRY_RUN=1` forca.
- Processa **de baixo para cima** (P -> S -> F -> raiz) em uma unica passada.
- **Nao altera folhas**: `%` de P só muda por `glpi-node-upsert`/`commit-harvest`.
- P sem `hours` recebe `effort.task_hours_default` com aviso (V28).
- Se `SOMA(alfa_k) != 1` (tolerancia 0.001), **aborta** (V14).
- `--scope=F2` limita a subarvore, mas o raiz e recalculado de todo modo.
- Idempotente: rodar duas vezes seguidas produz zero mudanca na segunda.
- Divergencia > `rollup.tolerance_pp` e reportada como V08 ao validate.

## Quando rodar

| Momento | Comando |
|---------|---------|
| Apos lote de `node-upsert` | `--apply` |
| Apos `retro-apply` | `--apply` |
| Apos `commit-harvest --apply` | `--apply` |
| Antes de reuniao de status | `--mode=manual --format=md` |
| Em CI noturno | `--mode=manual --quiet` (detecta deriva manual na UI) |

Codigos de saida: `0` ok · `2` pesos invalidos · `4` projeto nao resolvido ·
`5` API · `6` abortado.
