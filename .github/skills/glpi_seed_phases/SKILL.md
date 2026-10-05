---
name: glpi-seed-phases
description: "DEPRECATED alias de glpi-phase-ensure. ATENCAO: o template samu-s-phases semeava SESSOES como fases. Redireciona para a skill primaria."
---

# Skill: glpi-seed-phases (deprecated)

**Deprecated desde o kit v2.0.0 (modelo F/S/P, schema 2).**

Preferir **`glpi-phase-ensure`**.

Se acionada pelo nome legado, carregar e seguir **integralmente**
[`.github/skills/glpi-phase-ensure/SKILL.md`](../glpi-phase-ensure/SKILL.md).

## Erro conceitual que esta depreciacao corrige

O template `samu-s-phases` criava `S0..S7` chamando-os de "fases". No modelo
atual, `S` e **sessao** (2o nivel), nao fase. As fases sao fixas em 5:

| Code | Nome |
|------|------|
| F1 | Planejamento |
| F2 | Implementacao |
| F3 | Testes Internos |
| F4 | Homologacao |
| F5 | Aprovacao |

Equivalencia:

~~~bash
# antes (errado no modelo atual)
./tools/glpi/bin/glpi-seed-phases --template=samu-s-phases
# agora (duas etapas distintas)
./tools/glpi/bin/glpi-phase-ensure --all --apply
./tools/glpi/bin/glpi-session-seed --from=sessions-seed.example.json --phase=F2 --apply
~~~

Templates depreciados: `samu-s-phases`, `product-s-phases.example`,
`corporate-phases`, `botpan-phases`, `generic-phases`.
Substituto canonico: `lifecycle-5-phases`.
Ver `docs/06_glpi/MIGRACAO_V1_V2.md`.