---
name: documente-o-plano
description: "Cria ou atualiza plano de implementacao em docs/05_progresso com hierarquia S/P, checklists e timestamps GLPI. Use quando o usuario pedir documente o plano, documentar plano, criar plano, planejar sprint/sessao ou modelo de planejamento."
argument-hint: "Modulo (geral|nome-monorepo|modulo-externo) e titulo curto do plano."
---

# Skill: documente-o-plano

Gera planos Markdown **objetivos para humanos** e **denso/previsivel para agentes**, alinhados a `docs/01_requisitos` e ao padrao GLPI (S = fase · P = tarefa).

## Gatilhos

- "documente o plano", "documentar plano", "criar plano", "planejar sprint/sessao"
- Pedidos de checklist S/P com datas planejadas/reais

## Fluxo obrigatorio

1. **Contexto**
   - Confirmar **modulo** destino: `geral` | pasta monorepo | modulo externo.
   - Ler `docs/01_requisitos/**` (e `docs/01_requisitos/README.md`).
   - Se a pasta estiver vazia, so com README esqueleto, ou **incoerente** com as metas do plano: **recomendar criar/atualizar requisitos antes** (nao inventar regras de negocio).
2. **Caminho e nome**
   ```text
   docs/05_progresso/<modulo>/<nome_do_plano>-DD_MM_AA-hh_mm.md
   ```
   - `nome_do_plano`: slug em minusculas com `_` (sem acentos).
   - Timestamp = **criacao** no fuso local: `DD_MM_AA-hh_mm` (ex.: `offline_sync-24_07_26-09_40.md`).
   - Criar `docs/05_progresso/<modulo>/` se nao existir.
3. **Anexos de detalhe (por S)**
   - Cada fase **S** deve ter paragrafo resumido **no plano** + link para doc detalhado.
   - Nome intuitivo correlacionando **S + tema + tempo**, ex.:
     ```text
     docs/05_progresso/<modulo>/anexos/S1_<slug>-DD_MM_AA.md
     ```
4. **Escrever o plano** com o template abaixo (sem omitir campos obrigatorios).
5. **Validar checklist temporal** (secao Regras de timestamp) antes de finalizar.
6. Informar caminho criado e proximos passos (`glpi-retro-scan` / upsert se o usuario quiser sync GLPI).

## Hierarquia S / P

| Nivel | Significado | Code |
|-------|-------------|------|
| **S** | Semana / Sprint / Sessao (fase pai) | `S0`, `S1`, … |
| **P** | Tarefa filha de um S | `S1.P1`, `S1.P2`, … |

Ordem no documento: **S (pai) → Ps (filhos)** em sequencia.

## Checklists (obrigatorio)

Todo item S e P inicia com um destes marcadores:

| Marcador | Estado |
|----------|--------|
| `- [ ]` | Nao iniciado |
| `- [~]` | Em andamento |
| `- [x]` ou `- [X]` | Finalizado |

Preferir `- [x]` (minusculo) por compatibilidade com o kit; `- [X]` e aceito.

## Regras de timestamp (obrigatorio)

Formato preferido (ISO local): `YYYY-MM-DD HH:MM` (ou `YYYY-MM-DD`).

Embutir via comentario HTML na **mesma linha** do checklist ou na **linha seguinte** (compativel com `glpi-retro-scan`):

```html
<!-- glpi: plan_start="..." plan_end="..." real_start="..." real_end="..." -->
```

| Estado | `plan_start` / `plan_end` | `real_start` | `real_end` |
|--------|---------------------------|--------------|------------|
| `- [ ]` | **Obrigatorio** (estimativa do organograma) | omitir ou vazio | omitir ou vazio |
| `- [~]` | **Obrigatorio** | **Obrigatorio** | omitir ate concluir |
| `- [x]` / `- [X]` | **Obrigatorio** | **Obrigatorio** | **Obrigatorio** |

Datas planejadas devem respeitar o organograma (S cobre o intervalo dos Ps; Ps nao ultrapassam o S pai sem justificativa explicita).

## Template do plano

```markdown
# Plano: <Titulo legivel>

> Criado: DD/MM/AAAA hh:mm · Modulo: `<modulo>` · Arquivo: `<nome>-DD_MM_AA-hh_mm.md`
> Requisitos: ver `docs/01_requisitos/` (listar arquivos consultados)

## Objetivo

<1–3 frases. Meta mensuravel.>

## Requisitos de negocio (vinculo)

- [obrigatorio] Conferir `docs/01_requisitos/…`
- Se ausentes/incoerentes: **ACAO** — criar/atualizar requisitos antes de executar o plano.
- Lista curta: RN-id ou arquivo → trecho que o plano respeita.

## Organograma (resumo)

| Code | Titulo | Status | Plan ini | Plan fim |
|------|--------|--------|----------|----------|
| S1 | … | [ ] | … | … |
| S1.P1 | … | [ ] | … | … |

## Fases e tarefas

### S1 — <Titulo da fase>

- [ ] **S1** <Titulo da fase>
  <Paragrafo resumido (3–6 linhas): escopo, criterio de aceite, risco.>
  Detalhe: [`anexos/S1_<slug>-DD_MM_AA.md`](./anexos/S1_<slug>-DD_MM_AA.md)
  <!-- glpi: plan_start="YYYY-MM-DD HH:MM" plan_end="YYYY-MM-DD HH:MM" -->

  - [ ] **S1.P1** <Titulo tarefa>
    Criterio: <teste/aceite curto>
    <!-- glpi: plan_start="YYYY-MM-DD HH:MM" plan_end="YYYY-MM-DD HH:MM" -->

  - [~] **S1.P2** <Titulo>
    Criterio: …
    <!-- glpi: plan_start="..." plan_end="..." real_start="YYYY-MM-DD HH:MM" -->

  - [x] **S1.P3** <Titulo>
    Criterio: …
    <!-- glpi: plan_start="..." plan_end="..." real_start="..." real_end="..." -->
```

Exemplo completo: [template-exemplo.md](template-exemplo.md).

## Regras essenciais

- Nao ferir regras de negocio de `docs/01_requisitos`; se faltarem, **recomendar cria-las**.
- Plano curto no arquivo principal; detalhe longo so nos anexos linkados.
- Nao inventar timestamps reais; so preencher `real_*` com fatos (sessao/commit/confirmacao do usuario).
- Nao commitar secrets.
- Apos criar, sugerir (nao executar sem pedido): `./tools/glpi/bin/glpi-retro-scan` apontando o workspace/plano.

## Relacao com outras skills

- `documentar` — updates pontuais no plano vigente
- `oncoto-oncovo` — situacao atual vs plano
- `encerrar-sessao` — registro diario (nao substitui o plano)
- `glpi-retro-scan` / `glpi-task-upsert` — sync S/P → GLPI
