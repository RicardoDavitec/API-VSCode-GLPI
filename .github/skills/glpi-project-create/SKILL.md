---
name: glpi-project-create
description: "DEPRECATED alias de glpi-project-upsert. Redireciona para a skill primaria; nao usar em novos fluxos."
---

# Skill: glpi-project-create (deprecated)

**Deprecated desde o kit v2.0.0 (modelo F/S/P, schema 2).**

Preferir **`glpi-project-upsert`**.

Se acionada pelo nome legado, carregar e seguir **integralmente**
[`.github/skills/glpi-project-upsert/SKILL.md`](../glpi-project-upsert/SKILL.md).

Motivo: a skill antiga só **criava**. A nova cobre criar, renomear, redescrever,
mudar estado/datas/prioridade/responsavel e atuar tambem sobre subprojetos de fase.

Equivalencia:

~~~bash
# antes
./tools/glpi/bin/glpi-project-create --name="X" --code=X --state=gep1 --apply
# agora
./tools/glpi/bin/glpi-project-upsert --name="X" --code=X --state=todo --apply
~~~

Atencao: a antiga sugeria `glpi-seed-phases --template=samu-s-phases`, que
semeava `S0..S7` como fases — no modelo atual essas sao **sessoes**.
Use `glpi-phase-ensure --all` para as 5 fases reais.