# Guia de skills — pmf-dev-kit

| Skill | Uso |
|-------|-----|
| atualizar / exporte / importe | Sync Git do **produto** |
| **atualizar-kit** | Verifica/sincroniza novidades do **pmf-dev-kit** → produto (`scripts/atualizar-kit`) |
| backup | Cópia de segurança |
| encerrar-sessao | `SESSAO_*` em `docs/05_progresso/geral/` (+ anexo GLPI opcional) |
| oncoto-oncovo | Situação do plano |
| commit / documentar | Commit com **gate de plano S/P**; docs pontuais |
| **documente-o-plano** | Cria plano S/P com timestamps GLPI em `docs/05_progresso/<modulo>/` |
| **inserir-pendencia** | Pendência atemporal em `docs/05_progresso/pendencias/CHECKLIST_PENDENCIAS.md` (módulo + timestamp) |
| **acompanhar-chamado** | ITILFollowup no Ticket (título sugerido + edição/default; anexo opcional) |
| glpi-followup | Alias **deprecated** → `acompanhar-chamado` |
| glpi-task-upsert | ProjectTask S/P (`--attach=arquivo` opcional) |
| glpi-project-create | Novo Project |
| glpi-retro-scan | Candidatos a partir do markdown |

CLI: `tools/glpi/bin/*` (inclui `glpi-followup`, `glpi-document-attach`) · Docs: `docs/06_glpi/`  
Sync kit: `./scripts/atualizar-kit --check-only` · `./scripts/atualizar-kit --profile=full-skeleton --yes`
