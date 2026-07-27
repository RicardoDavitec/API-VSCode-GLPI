# Fluxo de commit e validação

Checklist antes de considerar a entrega fechada:

- [ ] Rodar build/teste da app alterada
- [ ] **Atualizar planos S/P** (obrigatorio se a entrega avanca/conclui `Sn` / `Sn.Pm`) — skill `commit`:
  - `docs/05_progresso/geral/PLANO_IMPLEMENTACAO.md` (ID, Status, `%`, Plan/Real, GEP)
  - plano de modulo em `docs/05_progresso/<modulo>/` se existir
  - comentarios `<!-- glpi: real_start/real_end -->` quando o plano usar o formato kit
- [ ] Incluir os `.md` de plano no mesmo commit da entrega (preferencial)
- [ ] Commit no padrão AGENTS.md / skill `commit`
- [ ] Push para branch de trabalho do produto (ver `FLUXO_BRANCHES_AMBIENTES.md`)
- [ ] Promover teste → homologa → `main` conforme checklist do ambiente
- [ ] follow-up GLPI enviado?
- [ ] ProjectTask atualizada? (pai S e/ou filho P — skill `glpi-task-upsert`)

O follow-up GLPI fecha o ciclo **auditoria local ↔ suporte institucional** (chamado do projeto).  
A ProjectTask fecha o ciclo **plano local (S/P) ↔ gestão de entrega** no Project.

```bash
# Filho (item) — pai S4 precisa existir no state
./tools/glpi/glpi task upsert --code=S4.P5 --parent-code=S4 --percent=40 --state=gep3 --apply
./tools/glpi/glpi ticket followup - "[S4.P5] resumo da entrega + commit/sha + proximo passo"
```

Skills: `.github/skills/commit/SKILL.md`, `.github/skills/glpi-task-upsert/SKILL.md`, `.github/skills/acompanhar-chamado/SKILL.md` (alias: `glpi-followup`).  
Hierarquia: `docs/06_glpi/HIERARQUIA_S_P_GLPI.md`.

## Comandos rápidos

```bash
# Ajuste aos scripts do produto
npm run build:backend   # se existir
npm run build:web       # se existir
curl http://localhost:3700/health   # se API local
./tools/glpi/glpi ticket get
```
