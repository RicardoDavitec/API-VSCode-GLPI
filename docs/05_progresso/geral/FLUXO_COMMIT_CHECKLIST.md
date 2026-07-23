# Fluxo de commit e validação

Checklist antes de considerar a entrega fechada:

- [ ] Rodar build/teste da app alterada
- [ ] Atualizar checklist da fase em `PLANO_IMPLEMENTACAO.md` se aplicável
  (ID `Sn.Pm`, Status, `%`, Plan/Real ini/fim, GEP)
- [ ] Commit no padrão AGENTS.md
- [ ] Push para branch de trabalho → merge em `teste-sigs-samu-operacional` (ver `FLUXO_BRANCHES_AMBIENTES.md`)
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

Skills: `.github/skills/glpi-task-upsert/SKILL.md`, `.github/skills/acompanhar-chamado/SKILL.md` (alias: `glpi-followup`).  
Hierarquia: `docs/06_glpi/HIERARQUIA_S_P_GLPI.md`.

## Comandos rápidos

```bash
npm run build:backend
npm run build:web
curl http://localhost:3700/health
./tools/glpi/glpi ticket get
```
