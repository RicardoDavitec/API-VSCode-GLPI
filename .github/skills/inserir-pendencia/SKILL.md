---
name: inserir-pendencia
description: "Insere ou atualiza pendencia atemporal no CHECKLIST_PENDENCIAS.md no padrao de checklist documente-o-plano (marcadores e glpi timestamps). Use quando o usuario pedir inserir pendencia, registrar pendencia, checklist de pendencias, pendencia atemporal ou higienizacao/debt tecnico para depois."
argument-hint: "Modulo + titulo curto (ex: sql-server higienizar orfaos E01)"
---

# Skill: inserir-pendencia

Alimenta o checklist **atemporal** em `docs/05_progresso/pendencias/`, usando o **mesmo padrão de checklist** da skill `documente-o-plano` (marcadores `- [ ]` / `- [~]` / `- [x]` + comentário `<!-- glpi: ... -->`).

## Gatilhos

- "inserir pendência", "registrar pendência", "checklist de pendências"
- "pendência atemporal", "anotar para depois", "higienização", "tech debt no checklist"

## Arquivos

| Arquivo | Papel |
|---------|--------|
| `docs/05_progresso/pendencias/CHECKLIST_PENDENCIAS.md` | Itens (checklist) |
| `docs/05_progresso/pendencias/README.md` | **Convenções e instruções** (não duplicar no checklist) |

Se o checklist **não existir**, criar com o [Bootstrap](#bootstrap) (corpo enxuto + link ao README).  
Se o README **não existir**, copiar/criar a partir do esqueleto do kit ou da seção de referência no produto.  
Criar pasta `docs/05_progresso/pendencias/` se necessário.

**Antes de inserir:** ler `docs/05_progresso/pendencias/README.md` (fonte das convenções).

## Fluxo obrigatório

1. **Coletar** (perguntar o que faltar):
   - Título, módulo, contexto, evidência, critério de aceite
   - `plan_end` (prazo alvo) — se ausente, sugerir estimativa e confirmar
   - Status inicial: `- [ ]`
2. **Timestamps visíveis + glpi**
   - **Inserido em** = agora (`YYYY-MM-DD HH:MM`) — obrigatório na criação
   - **Corrigido em** = `—` na criação; preencher só ao resolver
   - `plan_start` = mesmo valor de **Inserido em**
   - `plan_end` = prazo alvo (obrigatório no comentário glpi)
   - Ao concluir: **Corrigido em** = agora e `real_end` = mesmo valor
3. **ID** = `PEND-YYYYMMDD-NNN` (próximo NNN do dia no arquivo)
4. **Inserir** em `CHECKLIST_PENDENCIAS.md`:
   - Linha na tabela **Índice**
   - Item no corpo no [template](#template-de-item) (marcador + Inserido/Corrigido + `<!-- glpi: ... -->`)
5. Não concluir sem pedido; ver [Concluir](#concluir-pendencia).
6. Informar ID + path; não commitar sozinho.

## Template de item

Alinhado a `documente-o-plano`:

```markdown
- [ ] **PEND-YYYYMMDD-NNN** <Titulo>
  Módulo: `<modulo>`
  Inserido em: `YYYY-MM-DD HH:MM`
  Corrigido em: `—`
  Contexto: <explicacao>
  Critério: <aceite>
  Evidência: <… ou N/A>
  Refs: <opcional>
  <!-- glpi: plan_start="YYYY-MM-DD HH:MM" plan_end="YYYY-MM-DD HH:MM" -->
```

Índice:

```markdown
| PEND-YYYYMMDD-NNN | [ ] | <modulo> | YYYY-MM-DD HH:MM | — | <Titulo> |
```

Colunas do índice: `ID | Status | Módulo | Inserido em | Corrigido em | Título` (espelhar os mesmos valores do item).

Módulos e regras de `plan_*` / `real_*` / Inserido / Corrigido: ver `docs/05_progresso/pendencias/README.md` (não reescrever aqui).

## Concluir pendência

1. Marcador → `- [x]`
2. **Corrigido em** (no **item** e no **índice**) → `YYYY-MM-DD HH:MM` (agora)
3. Preencher `real_start` (se faltava) e `real_end` (= **Corrigido em**) no comentário glpi
4. Nota curta do que foi feito
5. Atualizar coluna Status no Índice para `[x]`
6. Opcional: resumir em **Histórico (concluídas)**; não apagar evidências

Em andamento (`- [~]`): exigir `real_start` no glpi; manter **Corrigido em:** `—` no item e no índice.

## Bootstrap

```markdown
# Checklist de pendências atemporais

> **Convenções e instruções:** [`README.md`](README.md)  
> **Padrão de checklist:** skill `documente-o-plano` · **Alimentação:** skill `inserir-pendencia`

## Índice

| ID | Status | Módulo | Inserido em | Corrigido em | Título |
|----|--------|--------|-------------|--------------|--------|

## Pendências

## Histórico (concluídas)

_Nenhuma ainda._
```

## Relação com outras skills

| Skill | Papel |
|-------|--------|
| `documente-o-plano` | Mesmo padrão de marcadores + `<!-- glpi: ... -->` para planos S/P |
| `encerrar-sessao` | Pode citar `PEND-*` abertos |
| `glpi-retro-scan` | Varre timestamps glpi do markdown |

## Regras essenciais

- Convenções só no README da pasta; checklist só linka o README.
- Seguir marcadores e tabela de timestamps de `documente-o-plano` (com adaptação atemporal documentada no README).
- Não inventar pendências; não gravar segredos; não commitar sem pedido.

## Referências

- `docs/05_progresso/pendencias/README.md`
- `docs/05_progresso/pendencias/CHECKLIST_PENDENCIAS.md`
- `.github/skills/documente-o-plano/SKILL.md`
