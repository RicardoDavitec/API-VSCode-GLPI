---
name: glpi-followup
description: "DEPRECATED alias de acompanhar-chamado. Use acompanhar-chamado (acompanhar chamado / registrar acompanhamento / follow-up GLPI). Redireciona para a skill primaria."
---

# Skill: glpi-followup (deprecated)

**Deprecated.** Preferir **`acompanhar-chamado`**.

Se acionada pelo nome legado, carregar e seguir **integralmente**
[`.github/skills/acompanhar-chamado/SKILL.md`](../acompanhar-chamado/SKILL.md)
— titulo sugerido + edicao/default, envio `ITILFollowup`, anexo opcional.

## Novidade do modelo F/S/P

O acompanhamento deve declarar o **no ancora** para que o texto cite fase,
sessao e tarefa — sem isso o registro fica sem rastreio hierarquico.

~~~bash
./tools/glpi/bin/glpi-followup - "<texto>"                 # legado, sem ancora
./tools/glpi/bin/glpi-followup --code=F2.S4 - "<texto>"    # com ancora
~~~

Preferir:

~~~bash
./tools/glpi/bin/glpi-followup-upsert --code=F2.S4.P5 --from-commits --apply
~~~