# pmf-dev-kit

Repositório **fonte** (template) da Prefeitura de Franca / PMF para bootstrap de gestão de projeto com:

- integração **GLPI** (CLI, skills, hierarquia S/P);
- skills de fluxo Git/sessão;
- árvore padronizada de **`docs/`**;
- scripts `bootstrap-into` / `upgrade-into` para aplicar em projetos vigentes.

> Cada projeto **vendoriza** uma cópia local (`tools/glpi`, skills, docs).  
> Secrets ficam em `~/.secrets/GLPI-tokens.txt` (nunca neste repo).

## Numeração de `docs/` (remapeada)

Conflito evitado: a árvore de produto usa `00_visao_geral`; o GLPI **não** ocupa `00`.

| Pasta | Conteúdo |
|-------|----------|
| `00_visao_geral` | Contexto, objetivos, glossário do produto |
| `01_requisitos` | Requisitos, regras de negócio |
| `02_arquitetura` | Arquitetura técnica |
| `03_implementacao` | Implementação, compilação, guias de build |
| `04_operacao` | Operação, runbooks, deploy |
| `05_progresso` | Plano, checklists, sessões, fluxo commit/branches |
| `06_glpi` | Integração GLPI (era `00-GLPI` no samu-operacional) |
| `07_doc_academica` | Material acadêmico / TCC / artigos |
| `08_imagens` | Assets e diagramas |
| `09_dados_e_tabelas` | Seeds, dumps descritivos, dicionário de dados |

## Perfis de bootstrap

| Perfil | Inclui |
|--------|--------|
| `glpi-only` | `tools/glpi`, skills `glpi-*`, `docs/06_glpi`, `.glpi` skeleton |
| `pmf-core` | + skills commit/exporte/importe/atualizar/backup/documentar/encerrar-sessao/oncoto-oncovo + `docs/05_progresso` |
| `full-skeleton` | + árvore completa `docs/00`…`09` + workflow example + `AGENTS.md.example` |

## Uso rápido

```bash
# Aplicar neste kit em um projeto existente
./scripts/bootstrap-into.sh /caminho/do/projeto --profile=pmf-core --key=meu-produto

cd /caminho/do/projeto
# editar .glpi/project.yaml (ticket_id / project_id)
./tools/glpi/bin/glpi-auth   # ou: ./tools/glpi/glpi auth
./tools/glpi/bin/glpi-seed-phases --template=corporate-phases
./tools/glpi/bin/glpi-retro-scan
```

Atualizar ferramentas sem sobrescrever config do produto:

```bash
./scripts/upgrade-into.sh /caminho/do/projeto --profile=pmf-core
```

## Origem

Extraído e generalizado a partir de `samu-operacional` (SIGS-Samu), com docs GLPI movidos de `docs/00-GLPI` → `docs/06_glpi`.
