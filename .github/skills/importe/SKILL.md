---
name: importe
description: "Use para verificar repositorio remoto e fazer pull do branch remoto. Traz alteracoes do origin para local. Nao use para commit, push ou backup."
argument-hint: "Opcional: branch remoto (padrao: upstream do branch ativo)."
---

# Skill: importe

Atualiza o repositorio local com commits do remoto (fetch + pull seguro).

## Modo eficiente (obrigatorio)

- Coletar apenas: `git status -sb`, `git fetch origin`, `git log HEAD..origin/<branch> --oneline`.
- Uma unica pergunta se houver alteracoes locais nao commitadas.
- Resposta final curta: commits recebidos, novo HEAD, status.

## Fluxo obrigatorio

1. **Contexto**
   - `git branch --show-current`
   - `git remote get-url origin`
   - `git status -sb`
2. **Fetch**
   - `git fetch origin`
3. **Analise remota**
   - Branch alvo: argumento do usuario ou upstream (`@{u}`) do branch ativo.
   - `git log HEAD..origin/<branch> --oneline` — commits a receber.
   - Se zero commits novos: informar "local ja atualizado".
4. **Alteracoes locais nao commitadas**
   - Se `git status` mostrar modificacoes: perguntar uma vez:
     - **Stash** (`git stash push -m "importe-temp"`) → pull → opcional `git stash pop`
     - **Abortar** e pedir commit/exporte antes
   - Nunca descartar alteracoes sem confirmacao.
5. **Pull**
   - Preferir fast-forward: `git pull --ff-only origin <branch>`
   - Se `--ff-only` falhar: informar divergencia e sugerir skill `atualizar` (nao fazer merge automatico neste skill).
6. **Pos-pull**
   - `git status -sb`
   - `git log -3 --oneline`

## Regras essenciais

- Nunca usar `--force`, `reset --hard` nem `rebase -i`.
- Nao commitar nem fazer push neste skill.
- Remoto padrao SAMU: Gitness `https://gitness.franca.sp.gov.br/git/SIGS/samu-operacional.git`

## Referencias

- Skill `exporte` (fluxo inverso)
- Skill `atualizar` (quando local e remoto divergiram)
- `docs/05_progresso/geral/FLUXO_BRANCHES_AMBIENTES.md`
- Dicas: [DICAS_USO.md](DICAS_USO.md)
