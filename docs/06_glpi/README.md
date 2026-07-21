# 06_glpi — Integração GLPI

Gestão de Ticket / Project / ProjectTask (hierarquia **S**=pai, **P**=filho).  
Compatível com **qualquer instância GLPI**; preset default **`api-vscode-glpi`** (exemplos PMF Franca).

## Documentos

| Documento | Conteúdo |
|-----------|----------|
| **[`MANUAL_INTEGRACAO_GLPI.md`](MANUAL_INTEGRACAO_GLPI.md)** | Passo a passo + presets + assistentes |
| [`MANUAL_USO_GLPI.md`](MANUAL_USO_GLPI.md) | CLI, configs, skills, troubleshooting |
| [`INTEGRACAO_GLPI_GESTAO_PROJETOS.md`](INTEGRACAO_GLPI_GESTAO_PROJETOS.md) | Visão de gestão |
| [`HIERARQUIA_S_P_GLPI.md`](HIERARQUIA_S_P_GLPI.md) | Mapeamento plano ↔ ProjectTask |
| [`REAVALIACAO_VSCODE_GIT_GLPI.md`](REAVALIACAO_VSCODE_GIT_GLPI.md) | Gap VSCode ↔ Git ↔ GLPI |

## Instalação rápida

```bash
./scripts/install-glpi.sh
# ou
python3 scripts/install_glpi.py
```

## Ferramentas

- CLI: `tools/glpi/glpi` — inclui **`states discover`**
- Assistentes: `scripts/install-glpi.sh` · `scripts/install_glpi.py`
- Bootstrap: `scripts/bootstrap-into.sh` (`--preset=api-vscode-glpi|generic`)
- Secrets: `~/.secrets/GLPI-tokens.txt`

## Gitness

[PMF-Integracao_GLPI/pmf-dev-kit](https://gitness.franca.sp.gov.br/PMF-Integracao_GLPI/pmf-dev-kit)

**Autor:** Dr. Ricardo David — [`AUTHORS.md`](../../AUTHORS.md) · Patrocínio: PMF — DTI · [MIT](../../LICENSE)
