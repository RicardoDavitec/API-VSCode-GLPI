# Plano: Preview refatoração GLPI para modelo F/S/P

> Criado: 07/10/2026 07:30 · Fase principal: `F1` · Produto: `API-VScode-GLPI`
> Arquivo: `preview_refatoracao_glpi_fsp-07_10_26-07_30.md`
> GLPI: projeto `APIVSGLPI` (homologação)

## Objetivo

Validar o novo padrão de 4 níveis para integração com GLPI no projeto de homologação:

- Projeto raiz
- Fase (`F1`..`F5`)
- Sessão (`S1`, `S2`, ...)
- Tarefa (`P1`, `P2`, ...)

A operação segue o modelo de ciclo de vida corporativo com foco em projeto de software e manutenção de kit, sem apagar objetos legados.

## Requisitos de negócio

- Cada projeto possui cinco fases fixas: Planejamento, Implementação, Testes Internos, Homologação e Aprovação.
- Cada fase pode conter várias sessões; cada sessão pode conter várias tarefas.
- Tarefa deve ser associada a evidência de execução, preferencialmente commit ou checklist.
- O kit deve funcionar em qualquer instância GLPI; a carga do produto é configurada por overlay.
- Objetos legados devem permanecer, mas podem ser migrados ou referenciados sem exclusão.

## Organograma (preview)

| Code | Titulo | Status | Plan ini | Plan fim |
|------|--------|--------|----------|----------|
| F1 | Planejamento do modelo F/S/P | [~] | 2026-10-07 07:30 | 2026-10-07 08:00 |
| F1.S1 | Validacao do fluxo de homologacao | [~] | 07:30 | 08:00 |
| F1.S1.P1 | Validar credenciais e conexao GLPI | [x] | 07:30 | 07:40 |
| F1.S1.P2 | Criar projeto APIVSGLPI em homologacao | [x] | 07:40 | 07:45 |
| F1.S1.P3 | Rodar retro-scan e validar arvore | [x] | 07:45 | 07:55 |
| F1.S1.P4 | Revisar candidatos e preparar apply controlado | [ ] | 07:55 | 08:00 |

## Fases e tarefas

### F1 — Planejamento

- [~] **F1** Planejamento do modelo F/S/P
  Objetivo: validar a operação do kit em homologação antes do apply de tarefas no projeto.
  <!-- glpi: code="F1" plan_start="2026-10-07 07:30" plan_end="2026-10-07 08:00" real_start="2026-10-07 07:30" -->

  - [x] **F1.S1** Validacao do fluxo de homologacao
    Critério: autenticação, criação do projeto e validação remota funcionando.
    <!-- glpi: code="F1.S1" plan_start="2026-10-07 07:30" plan_end="2026-10-07 08:00" real_start="2026-10-07 07:30" -->

    - [x] **F1.S1.P1** Validar credenciais e conexao GLPI
      Critério: `auth` no ambiente homolog com sucesso.
      <!-- glpi: code="F1.S1.P1" plan_start="2026-10-07 07:30" plan_end="2026-10-07 07:40" real_start="2026-10-07 07:30" real_end="2026-10-07 07:40" -->

    - [x] **F1.S1.P2** Criar projeto APIVSGLPI em homologacao
      Critério: projeto `API-VScode-GLPI` criado com sucesso no GLPI.
      <!-- glpi: code="F1.S1.P2" plan_start="2026-10-07 07:40" plan_end="2026-10-07 07:45" real_start="2026-10-07 07:40" real_end="2026-10-07 07:45" -->

    - [x] **F1.S1.P3** Rodar retro-scan e validar arvore
      Critério: `retro-scan` executado e `glpi-tree-validate` remoto com exit 0.
      <!-- glpi: code="F1.S1.P3" plan_start="2026-10-07 07:45" plan_end="2026-10-07 07:55" real_start="2026-10-07 07:45" real_end="2026-10-07 07:55" -->

    - [ ] **F1.S1.P4** Revisar candidatos e preparar apply controlado
      Critério: definir a primeira árvore de tarefas e aplicar de forma controlada no GLPI.
      <!-- glpi: code="F1.S1.P4" plan_start="2026-10-07 07:55" plan_end="2026-10-07 08:00" -->

## Resultado da sessão

A validação da integração em homologação foi concluída, com autenticação e criação do projeto funcionando. O ambiente está pronto para continuar com a revisão da árvore F/S/P e o apply controlado dos candidatos do projeto.

## Pendências

- [ ] Definir a primeira árvore F/S/P de produção para o projeto `APIVSGLPI`.
- [ ] Revisar candidatos de `retro-scan` e aplicar `retro-apply` ou `glpi-node-upsert` com `--apply`.
- [ ] Validar resultados de progresso e estados no GLPI após o primeiro lote.
