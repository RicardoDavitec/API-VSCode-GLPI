---
name: encerrar-sessao
description: "Use para encerrar sessao/finalizar dia/resumo do dia. Cria SESSAO_AAAA-MM-DD em docs/05_progresso/geral, conduz commit/push e ofereceionalmente anexa o documento ao Ticket GLPI."
argument-hint: "Foco da sessao (ex: build mobile, docs geral, deploy servidor) ou vazio para resumo automatico."
---

# Skill: encerrar-sessao

Fecha a sessao do dia com registro objetivo em `docs/05_progresso/geral/`.

## Modo eficiente (obrigatorio)

- Coletar apenas comandos minimos (`git log` do dia e resumo de diff quando necessario).
- Gerar resumo curto e factual, sem repetir logs inteiros.
- Perguntas: commit, push, **anexo GLPI** (opcional), backup.

## Fluxo minimo obrigatorio

1. Coletar contexto:
   - `git log --oneline --since="00:00" --format="%h %s"`
2. Nomear arquivo: `SESSAO_AAAA-MM-DD_<DESCRICAO_CURTA>.md` em `docs/05_progresso/geral/`.
3. Criar documento com: Sumario Executivo, Commits da sessao, Problemas, Decisoes, Proximas acoes.
4. Atualizar `docs/05_progresso/geral/README.md` (ou `LEIA-ME.md` se existir).
5. Versionar: `git add docs/`, sugerir `docs(geral): registra sessao AAAA-MM-DD`, confirmar, commitar.
6. Perguntar sobre push.
7. **Anexar ao GLPI (opcional):** perguntar se deve enviar o `SESSAO_*` como Document no Ticket.
   - Dry-run: `./tools/glpi/bin/glpi-document-attach --file=docs/05_progresso/geral/SESSAO_....md --ticket`
   - Apply: mesmo comando com `--apply` (somente com confirmação).
   - Opcional: follow-up texto via skill `glpi-followup` apontando o arquivo/sha.
8. Perguntar sobre backup; se sim, carregar skill `backup` e executar.

## Regras essenciais

- Nao inventar atividades.
- Se nao houver commit no dia, registrar contexto real da conversa.
- Nunca usar `--force`.
- Nao anexar segredos (`.env`, tokens).

## Referencias

- Skill `documentar`
- Skill `glpi-followup`
- Skill `backup`
- Wrapper: `tools/glpi/bin/glpi-document-attach`
- Dicas: [DICAS_USO.md](DICAS_USO.md)
