# Numeração docs — decisão de remapeamento

## Problema
Árvore de produto (figura): `00_visao_geral`, `01_requisitos`, …  
Kit anterior no samu-operacional: `docs/00-GLPI`  
→ conflito de identidade numérica no `00`.

## Decisão
| Antes (samu) | Kit fonte (`pmf-dev-kit`) |
|--------------|---------------------------|
| `docs/00-GLPI` | `docs/06_glpi` |
| (gap na figura entre 05 e 07) | ocupado por GLPI |
| `docs/05-gestao-projeto` | `docs/05_progresso` |
| `docs/01-arquitetura` | `docs/02_arquitetura` |
| `docs/03-compilacao` | `docs/03_implementacao/compilacao` |

Convenção de nome: `NN_snake_case` (underscores, sem acentos no path).
