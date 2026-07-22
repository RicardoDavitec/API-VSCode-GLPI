# Sessão 2026-07-22 — Retro-scan, content polyrepo e homolog GLPI

## Sumário executivo

- Datas em checklists/planos sem S/P (`git blame` + parser Bot_Pan) e regra GEP (`gep1`/`gep3` zeram `real_*` inferidos).
- `document attach` + skills; `content` enriquecido com `Repos`/`Fontes` no retro-scan/apply.
- Ambiente **homolog** (`--env=homolog`), secrets centralizados em `~/.secrets/glpi.env` (não por projeto).
- Auth homolog OK após App-Token próprio; upgrade Bot_Pan; apply de tarefas na homolog ainda pendente de `project.homolog.yaml` + dry-run/`--apply`.

## Commits da sessão (kit)

| Hash | Mensagem |
|------|----------|
| `f1ebea1` | retro-scan datas em checklists e planos Bot_Pan |
| `a8df464` | document attach + GEP nullify real_* |
| `fa1f2cb` | content enriquecido com repos/fontes |
| `b4cf9b6` | ambiente homolog (`--env`) e secrets `glpi.env` |

Push: `origin` (Gitness) e `github` (API-VSCode-GLPI).

## Problemas

- Homolog rejeita App-Token de produção (`ERROR_WRONG_APP_TOKEN`); resolvido com token de cliente API na homolog (`GLPI_APP_TOKEN_HOMOLOG`).
- Upgrade Bot_Pan exige path posicional (`upgrade-into.sh /path`), não `--target=`.
- `retro-apply` dry-run **não** grava arquivo — só terminal; artefato do scan fica em `docs/06_glpi/retro-scans/`.
- Envio do `2026-07-22_1510_botpan.json` à homolog ainda não concluído (faltava `project_id` de homolog / apply controlado).

## Decisões

- Tokens únicos em `~/.secrets/glpi.env` (comum a todos os produtos); exemplo no kit sem segredos.
- State local separado em homolog: `state-project-<id>.homolog.json`.
- Procedência polyrepo no **conteúdo** da ProjectTask (`Repos` + `Fontes`), teto 4000 chars.

## Próximas ações

1. No Bot_Pan: `project.homolog.yaml` com `project_id` da homolog.
2. Dry-run: `glpi --env=homolog retro-apply --from=docs/06_glpi/retro-scans/2026-07-22_1510_botpan.json` (começar com `--kinds=phase --limit=N`).
3. Apply controlado na homolog; só depois avaliar produção.
4. (Opcional) Anexar esta sessão ao Ticket via `glpi-document-attach` quando houver `ticket_id`.

---

*Encerrada em 22/07/2026 — Dr. Ricardo David*
