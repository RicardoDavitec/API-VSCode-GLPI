---
name: atualizar
description: "Use para analisar repositorios local e remoto e sincronizar: commit+push, pull ou merge inteligente conforme o estado. Nao use para backup ou encerrar sessao."
argument-hint: "Vazio — analise automatica."
---

# Skill: atualizar

Analisa local vs remoto e escolhe o caminho mais seguro para sincronizar.

## Modo eficiente (obrigatorio)

- Coletar em paralelo: `git status -sb`, `git fetch origin`, `git log --oneline HEAD..@{u}`, `git log --oneline @{u}..HEAD`.
- Decidir acao em uma tabela mental (abaixo); executar sem logs longos.
- Uma unica confirmacao antes de commit ou merge com conflito potencial.

## Fluxo obrigatorio

1. **Diagnostico**
   ```bash
   git branch --show-current
   git remote get-url origin
   git fetch origin
   git status -sb
   git log --oneline @{u}..HEAD    # commits locais nao publicados
   git log --oneline HEAD..@{u}    # commits remotos nao recebidos
   git diff --stat                 # se working tree suja
   ```
2. **Classificar estado**

   | Situacao | Acao |
   |----------|------|
   | Limpo, em sync | Informar OK; nada a fazer |
   | Limpo, ahead | `exporte` (push) |
   | Limpo, behind | `importe` (pull --ff-only) |
   | Limpo, diverged | Merge inteligente (passo 3) |
   | Dirty, sem conflito remoto | Commit → push ou stash → pull |
   | Dirty + diverged | Commit local → merge remoto (passo 3) |

3. **Merge inteligente** (apenas quando diverged e fast-forward impossivel)
   - Garantir working tree commitada ou stashed.
   - `git merge origin/<branch-ativo> --no-edit`
   - Se conflito: listar arquivos em conflito, **parar** e pedir resolucao manual (nao auto-resolver).
   - Apos merge limpo: `git push origin <branch-ativo>`.
4. **Dirty tree com alteracoes**
   - Se usuario confirmar: `git add` + commit (padrao skill `commit`) → seguir exporte ou merge conforme estado.
   - Nao commitar `.env`, secrets, `node_modules`.
5. **Relatorio final**
   - Branch, HEAD, ahead/behind, acao executada, proximo passo se bloqueado.

## Regras essenciais

- **Nunca** `--force`, `reset --hard`, `rebase -i` ou `push --force-with-lease`.
- Preferir `--ff-only` no pull; merge explicito so quando diverged.
- Em conflito: parar, listar arquivos, nao inventar resolucao.
- Branch padrao de trabalho: `teste-sigs-samu-operacional`.

## Ordem de delegacao interna

Este skill pode invocar logicamente:
- `exporte` — quando ahead ou dirty+commit
- `importe` — quando behind sem divergencia
- `commit` — para mensagem padrao

## Referencias

- Skills `exporte`, `importe`, `commit`
- `docs/05_progresso/geral/FLUXO_BRANCHES_AMBIENTES.md`
- `docs/05_progresso/geral/FLUXO_COMMIT_CHECKLIST.md`
- Dicas: [DICAS_USO.md](DICAS_USO.md)
