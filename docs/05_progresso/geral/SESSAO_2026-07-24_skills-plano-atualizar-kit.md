# Sessão 2026-07-24 — Skills de plano, atualizar-kit e sync nos produtos

## Sumário executivo

- Esclarecido: `glpi-retro-apply --env=homolog` em dry-run **não grava** no suporte-homolog (`--env` só escolhe contexto; `--apply` escreve).
- Criados skills **`documente-o-plano`** (planos S/P com timestamps GLPI) e **`atualizar-kit`** (+ `scripts/atualizar-kit` / `atualizar_kit.py`).
- Kit sincronizado nos produtos já instalados: Bot_Pan (`pmf-core`), samu-operacional e samu-web WSL/Windows (`full-skeleton`).
- Export (commit+push) dos produtos com remoto; skill **`inserir-pendencia`** + pasta `docs/05_progresso/pendencias/`.

## Commits da sessão (kit)

| Hash | Mensagem |
|------|----------|
| `bafb75b` | skills documente-o-plano e atualizar-kit |
| `51778fd` | skill inserir-pendencia e checklist atemporal |

## Problemas

- `pmf-dev-kit` sem `user.name`/`user.email` local — commits via env `GIT_AUTHOR_*` (sem alterar `git config`).
- `samu-web` WSL: bootstrap local **sem `origin`** (commit feito, push impossível).
- Push do samu-web Windows exigiu `credential.helper=store` na primeira tentativa.

## Decisões

- Perfil Bot_Pan: `pmf-core` (docs legadas com hífen preservadas).
- State local (ex.: `state-project-*.homolog.json`) fora do commit.
- Wrapper `scripts/atualizar-kit` + `.glpi/kit.yaml` em cada produto para sync futuro.

## Próximas ações

1. Nos produtos: `./scripts/atualizar-kit --check-only` / `--yes` quando o kit evoluir.
2. Usar `documente-o-plano` / `inserir-pendencia` nos produtos conforme demanda.
3. (Opcional) Configurar `origin` no `samu-web` WSL ou unificar com o clone Windows.
4. (Opcional) Anexar esta sessão ao Ticket via `glpi-document-attach`.

## Escopo

Foco: documentação de planejamento, sync do kit e publicação nos repositórios PMF.
