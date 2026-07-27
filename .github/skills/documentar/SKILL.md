---
name: documentar
description: "Atualiza planos, decisoes e progresso em docs/. Para criar um plano novo S/P com timestamps, use documente-o-plano. Ao fechar Sn/Pm com codigo, use tambem a skill commit (gate de plano)."
---

# Skill: documentar

Atualizar documentos existentes:

- `docs/05_progresso/geral/PLANO_IMPLEMENTACAO.md` (checklists)
- Planos em `docs/05_progresso/<modulo>/*-DD_MM_AA-hh_mm.md`
- Arquitetura / requisitos conforme pastas `docs/02_arquitetura/`, `docs/01_requisitos/`

**Criar plano novo:** skill `documente-o-plano` (nome com timestamp, hierarquia S/P, comentarios `<!-- glpi: ... -->`).

**Fechar item S/P com codigo:** skill `commit` — atualizar planos **antes** do `git commit` (mesmo commit da entrega).
