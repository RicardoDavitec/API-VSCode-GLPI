# Plano: Refatoracao das skills GLPI para modelo F/S/P

> Criado: 05/10/2026 09:30 · Fase principal: `F1` · Produto: `pmf-dev-kit`
> Arquivo: `refatoracao_glpi_fsp-05_10_26-09_30.md`
> Requisitos: `docs/01_requisitos/README.md` · `docs/06_glpi/HIERARQUIA_F_S_P_GLPI.md`
> GLPI: projeto `PMFDEVKIT`

## Objetivo

Expandir o padrao de skills GLPI de 3 niveis (Projeto -> S -> P) para 4 niveis
(Projeto -> F -> S -> P), com as 5 fases do ciclo de vida, mantendo o kit
generico (overlay kit/preset/produto) e sem perder o historico legado.

## Requisitos de negocio (vinculo)

- Cada projeto possui exatamente 5 fases: Planejamento, Implementacao,
  Testes Internos, Homologacao, Aprovacao.
- Cada fase possui N sessoes; cada sessao possui N tarefas.
- Tarefa (P) e fundamentada em commit.
- O kit deve servir a qualquer instancia GLPI com API REST (preset `generic`),
  tendo a PMF Franca como exemplificacao (preset `api-vscode-glpi`).
- Nenhum objeto legado pode ser apagado.

## Organograma (resumo)

| Code | Titulo | Status | Plan ini | Plan fim |
|------|--------|--------|----------|----------|
| F1.S1 | Modelagem do padrao F/S/P | [x] | 2026-10-05 09:30 | 2026-10-05 11:00 |
| F1.S1.P1 | Diagnostico das skills v1 | [x] | 09:30 | 09:45 |
| F1.S1.P2 | Definir topologia e invariantes | [x] | 09:45 | 10:10 |
| F1.S1.P3 | Camada de overlay kit/preset/produto | [x] | 10:10 | 10:30 |
| F1.S1.P4 | Emitir skills refatoradas | [x] | 10:30 | 10:50 |
| F1.S1.P5 | upgrade-into.sh com ownership K/P/S | [x] | 10:50 | 11:00 |
| F1.S1.P6 | Agentes e skill commit v2 | [~] | 11:00 | 11:30 |
| F1.S2 | Aplicacao no repositorio fonte | [ ] | 2026-10-05 11:30 | 2026-10-05 18:00 |

## Fases e tarefas

### F1 — Planejamento

