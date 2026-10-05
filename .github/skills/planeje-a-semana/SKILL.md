---
name: planeje-a-semana
description: >-
  Gera o Quadro de Trabalho Semanal a partir dos planos ativos F/S/P e do
  backlog do GLPI, respeitando a agenda real do analista (.glpi/agenda.yaml).
  Valida capacidade antes de gravar. Use em planeje a semana, quadro semanal,
  planilha de acompanhamento, alocar tarefas da semana.
argument-hint: "Opcional: AAAA-Wnn (ex: 2026-W41)."
---

# Skill: planeje-a-semana

Fecha o triangulo **plano tecnico → chamado institucional → agenda humana**.

## Cadeia

~~~text
docs/05_progresso/planos_ativos/*.md   (tarefas P pendentes)
          +
GLPI: chamados em nome do analista     (backlog institucional)
          +
.glpi/agenda.yaml                      (jornada, dedicacao, estrategia)
          v
docs/05_progresso/quadros_semanais/quadro_semanal-AAAA_Snn.{md,xlsx,ods,json}
~~~

## Comandos

~~~bash
# relatorio de capacidade (nao gera arquivo)
./tools/glpi/bin/glpi-weekly-sheet.py --capacidade

# semana atual, dry-run no terminal
./tools/glpi/bin/glpi-weekly-sheet.py

# gravar nos 3 formatos
./tools/glpi/bin/glpi-weekly-sheet.py --formato=md,xlsx,ods --write

# semana especifica + backlog real do GLPI
./tools/glpi/bin/glpi tickets --assigned-to=me --format=json > /tmp/bk.json
./tools/glpi/bin/glpi-weekly-sheet.py --semana=2026-W41 \
  --backlog-json=/tmp/bk.json --formato=xlsx --write

# quebrar tarefas longas em atomos (quando a tarde nao comporta)
./tools/glpi/bin/glpi-weekly-sheet.py --estrategia=atom --write
~~~

## A grade real (ATENCAO: periodos NAO sao iguais)

| Dia | Período manhã | Período tarde | Assimetria |
|-----|---------------|---------------|------------|
| seg · ter · qui · sex | **82,5 min** | **37,5 min** | 2,2x |
| qua | **95,0 min** | **30,0 min** | 3,2x |

~~~text
n_slots = teto( h_i / delta(d,p) )

Onde: h_i      = duracao da tarefa em minutos (--hours x 60)
      delta    = duracao do periodo naquele dia
      teto()   = arredondamento para cima
~~~

Consequencia: **um P de 2 h (120 min) nao cabe na tarde** (3 periodos
produtivos = 112,5 min na seg/ter/qui/sex e 90 min na quarta).
Por isso a estrategia default e `morning-first`.

## Estrategias de alocacao

| Estrategia | Comportamento |
|------------|---------------|
| `morning-first` (default) | P longo vai para a manha; tarde recebe atomos curtos |
| `slice` | P ocupa periodos contiguos; sobra vira folga |
| `atom` | quebra o P em atomos <= duracao do periodo |

## Capacidade e guarda

~~~text
C_d  = SOMA dos minutos dos periodos NAO reservados do dia
rho  = SOMA(h_i alocadas) / C_d   ->  deve ser <= max_ocupacao (1.0)
~~~

| Projeto | Dias | Capacidade | Tarefas P (2h) |
|---------|------|------------|----------------|
| Botão do Pânico | seg + ter | 12,00 h | 6,0 |
| PET-Saúde Digital | qua | 6,25 h (+1,5 h reunião) | 3,1 |
| SAMU-Operacional | qui + sex | 12,00 h | 6,0 |
| **TOTAL** | — | **30,25 h** | **15,1** |

`rho > 1.0` -> **exit 2**, nenhum arquivo e gravado.
`rho >= 0.85` -> aviso (risco de estouro com intercorrencia).

## Reserva institucional (nao negociar)

M1 (primeiro da manha) e T4 (ultimo da tarde) sao **sempre** `DISPONÍVEL`:

~~~text
R = (delta_M1 + delta_T4) / jornada = (82,5 + 37,5) / 480 = 25%
~~~

Um quarto da jornada para planejamento e intercorrencia. O gerador **recusa**
alocar nesses periodos, mesmo com `--force`.

## Priorizacao do backlog

1. estado `doing` (`[~]`) — o que ja comecou termina primeiro;
2. estado `testing` (`[t]`);
3. `plan_end` mais proximo;
4. fase menor (F1 antes de F2 ...);
5. ordem de code.

## Regras

- **Dry-run por padrao**: sem `--write` nada e gravado.
- Tarefas `done`/`closed` **nao** entram no quadro.
- Dia sem dedicacao em `agenda.yaml` fica vazio (nao inventa projeto).
- Compromisso fixo (reuniao PET) e **fora da grade**: nao consome periodo.
- Nunca altera os planos nem o GLPI — só **le**.
- Gera sidecar JSON para consumo por `glpi-node-upsert --plan-only`.

## Quando acionar

| Momento | Comando |
|---------|---------|
| Sexta, fim do dia (planejar a proxima) | `--semana=<proxima> --write` |
| Segunda, inicio (conferir) | `--capacidade` |
| Apos `documente-o-plano` | regerar o quadro da semana |
| Apos `glpi-commit-harvest` | regerar (tarefas fechadas saem do quadro) |

## Relacao com outras skills

| Skill | Papel |
|-------|-------|
| `documente-o-plano` | cria os P que alimentam o quadro |
| `glpi-backlog-export` | traz os chamados do GLPI para o backlog |
| `glpi-commit-harvest` | fecha P -> saem do quadro automaticamente |
| `glpi-node-upsert` | grava `plan_start`/`plan_end` derivados do quadro |
| `encerrar-sessao` | registra o que foi feito em cada periodo |

Dependencias: `pip install pyyaml openpyxl odfpy`