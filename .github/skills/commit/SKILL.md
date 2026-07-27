---
name: commit
description: "Commits padronizados (gitmoji + timestamp PT-BR) com atualizacao obrigatoria de planos S/P. Use ao commitar, fechar item Sn/Sn.Pm ou apos testes de uma entrega."
argument-hint: "Opcional: codigo S/P afetado (ex: S2.P5) e resumo curto."
---

# Skill: commit (pmf-dev-kit / produto)

Formato da mensagem:

```text
<gitmoji> <tipo>(<escopo>): <descricao-sem-acentos>_DD-MM-AA_hh-mm
```

Escopos tipicos: `backend`, `web`, `mobile`, `docs`, `infra`, `db` (o produto pode estender em `AGENTS.md`).  
Referencias: `AGENTS.md` do produto, `docs/05_progresso/geral/FLUXO_COMMIT_CHECKLIST.md`.

---

## Gate obrigatorio — planos antes do commit

**Nao commitar codigo de entrega sem atualizar o(s) plano(s)** quando a mudanca implementa, avanca ou conclui um item `Sn` / `Sn.Pm`.

### Quando atualizar (sempre que aplicavel)

| Situacao | Acao no plano |
|----------|----------------|
| Implementou / testou um **P** | Marcar `Sn.Pm` (`[ ]`→`[~]` ou `[x]`), `%`, `Real ini`/`Real fim`, GEP, criterio se mudou |
| Concluiu todos os P de um **S** | Fechar o S pai (`[x]`, `%`, `Real fim`) |
| Entrega so de docs/plano | Pode ser commit `docs` sem mudar Status de codigo; registrar nota se fechar sessao de planejamento |
| Hotfix sem item no plano | Nota em "Concluido nesta sessao" **ou** abrir P no plano do modulo; nao deixar orfao |

### Onde atualizar

1. **Plano produto (fluxo principal):**  
   `docs/05_progresso/geral/PLANO_IMPLEMENTACAO.md` (ou equivalente definido no produto)
2. **Plano de modulo (trilha paralela):**  
   `docs/05_progresso/<modulo>/*-DD_MM_AA-hh_mm.md`  
   (criado por skill `documente-o-plano`)
3. **Timestamps GLPI** (formato kit):  
   na mesma linha ou seguinte do checklist:
   ```html
   <!-- glpi: plan_start="..." plan_end="..." real_start="..." real_end="..." -->
   ```
   - `[~]` → `real_start` obrigatorio  
   - `[x]` → `real_start` + `real_end` obrigatorios  
4. **Sessao (opcional no mesmo commit):** bloco "Concluido nesta sessao (DD/MM)" no plano geral ou skill `encerrar-sessao` no fim do dia.

### Ordem de trabalho do agente

1. Identificar `Sn` / `Sn.Pm` afetados (argumento do usuario, diff, ou `oncoto-oncovo`).
2. Atualizar checklists + `%` do S pai (media ou valor explicito coerente).
3. Incluir os `.md` de plano no **mesmo** `git add` do codigo (preferir mesmo commit da entrega).
4. So entao `git commit` no padrao.
5. Se o usuario pediu push/`exporte`: push apos commit.
6. Sugerir (nao executar sem pedido): `glpi-task-upsert` / `glpi-retro-scan` para sync S/P.

### Excecoes (documentar no status ou mensagem)

- Commit **apenas** de formatacao/typo sem impacto de fase.
- Lockfile / gerados sem mudanca funcional — plano so se o P for deps/infra.
- Secrets / `.env` local: **nunca** commitar; planos nao devem conter senhas ou vetores sensiveis.

---

## Checklist pre-commit (agente)

- [ ] Planos S/P atualizados (produto e/ou modulo) **ou** justificativa de excecao
- [ ] Build/teste da app alterada (quando houver codigo)
- [ ] Sem secrets no stage
- [ ] Mensagem no padrao gitmoji + timestamp PT-BR
- [ ] Arquivos da entrega commitados (codigo + planos)

---

## Relacao com outras skills

| Skill | Papel |
|-------|--------|
| `documentar` | Updates pontuais de docs; **commit** exige o gate de plano |
| `documente-o-plano` | Criar plano novo S/P |
| `oncoto-oncovo` | Descobrir fase/item ativo antes de marcar |
| `exporte` | Commit (com este gate) + push |
| `encerrar-sessao` | `SESSAO_*` do dia (complementa, nao substitui checklist S/P) |
| `glpi-task-upsert` | Espelhar Status/% no GLPI apos commit |
| `inserir-pendencia` | Pendencias atemporais (nao substitui fechar S/P) |

---

## Exemplos

```text
✨ feat(web): shell operacional 4 paineis_27-07-26_13-58
📝 docs(docs): marca S2.P5 parcial apos testes_27-07-26_14-16
🐛 fix(backend): corrige upsert de cache_27-07-26_15-00
```

Se a mensagem cita um P, o arquivo de plano correspondente **deve** refletir o mesmo Status no commit.
