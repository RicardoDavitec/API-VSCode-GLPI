---
name: glpi-document-attach
description: >-
  Anexa arquivo a Project, fase, sessao, tarefa (por code F/S/P) ou Ticket no
  GLPI. Markdown vira PDF se houver conversor. Recusa arquivos sensiveis.
  Use em anexar documento glpi, anexar plano, anexar evidencia, subir ata.
---

# Skill: glpi-document-attach

Cria `Document` no GLPI e vincula ao item alvo via `Document_Item`.

## Comandos

~~~bash
# Plano no nivel da sessao
./tools/glpi/bin/glpi-document-attach \
  --file=docs/05_progresso/planos_ativos/plano-05_10_26-09_30.md \
  --code=F2.S4 --apply

# Evidencia de homologacao em tarefa
./tools/glpi/bin/glpi-document-attach --file=evidencias/tela-login.png \
  --code=F4.S1.P2 --name="Evidencia: tela de login homologada" --apply

# Ata no nivel da fase
./tools/glpi/bin/glpi-document-attach --file=docs/07_homologacao/ata-03.md \
  --code=F4 --apply

# Termo de aceite no projeto raiz
./tools/glpi/bin/glpi-document-attach --file=docs/08_aceite/termo.pdf \
  --project --apply

# Ticket institucional
./tools/glpi/bin/glpi-document-attach --file=relatorio.pdf --ticket=12345 --apply

# Manter Markdown (nao converter)
./tools/glpi/bin/glpi-document-attach --file=plano.md --code=F1 --raw --apply

# Lote
./tools/glpi/bin/glpi-document-attach --glob='evidencias/F4_S1_*.png' \
  --code=F4.S1 --apply
~~~

## Parametros

| Flag | Default | Descricao |
|------|---------|-----------|
| `--file=PATH` | — | Arquivo (obrigatorio, ou `--glob`) |
| `--glob=PADRAO` | — | Multiplos arquivos |
| `--code=F2.S4` | — | Alvo pelo code F/S/P |
| `--project` | — | Alvo = projeto raiz |
| `--ticket=ID` | — | Alvo = `Ticket` |
| `--name=STR` | nome do arquivo | Nome do `Document` |
| `--comment=STR` | — | Campo de comentario |
| `--raw` | off | Nao converte `.md` para PDF |
| `--pdf` | auto | Forca conversao |
| `--entity=ID` | preset | `entities_id` |
| `--replace` | off | Substitui documento homonimo em vez de duplicar |
| `--apply` | off | Efetiva (confirmacao) |

## Conversao Markdown -> PDF

Se `tools/glpi/bin/glpi-md-to-pdf` existir, `.md` e convertido antes do upload
(preserva tabelas, *checklists* e o cabecalho `glpi-meta`).
Ausente o conversor: envia o Markdown bruto com aviso.
`--raw` sempre vence.

## Nomenclatura

~~~text
name: "[F2.S4] plano-05_10_26-09_30.pdf"
~~~

O prefixo `[code]` garante rastreio na aba Documentos do GLPI, onde a origem
hierarquica nao e visivel.

## Seguranca (bloqueio incondicional)

Recusa, **mesmo com `--apply`**, arquivos que casem `safety.deny_attach`:

~~~text
*.env  ·  .env*  ·  *.pem  ·  id_rsa*  ·  *.key  ·  *secret*  ·  *.p12  ·  *token*
~~~

Alem disso:
- Varre arquivos de texto com `safety.deny_content_regex`; achando segredo,
  **aborta** e indica linha/arquivo (nao redige automaticamente).
- Recusa arquivo > `--max-size` (default 20 MB) com sugestao de compactar.
- Recusa `.zip`/`.tar.gz` contendo padrao negado (inspeciona listagem).

## Idempotencia

Sem `--replace`, documento com mesmo nome **e** mesmo hash SHA-256 ja vinculado
ao alvo e **ignorado** (mensagem `skip: ja anexado`). Hash diferente com mesmo
nome gera sufixo `-v2`, `-v3`.

Codigos de saida: `0` ok · `2` arquivo invalido · `4` alvo nao resolvido ·
`5` API · `6` abortado · `12` arquivo negado por politica de seguranca.