- [~] **F1** Planejamento do modelo F/S/P
  Consolidar o padrao organizacional, os contratos de configuracao e as skills.
  Aceite: kit generico com 5 fases, overlay funcional e validador operante.
  <!-- glpi: code="F1" plan_start="2026-10-05 09:30" plan_end="2026-10-05 18:00" real_start="2026-10-05 09:30" -->

  - [x] **F1.S1** Modelagem do padrao F/S/P
    Criterio: modelo canonico definido, invariantes formalizadas, skills emitidas.
    Detalhe: [`anexos/F1_S1_modelagem_fsp-05_10_26.md`](./anexos/F1_S1_modelagem_fsp-05_10_26.md)
    <!-- glpi: code="F1.S1" plan_start="2026-10-05 09:30" plan_end="2026-10-05 11:30" real_start="2026-10-05 09:30" -->

    - [x] **F1.S1.P1** Diagnostico das skills v1
      Criterio: tabela de lacunas das 5 skills + template, com severidade.
      Achado: `PR/PH/R/H/I` em `documente-o-plano` eram fases disfarcadas.
      <!-- glpi: code="F1.S1.P1" plan_start="2026-10-05 09:30" plan_end="2026-10-05 09:45" real_start="2026-10-05 09:30" real_end="2026-10-05 09:45" -->

    - [x] **F1.S1.P2** Definir topologia e invariantes
      Criterio: fase = subprojeto (evidencia: `hierarchy.yaml` usa
      `project.form.php`); contencao de datas; rollup ponderado; `phi` sobrejetiva.
      <!-- glpi: code="F1.S1.P2" plan_start="2026-10-05 09:45" plan_end="2026-10-05 10:10" real_start="2026-10-05 09:45" real_end="2026-10-05 10:10" -->

    - [x] **F1.S1.P3** Camada de overlay kit/preset/produto
      Criterio: `model.defaults.yaml` + `model.overlay.yaml` + `model.yaml`
      com resolucao `V(k) = produto > preset > kit` e merge de listas por `code`.
      <!-- glpi: code="F1.S1.P3" plan_start="2026-10-05 10:10" plan_end="2026-10-05 10:30" real_start="2026-10-05 10:10" real_end="2026-10-05 10:30" -->

    - [x] **F1.S1.P4** Emitir skills refatoradas
      Criterio: 10 skills ativas + 4 aliases depreciados, sem jargao institucional.
      <!-- glpi: code="F1.S1.P4" plan_start="2026-10-05 10:30" plan_end="2026-10-05 10:50" real_start="2026-10-05 10:30" real_end="2026-10-05 10:50" -->

    - [x] **F1.S1.P5** upgrade-into.sh com ownership K/P/S
      Criterio: invariante `K ∩ P = ∅` verificada em runtime, backup, dry-run,
      self-update atomico, migracao v2, gitignore de segredos.
      <!-- glpi: code="F1.S1.P5" plan_start="2026-10-05 10:50" plan_end="2026-10-05 11:00" real_start="2026-10-05 10:50" real_end="2026-10-05 11:00" -->

    - [~] **F1.S1.P6** Agentes e skill commit v2
      Criterio: 4 agentes (`orchestrator`, `auditor`, `migrator`, `scribe`) +
      skill `commit` com gate de plano em F/S/P.
      <!-- glpi: code="F1.S1.P6" plan_start="2026-10-05 11:00" plan_end="2026-10-05 11:30" real_start="2026-10-05 11:00" -->

  - [ ] **F1.S2** Aplicacao no repositorio fonte
    Criterio: arquivos gravados, `bash -n` limpo, dry-run do upgrade validado.
    <!-- glpi: code="F1.S2" plan_start="2026-10-05 11:30" plan_end="2026-10-05 18:00" -->

    - [ ] **F1.S2.P1** Gravar arquivos de configuracao do kit
      <!-- glpi: code="F1.S2.P1" plan_start="2026-10-05 11:30" plan_end="2026-10-05 12:30" -->

    - [ ] **F1.S2.P2** Gravar skills e agentes
      <!-- glpi: code="F1.S2.P2" plan_start="2026-10-05 14:00" plan_end="2026-10-05 15:30" -->

    - [ ] **F1.S2.P3** Testar upgrade-into.sh em clone descartavel
      Criterio: `bash -n` OK, dry-run sem erro, camada P preservada no apply.
      <!-- glpi: code="F1.S2.P3" plan_start="2026-10-05 15:30" plan_end="2026-10-05 17:00" -->

    - [ ] **F1.S2.P4** Atualizar README e docs/06_glpi
      Criterio: tabela de camadas corrigida (hoje diz "S=pai, P=filho").
      <!-- glpi: code="F1.S2.P4" plan_start="2026-10-05 17:00" plan_end="2026-10-05 18:00" -->

## Concluido nesta sessao (05/10)

- Modelo canonico F/S/P definido e justificado por evidencia (`hierarchy.yaml`).
- Retificacao: fase = **subprojeto**, nao `ProjectTask`.
- Descoberta: `gep4` (Testando) e `gep9` (Fechado) existiam em `states.json`
  mas nenhuma skill usava -> novos marcadores `[t]` e `[A]`.
- Camada de overlay em 3 niveis para generalizar o kit.
- 10 skills ativas + 4 aliases + 4 agentes especificados.
- `upgrade-into.sh` v2.0.0 com modelo de propriedade de arquivos.

## Pendencias

- [ ] Decidir origem das sessoes de **F3 Testes Internos** (fase sem legado).
- [ ] Rodar `glpi states discover` para confirmar IDs na instancia.
- [ ] Implementar os binarios novos em `tools/glpi/bin/`
      (`glpi-phase-ensure`, `glpi-node-upsert`, `glpi-commit-harvest`,
      `glpi-tree-validate`, `glpi-progress-rollup`, `glpi-migrate-codes`).