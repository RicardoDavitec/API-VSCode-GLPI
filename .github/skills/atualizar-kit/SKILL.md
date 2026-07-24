---
name: atualizar-kit
description: "Verifica atualizacoes no repositorio fonte pmf-dev-kit e sincroniza tools/skills/docs no repositorio produto que chamou. Use quando o usuario pedir atualizar kit, sync kit, upgrade kit ou sincronizar pmf-dev-kit."
argument-hint: "Opcional: --profile=pmf-core|full-skeleton|glpi-only · --check-only · caminho do kit"
---

# Skill: atualizar-kit

Sincroniza o **produto atual** (repo que chamou) com novidades do **pmf-dev-kit** sem apagar `.glpi/project.yaml` / state.

## Gatilhos

- "atualizar kit", "sync kit", "upgrade kit", "sincronizar pmf-dev-kit"

## Fluxo obrigatorio

1. **Resolver dirs**
   - `TARGET` = raiz do repositorio produto (`git rev-parse --show-toplevel` ou cwd do produto).
   - `KIT` = clone do pmf-dev-kit (ver resolucao abaixo).
2. **Checar updates no kit**
   ```bash
   python3 "$KIT/scripts/atualizar_kit.py" --target="$TARGET" --check-only
   # ou wrapper:
   "$KIT/scripts/atualizar-kit" --target="$TARGET" --check-only
   ```
3. **Se houver commits novos no remoto do kit** (ou working tree do kit mais nova que a ultima sync):
   - Mostrar resumo (`git log` curto do kit).
   - Confirmar com o usuario antes de gravar no produto (exceto se `--yes`).
4. **Aplicar sync**
   ```bash
   "$KIT/scripts/atualizar-kit" --target="$TARGET" --profile=full-skeleton --yes
   ```
   Perfil default sugerido: o mesmo ja usado no produto (`full-skeleton` se existir `docs/00_visao_geral`; senao `pmf-core`).
5. **Relatorio**
   - Branch/HEAD do kit, perfil, arquivos novos/alterados (`git status -sb` no TARGET).
   - Nao commitar automaticamente; sugerir skill `exporte` / `commit` se o usuario quiser.

## Resolucao do caminho do kit

Ordem:

1. Flag `--kit=/caminho/pmf-dev-kit`
2. Env `PMF_DEV_KIT` ou `PMF_KIT_ROOT`
3. `.glpi/kit.yaml` no produto com `path: /.../pmf-dev-kit`
4. Irmao comum: `../pmf-dev-kit` relativo ao TARGET
5. Fallback: `$HOME/projetos/pmf-dev-kit`

Se nao achar: **parar** e pedir o caminho.

## Regras essenciais

- Preservar sempre `.glpi/project.yaml`, `workspace.yaml` e `state-project-*.json`.
- Preferir `git fetch` + comparar com `origin/<branch>` no kit; so `git pull` no kit se o usuario autorizar (working tree do kit limpa).
- Nunca `--force` git / reset hard no produto.
- Nao sobrescrever skills especificos do produto (ex.: `build-*`) — o bootstrap/upgrade so atualiza skills do kit.
- Se TARGET == KIT: informar que ja esta no fonte; nada a sincronizar para si mesmo.

## Wrappers no produto (apos bootstrap)

Se o produto tiver `scripts/atualizar-kit` vendorizado, preferir:

```bash
./scripts/atualizar-kit --check-only
./scripts/atualizar-kit --profile=full-skeleton --yes
```

## Referencias

- `scripts/atualizar_kit.py` · `scripts/atualizar-kit`
- `scripts/upgrade-into.sh` · `scripts/bootstrap-into.sh`
- README secao "Atualizar o kit no projeto"
