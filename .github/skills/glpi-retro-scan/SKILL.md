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

## Pós-scan (apply pai→filho)

```bash
./tools/glpi/bin/glpi-retro-apply --from=docs/06_glpi/retro-scans/ARQUIVO.json
./tools/glpi/bin/glpi-retro-apply --from=... --kinds=phase --limit=8
./tools/glpi/bin/glpi-retro-apply --from=... --apply   # após revisão
```

## Referências

- `docs/06_glpi/HIERARQUIA_S_P_GLPI.md`
- `tools/glpi/bin/` — scripts de execução direta
- `tools/glpi/lib/retro_scan.py` / `retro_apply.py`
