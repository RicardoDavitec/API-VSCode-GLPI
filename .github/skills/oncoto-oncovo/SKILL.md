---
name: oncoto-oncovo
description: "Levantar situacao do desenvolvimento SAMU Operacional — onde estou, onde vou, proximo passo. Use no inicio de sessao, apos milestone ou antes de deploy."
---

# Skill: oncoto-oncovo

Responda sempre nesta estrutura (4 blocos):

## 1. Onde estou

- Fase atual do `docs/05_progresso/geral/PLANO_IMPLEMENTACAO.md` (S0–S7)
- Branch ativa e sync com remoto (`git status -sb`)
- Ambiente de teste (local dev / servidor intranet / URL publica)
- Ultimo checkpoint validado

## 2. Onde vou

- Proximo item ativo do plano
- Sequencia recomendada (S1 → S4 → S3 → S2…)
- Dependencias bloqueantes (Infra, SIGS, credenciais)

## 3. Estado do checklist

- Tabela resumida: item | status | criterio de teste
- Marcar [x] / [~] / [ ] conforme codigo + testes reais

## 4. Acao imediata

- Um unico proximo passo executavel (comando ou tarefa de codigo)
- Maximo 2 ideias extras se alinhadas ao plano

## Fontes obrigatorias

1. `docs/05_progresso/geral/PLANO_IMPLEMENTACAO.md`
2. `docs/05_progresso/geral/FLUXO_BRANCHES_AMBIENTES.md`
3. `git log -5 --oneline` e `git status -sb`

## Deploy / ambiente

| Perfil | Onde | Comando |
|--------|------|---------|
| dev | WSL local | `npm run docker:dev` |
| prod | Servidor 172.21.31.167 | `npm run deploy:server` ou Harness |

URL teste intranet/producao inicial: `https://samu.franca.sp.gov.br`
