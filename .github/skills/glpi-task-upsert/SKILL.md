---
name: glpi-task-upsert
description: "DEPRECATED alias de glpi-node-upsert. Redireciona para a skill primaria; nao usar em novos fluxos."
---

# Skill: glpi-task-upsert (deprecated)

**Deprecated desde o kit v2.0.0 (modelo F/S/P, schema 2).**

Preferir **`glpi-node-upsert`**.

Se acionada pelo nome legado, carregar e seguir **integralmente**
[`.github/skills/glpi-node-upsert/SKILL.md`](../glpi-node-upsert/SKILL.md).

Motivo: a antiga assumia 2 niveis (`--code=S4`, `--parent-code=S4`). O modelo
atual tem 3 (`F2`, `F2.S4`, `F2.S4.P5`) e o pai e **resolvido automaticamente**.

Equivalencia:

~~~bash
# antes
./tools/glpi/bin/glpi-task-upsert --code=S4 --name="..." --state=gep3 --percent=60
./tools/glpi/bin/glpi-task-upsert --code=S4.P5 --parent-code=S4 --name="..." --apply
# agora (com a fase explicita)
./tools/glpi/bin/glpi-node-upsert --code=F2.S4 --name="..." --state=doing --percent=60
./tools/glpi/bin/glpi-node-upsert --code=F2.S4.P5 --name="..." --apply
~~~

Codes v1 sem fase sao migrados por:
`./tools/glpi/bin/glpi-migrate-codes --dry-run`