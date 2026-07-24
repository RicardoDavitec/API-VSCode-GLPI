# Pendências atemporais

Pasta para dívidas técnicas e follow-ups **fora** do plano S/P do dia (skill `documente-o-plano`).

| Arquivo | Uso |
|---------|-----|
| [`CHECKLIST_PENDENCIAS.md`](CHECKLIST_PENDENCIAS.md) | Checklist canônico (somente itens) |
| Este `README.md` | Instruções e convenções |

**Skill de alimentação:** `inserir-pendencia` (`.github/skills/inserir-pendencia/`).  
**Padrão de checklist:** o mesmo da skill [`documente-o-plano`](../../../.github/skills/documente-o-plano/SKILL.md).

---

## Instruções

1. **Não** coloque convenções longas dentro de `CHECKLIST_PENDENCIAS.md` — só itens + link para este README.
2. Para **nova** pendência: use a skill `inserir-pendencia` (ou copie o template abaixo).
3. Cada item **obriga** marcador de checklist + comentário `<!-- glpi: ... -->` (compatível com `glpi-retro-scan`).
4. Pendência atemporal **não** substitui tarefa S/P de sprint: se entrar no plano, linkar `Ver PEND-…` no plano e manter o ID aqui.
5. Ao concluir: `- [x]`, preencher **Corrigido em**, `real_end` no glpi, nota curta; opcionalmente mover resumo para o Histórico.

---

## Convenções

### ID

`PEND-YYYYMMDD-NNN` — data do **registro** + sequência do dia (`001`, `002`, …).

### Marcadores (igual `documente-o-plano`)

| Marcador | Estado |
|----------|--------|
| `- [ ]` | Não iniciado |
| `- [~]` | Em andamento |
| `- [x]` ou `- [X]` | Finalizado |

Preferir `- [x]` (minúsculo).

### Módulo

Um valor ou combinação com `+` (ex.: `reengenharia-db+sql-server`):

| Módulo | Quando |
|--------|--------|
| `backend` | API, serviços |
| `frontend` | UI / desktop legado |
| `web` | App web |
| `mobile` | App móvel |
| `sql-server` | SQL Server / DBeaver / T-SQL |
| `postgresql` | PostgreSQL |
| `docs` | Documentação |
| `infra` | Deploy, CI, servidores |
| `reengenharia-db` | FK lógica→estrutural, DER, órfãos |
| `glpi` | Integração GLPI |
| `geral` | Cross-cutting |

### Timestamps (`<!-- glpi: ... -->`)

Formato: `YYYY-MM-DD HH:MM` (fuso local).  
Na **mesma linha** do item ou na **linha seguinte**:

```html
<!-- glpi: plan_start="..." plan_end="..." real_start="..." real_end="..." -->
```

| Estado | `plan_start` / `plan_end` | `real_start` | `real_end` |
|--------|---------------------------|--------------|------------|
| `- [ ]` | **Obrigatório** | omitir | omitir |
| `- [~]` | **Obrigatório** | **Obrigatório** | omitir até concluir |
| `- [x]` | **Obrigatório** | **Obrigatório** | **Obrigatório** |

**Campos visíveis obrigatórios (além do glpi):**

| Campo no item | Quando preencher | Formato |
|---------------|------------------|---------|
| **Inserido em** | Sempre, na criação | `YYYY-MM-DD HH:MM` |
| **Corrigido em** | Só quando resolvida (`[x]`); até lá usar `—` | `YYYY-MM-DD HH:MM` ou `—` |

**Adaptação atemporal — espelho glpi:**

| Campo glpi | Espelha |
|------------|---------|
| `plan_start` | **Inserido em** (registro) |
| `plan_end` | Prazo alvo de resolução (estimativa; pedir ao usuário se possível) |
| `real_start` | Início real do trabalho (quando `[~]` ou `[x]`) |
| `real_end` | **Corrigido em** (quando `[x]`) |

Diferente do plano S/P: não há organograma de sprint; os campos visíveis + `glpi:` ficam para leitura humana e varredura/retro.

### Forma do item no checklist

```markdown
- [ ] **PEND-YYYYMMDD-NNN** <Título curto>
  Módulo: `<modulo>`
  Inserido em: `YYYY-MM-DD HH:MM`
  Corrigido em: `—`
  Contexto: <o quê / por quê / impacto>
  Critério: <aceite mensurável>
  Evidência: <ids, path, query — ou N/A>
  Refs: <paths opcionais>
  <!-- glpi: plan_start="YYYY-MM-DD HH:MM" plan_end="YYYY-MM-DD HH:MM" -->
```

Em andamento:

```markdown
- [~] **PEND-…** <Título>
  Inserido em: `...`
  Corrigido em: `—`
  …
  <!-- glpi: plan_start="..." plan_end="..." real_start="YYYY-MM-DD HH:MM" -->
```

Concluído:

```markdown
- [x] **PEND-…** <Título>
  Inserido em: `YYYY-MM-DD HH:MM`
  Corrigido em: `YYYY-MM-DD HH:MM`
  Nota: <o que foi feito>
  …
  <!-- glpi: plan_start="..." plan_end="..." real_start="..." real_end="YYYY-MM-DD HH:MM" -->
```

### Índice

Tabela no topo de `CHECKLIST_PENDENCIAS.md` — espelho de navegação. Colunas obrigatórias:

| Coluna | Conteúdo |
|--------|----------|
| ID | `PEND-YYYYMMDD-NNN` |
| Status | `[ ]` / `[~]` / `[x]` (espelho do marcador do item) |
| Módulo | slug do módulo |
| **Inserido em** | `YYYY-MM-DD HH:MM` (igual ao campo do item) |
| **Corrigido em** | `—` se aberta; `YYYY-MM-DD HH:MM` se `[x]` |
| Título | título curto |

A **fonte de verdade do status** continua sendo o marcador `- [ ]` / `- [~]` / `- [x]` no corpo; **Inserido em** / **Corrigido em** no índice devem permanecer **iguais** aos campos do item.

---

## Relação com outros artefatos

| Artefato | Papel |
|----------|--------|
| Skill `documente-o-plano` | Planos temporais S/P |
| Skill `inserir-pendencia` | Insere/atualiza itens neste checklist |
| `SESSAO_*` / `encerrar-sessao` | Pode listar `PEND-*` abertos nas próximas ações |
| `glpi-retro-scan` | Lê comentários `<!-- glpi: ... -->` |

---

## Regras essenciais

- Não inventar pendência sem pedido ou evidência.
- Não gravar segredos (senhas, connection strings).
- Não apagar evidências ao concluir — só marcar `[x]` e preencher `real_end`.
- Convenções vivem **neste README**; o checklist só referencia: [`README.md`](README.md).
