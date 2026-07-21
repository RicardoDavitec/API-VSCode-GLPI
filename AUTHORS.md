# Autoria — pmf-dev-kit

## Autor principal e mantenedor

**Dr. Ricardo David**

| Contato | Endereço |
|---------|----------|
| **E-mail pessoal** | [rdavid38@hotmail.com](mailto:rdavid38@hotmail.com) |
| **E-mail corporativo** | [ricardodavid@franca.sp.gov.br](mailto:ricardodavid@franca.sp.gov.br) |

**Instituição patrocinadora:** Prefeitura Municipal de Franca (**PMF**) — Diretoria de Tecnologia da Informação (**DTI**)

| Papel | Escopo |
|-------|--------|
| **Concepção** | Modelo API-VSCode-GLPI (triângulo VSCode/Cursor ↔ Git ↔ GLPI) |
| **Arquitetura** | Vendorização por produto, presets, hierarquia S/P, secrets fora do git |
| **Implementação** | CLI `tools/glpi/`, assistentes `install-glpi.sh` / `install_glpi.py`, bootstrap/upgrade, skills Cursor |
| **Documentação** | Manuais em `docs/06_glpi/`, README de integração, generalização com exemplos PMF |
| **Manutenção** | Repositório fonte [PMF-Integracao_GLPI/pmf-dev-kit](https://gitness.franca.sp.gov.br/PMF-Integracao_GLPI/pmf-dev-kit) |

## Contexto institucional

Este kit foi **idealizado, implementado e documentado** pelo **Dr. Ricardo David**, com patrocínio institucional da **PMF — DTI**, no âmbito dos projetos de software da Prefeitura de Franca, em especial a integração de gestão de projetos com o GLPI institucional (`suporte.franca.sp.gov.br`).

**Origem técnica:** extraído e generalizado a partir do repositório **samu-operacional** (SIGS-Samu), onde a integração GLPI foi desenvolvida e validada operacionalmente (Ticket 10554 / Project 72 — exemplos documentais, não defaults obrigatórios).

**Evolução:** repositório **pmf-dev-kit** como template reutilizável para qualquer produto PMF — e, via preset `generic`, para instâncias GLPI compatíveis com a API REST.

## Como citar

Se utilizar este repositório em trabalhos, relatórios ou outro software, cite:

```text
David, R. (2026). pmf-dev-kit — Integração GLPI API-VSCode-GLPI
[software]. Autor: Dr. Ricardo David.
Instituição patrocinadora: Prefeitura Municipal de Franca — DTI.
https://gitness.franca.sp.gov.br/PMF-Integracao_GLPI/pmf-dev-kit
```

Versão BibTeX (`CITATION.bib` na raiz do repositório).

## Licença

Distribuído sob licença **MIT** — ver [`LICENSE`](LICENSE).

## Contribuições

Contribuições externas são bem-vindas via merge request no Gitness. Commits devem preservar o histórico de autoria; alterações substanciais podem ser registradas neste arquivo.

---

*Última atualização: 21/07/2026*
