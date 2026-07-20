---
name: exporte
description: "Use para salvar, verificar status, commitar e fazer push do branch ativo. Publica trabalho local no remoto. Nao use para pull, merge ou backup compactado."
argument-hint: "Opcional: escopo ou mensagem de commit (ex: web, docs)."
---

# Skill: exporte

Publica o trabalho local no repositorio remoto: status → commit (se necessario) → push do branch ativo.

## Modo eficiente (obrigatorio)

- Coletar apenas: `git status -sb`, `git diff --stat`, `git log -3 --oneline`.
- Uma unica confirmacao antes de commit (se houver alteracoes).
- Resposta final curta: branch, hash, ahead/behind, push OK.

## Fluxo obrigatorio

1. **Contexto**
   - `git status -sb`
   - `git branch --show-current`
   - `git remote get-url origin`
2. **Alteracoes locais**
   - Se working tree limpa e branch **nao** ahead: informar "nada a exportar".
   - Se working tree limpa e branch **ahead**: pular para push (passo 4).
   - Se houver alteracoes: `git diff --stat`; nao incluir `.env`, credenciais ou secrets.
3. **Commit** (quando necessario)
   - `git add` nos arquivos relevantes.
   - Mensagem no padrao `AGENTS.md` / skill `commit`: `<gitmoji> <tipo>(<escopo>): <descricao>_DD-MM-AA_hh-mm`
   - Confirmar uma vez com o usuario; commitar.
4. **Pre-push**
   - `git fetch origin`
   - `git status -sb` (verificar ahead/behind vs upstream)
   - Se **behind** remoto: avisar e sugerir skill `atualizar` ou `importe` antes de push.
5. **Push**
   - `git push -u origin <branch-ativo>` (primeira vez) ou `git push origin <branch-ativo>`
   - Nunca usar `--force` nem `--force-with-lease`.

## Regras essenciais

- Branch alvo: sempre o branch **atual** (`git branch --show-current`).
- Branch de trabalho padrao SAMU: `teste-sigs-samu-operacional`.
- Nao inventar arquivos no commit; nao commitar secrets.
- Se push falhar por autenticacao: orientar credencial Gitness/HTTPS (sem alterar `git config` global).

## Referencias

- Skill `commit`
- Skill `atualizar` (quando local e remoto divergiram)
- `docs/05_progresso/geral/FLUXO_COMMIT_CHECKLIST.md`
- Dicas: [DICAS_USO.md](DICAS_USO.md)
