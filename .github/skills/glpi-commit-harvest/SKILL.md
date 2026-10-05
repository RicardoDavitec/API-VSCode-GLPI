---
name: glpi-commit-harvest
description: >-
  Converte commits git em tarefas P agrupadas em sessoes S, com fase inferida
  e datas reais extraidas do log. Saida JSON para glpi-node-upsert/retro-apply.
  Use em colher commits, commits para glpi, sincronizar commits,
  fechar sessao, registrar sprint.
---

# Skill: glpi-commit-harvest

Especializacao de `glpi-retro-scan` para a fonte **git**. Enquanto o retro-scan
reconstroi o historico inteiro, esta skill e o **uso diario**: colher o que foi
commitado desde o ultimo sync e materializar S/P.

## Comandos

~~~bash
# Uso diario: desde o ultimo sync registrado no index
./tools/glpi/bin/glpi-commit-harvest --since-last-sync

./tools/glpi/bin/glpi-commit-harvest --since=HEAD~50
./tools/glpi/bin/glpi-commit-harvest --since=2026-10-01 --session-window=week
./tools/glpi/bin/glpi-commit-harvest --range=v1.0..v1.1 --phase=F3
./tools/glpi/bin/glpi-commit-harvest --last-session --code-prefix=F2.S7
./tools/glpi/bin/glpi-commit-harvest --branch=homolog --phase=F4 --apply
./tools/glpi/bin/glpi-commit-harvest --author="@me" --since=1.week --out=JSON
~~~

## Parametros

| Flag | Default | Descricao |
|------|---------|-----------|
| `--since` | `--since-last-sync` | Data ISO, `HEAD~N`, `1.week`, tag |
| `--until` | `HEAD` | Limite superior |
| `--range=A..B` | — | Intervalo explicito (precede `--since`) |
| `--since-last-sync` | — | Le `last_sync_sha` de `.glpi/index.json` |
| `--session-window` | `week` | `day`\|`week`\|`sprint`\|`branch` |
| `--code-prefix=F2.S7` | auto | Forca a sessao destino |
| `--phase=F3` | inferida | Forca a fase |
| `--branch` | atual | Restringe ao branch |
| `--author` | todos | Filtra autor (`@me` = `user.email` local) |
| `--squash-by=scope` | `scope` | `scope`\|`file`\|`none` — agrupa commits em um P |
| `--merge-commits` | off | Inclui commits de merge |
| `--out=FILE` | auto | JSON de saida |
| `--apply` | off | Encadeia `glpi-node-upsert --from=` |

## Agrupamento

- **S (sessao)** = recorte temporal de `--session-window`.
  Numeracao continua por fase: a proxima S de F2 e `max(S existente)+1`.
- **P (tarefa)** = um commit, ou um *squash* de commits do mesmo escopo
  (`feat(fila):` x3 -> um unico P), conforme `--squash-by`.
- `real_start` = `author_date` do primeiro commit do P;
  `real_end` = `author_date` do ultimo.
- `--hours` do P = `effort.task_hours_default`, ou estimado por
  `--estimate-from=diff` (heuristica de linhas alteradas, só aviso).

## Derivacao de estado

| Situacao do commit | Estado proposto | percent |
|--------------------|-----------------|---------|
| Commit normal (entregue) | `done` | 100 |
| Mensagem com `wip:`/`[wip]` | `doing` | 50 |
| `test:`/`ci:` com pipeline vermelho | `testing` | 80 |
| `revert:` | `doing` + nota de reversao no content | 50 |
| Commit em branch de homolog | fase F4, `testing` | 80 |
| Tag de release assinada | fase F5, `closed` **só com `--accept-ref`** | 100 |

Commit **e evidencia de execucao**: por isso P nasce `done`. Nunca se cria P
`todo` a partir de commit (isso vem do plano, via `documente-o-plano`).

## Conteudo gerado por P

~~~text
name: "[F2.S7.P3] feat(fila): persistir eventos em SQLite"
content:
  <!-- glpi-meta: code="F2.S7.P3" level="P" src="git:9f3ac1e" hours="2" -->
  Commit: 9f3ac1e · Autor: J. Silva · 2026-10-02 14:22 -03:00
  Branch: feature/fila-offline
  Arquivos (4): src/queue/sqlite.ts, src/queue/index.ts, tests/queue.spec.ts, CHANGELOG.md
  Diff: +182 / -37

  Atomos:
  - schema da tabela de eventos
  - enqueue/dequeue transacional
  - teste de ordem FIFO
~~~

## Regras

- **Nunca inventar datas**: sempre `git log --date=iso-strict`.
- Dry-run por padrao. `--apply` delega a `glpi-node-upsert --from=` (que tambem
  pede confirmacao).
- Commits que violam `safety.deny_content_regex` entram com o trecho **redigido**
  (`[REDIGIDO]`), nunca com o segredo.
- Atualiza `last_sync_sha` em `.glpi/index.json` só apos `--apply` bem-sucedido.
- Repositorio sujo (`git status` nao limpo) -> aviso; `--allow-dirty` prossegue.
- Em polyrepo, respeita `role`/`weight` (ver `glpi-retro-scan`).

Codigos de saida: `0` ok · `2` range invalido · `4` sessao/fase nao resolvida ·
`5` API · `6` abortado · `8` repo sujo sem `--allow-dirty`.