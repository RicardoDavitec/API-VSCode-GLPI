# Sessão 2026-07-21 — Integração GLPI (kit + Bot_Pan)

## Sumário executivo

- Documentação e generalização do **pmf-dev-kit** (preset `api-vscode-glpi`, assistentes bash/Python, autoria MIT).
- Publicação no Gitness e espelho no GitHub (`RicardoDavitec/API-VSCode-GLPI`).
- Upgrade GLPI no **Bot_Pan**; testes dry-run de install e **retro-scan**.
- Evolução do `retro_scan.py`: timestamps a partir de commits + GEP; gap restante: checklists sem vínculo S/P ainda com datas `null`.

## Commits da sessão (kit)

| Hash | Mensagem |
|------|----------|
| `e01577f` | docs: manual integração GLPI e rosto Gitness |
| `37d4a14` | feat: presets api-vscode-glpi, assistentes e autoria pública |
| *(este)* | retro-scan timestamps + registro de sessão |

Push também para remoto `github` (histórico completo até o commit desta sessão).

## Problemas

- Retro-scan no Bot_Pan: ~80 candidatos (commits) com datas; ~209 checklists sem `code` S/P permanecem com `plan_*`/`real_*` = `null` (sem merge com commits).
- Parser de plano S/P estilo SAMU não extrai fases dos `PLANO*.md` do Bot_Pan (0 candidatos `plan`).
- Artefatos em `docs/06_glpi/retro-scans/*.json|.md` estão no `.gitignore` (não aparecem no Explorer do IDE).

## Decisões

- Preset default do kit: **api-vscode-glpi**; exemplos PMF na documentação.
- Autoria pública: **Dr. Ricardo David**; e-mails pessoal + corporativo; patrocínio **PMF — DTI**; licença **MIT**.
- Remotos: `origin` = Gitness (upstream); `github` = publicação pública.
- Dry-run no Bot_Pan: sem `seed-phases --apply` / sem `retro-apply --apply`.

## Próximas ações

1. Associar timestamps a checklists/planos Bot_Pan (vínculo por dia/código/heurística).
2. Adaptar parser de plano ao formato do Bot_Pan (ou template S/P).
3. Retestar mono + polyrepo (`workspace.yaml` linhagem) após o fix.
4. (Opcional) `upgrade-into` Bot_Pan de novo e gerar novo `*_botpan-mono.json`.

---

*Encerrada em 21/07/2026 — Dr. Ricardo David*
