---
name: glpi-backlog-export
description: >-
  Exporta do GLPI os chamados e tarefas atribuidos ao analista (Ticket e
  ProjectTask F/S/P) em JSON para alimentar o quadro semanal.
  Somente leitura. Use em exportar backlog, meus chamados, backlog glpi.
---

# Skill: glpi-backlog-export

Traz a visao **institucional** do que esta atribuido ao analista, para
compor o backlog junto com os P dos planos ativos.

## Comandos

~~~bash
./tools/glpi/bin/glpi-backlog-export --assigned-to=me
./tools/glpi/bin/glpi-backlog-export --assigned-to=me --out=/tmp/bk.json
./tools/glpi/bin/glpi-backlog-export --project-code=BOTPAN,SAMUOP,PETSD
./tools/glpi/bin/glpi-backlog-export --include=tickets,tasks
./tools/glpi/bin/glpi-backlog-export --status=Novo,"Em atendimento",Pendente
~~~

## Fontes consultadas

| Itemtype | Filtro | Papel no backlog |
|----------|--------|------------------|
| `Ticket` | `users_id_assign = analista` | chamado institucional (incidente/requisicao) |
| `ProjectTask` | `users_id = analista`, nivel P | tarefa de projeto ja registrada |
| `ITILFollowup` | ultimos 7 dias | detecta chamado reaberto |

## Saida (consumida por `planeje-a-semana`)

~~~json
[
  {
    "id": 1514,
    "itemtype": "Ticket",
    "name": "Incidente [GLPI-1514]",
    "state": "todo",
    "status_glpi": "Novo",
    "project_code": "BOTPAN",
    "code": null,
    "hours": 2.0,
    "priority": 3,
    "date_mod": "2026-10-03T09:12:00-03:00",
    "url": "https://suporte.franca.sp.gov.br/front/ticket.form.php?id=1514"
  },
  {
    "id": 2543,
    "itemtype": "Ticket",
    "name": "Requisição [GLPI – SIGS - SAMU 2543]",
    "state": "doing",
    "status_glpi": "Em atendimento",
    "project_code": "SAMUOP",
    "hours": 4.0,
    "priority": 4
  },
  {
    "id": 931,
    "itemtype": "ProjectTask",
    "name": "[F2.S4.P5] Prototipo fila local",
    "code": "F2.S4.P5",
    "state": "doing",
    "project_code": "BOTPAN",
    "hours": 2.0,
    "plan_end": "2026-10-06 18:00"
  }
]
~~~

## Mapeamento de status

| GLPI | Papel semantico | Coluna STATUS da planilha |
|------|-----------------|---------------------------|
| Novo | `todo` | NOVO |
| Em atendimento | `doing` | EM ATENDIMENTO |
| Pendente | `testing` | PENDENTE |
| Solucionado | `done` | SOLUCIONADO |
| Fechado | `closed` | FECHADO |
| — (item fixo) | — | - |

## Regras

- **Somente leitura.** Nunca escreve no GLPI.
- Deduplicacao: `Ticket` vinculado a `ProjectTask` (via `ProjectTask_Ticket`)
  aparece **uma vez**, preferindo o `ProjectTask` (tem code F/S/P).
- `hours` vem de `actiontime` (ProjectTask) ou do default (2 h) para Ticket.
- `project_code` resolvido por `agenda.yaml:projetos[].glpi_project_id`;
  sem correspondencia -> `"?"` e aviso.
- Credenciais em `~/.secrets/glpi.env` — nunca no repositorio.
- Respeita `--env=homolog` do CLI.

Codigos de saida: `0` ok · `4` analista nao resolvido · `5` API/auth.
