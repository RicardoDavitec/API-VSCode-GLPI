---
name: glpi-retro-scan
description: "Levanta candidatos hierárquicos S(pai)/P(filho) a ProjectTask a partir de planos/checklists (mono/polyrepo)."
---

# Skill: glpi-retro-scan

Varre `.glpi/workspace.yaml` e gera relatório de candidatos (dedupe por código S/P).

**Execução preferencial:** wrapper em `tools/glpi/bin/` (não depende da skill).

## Comando

```bash
./tools/glpi/bin/glpi-retro-scan
# equivalente:
./tools/glpi/glpi retro-scan
```

Saída: `docs/06_glpi/retro-scans/YYYY-MM-DD_HHMM_<bundle>.md` (+ `.json`).

## Datas e GEP no JSON

- Commits / blame / similaridade preenchem `real_*` quando aplicável.
- **Após** reconciliar status:
  - `gep3` (em andamento) → `real_end = null` (exceto `temporal_source` confirmado: `plan`, `checklist-comment`)
  - `gep1` (não iniciado) → `real_start` e `real_end` = `null` (mesma exceção)
- `gep7` (feito) mantém as datas inferidas ou confirmadas.

## Conteúdo sugerido (GLPI)

`suggested_glpi.content` traz procedência polyrepo:

```text
Hierarquia: kind=… code=… parent=…
Repos: Bot_Pan, Bot_Pan_Cursor
Fontes:
- plan docs/…/PLANO_….md:110
- commit @ Bot_Pan abc1234 …
```

Limites: `GLPI_RETRO_CONTENT_MAX` (4000) · `GLPI_RETRO_CONTENT_MAX_SOURCES` (12).

## Pós-scan (apply pai→filho)

```bash
./tools/glpi/bin/glpi-retro-apply --from=docs/06_glpi/retro-scans/ARQUIVO.json
./tools/glpi/bin/glpi-retro-apply --from=... --kinds=phase --limit=8
./tools/glpi/bin/glpi-retro-apply --from=... --apply   # após revisão
```

## Anexo do relatório (após revisão)

O scan **não** grava no GLPI. Depois de revisar o `.md`/`.json`, opcionalmente anexar ao Project ou Ticket:

```bash
./tools/glpi/bin/glpi-document-attach --file=docs/06_glpi/retro-scans/ARQUIVO.md --project
./tools/glpi/bin/glpi-document-attach --file=docs/06_glpi/retro-scans/ARQUIVO.md --ticket --apply
```

## Referências

- `docs/06_glpi/HIERARQUIA_S_P_GLPI.md`
- `tools/glpi/bin/` — scripts de execução direta
- `tools/glpi/bin/glpi-document-attach`
- `tools/glpi/lib/retro_scan.py` / `retro_apply.py`
