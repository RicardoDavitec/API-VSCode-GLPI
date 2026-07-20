#!/usr/bin/env bash
# bootstrap-into.sh — aplica o pmf-dev-kit em um projeto vigente (vendoriza cópia local)
set -euo pipefail

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET=""
PROFILE="pmf-core"
KEY=""
TICKET=""
PROJECT=""
FORCE=0

usage() {
  cat <<EOF
Uso: $0 <dir-projeto> [opcoes]

Opcoes:
  --profile=glpi-only|pmf-core|full-skeleton   (default: pmf-core)
  --key=NOME                 chave em project.yaml
  --ticket=ID                ticket_id GLPI
  --project=ID               project_id GLPI
  --force                    sobrescreve tools/skills/docs do kit mesmo se existirem
  -h|--help

Exemplos:
  $0 /home/wsl/projetos/meu-app --profile=full-skeleton --key=meu-app
  $0 ../outro-repo --profile=glpi-only --ticket=10554 --project=72
EOF
}

for arg in "$@"; do
  case "$arg" in
    --profile=*) PROFILE="${arg#*=}" ;;
    --key=*) KEY="${arg#*=}" ;;
    --ticket=*) TICKET="${arg#*=}" ;;
    --project=*) PROJECT="${arg#*=}" ;;
    --force) FORCE=1 ;;
    -h|--help) usage; exit 0 ;;
    -*)
      echo "flag desconhecida: $arg" >&2
      usage
      exit 1
      ;;
    *)
      if [[ -z "$TARGET" ]]; then
        TARGET="$arg"
      else
        echo "argumento extra: $arg" >&2
        exit 1
      fi
      ;;
  esac
done

[[ -n "$TARGET" ]] || { usage; exit 1; }
TARGET="$(cd "$TARGET" 2>/dev/null && pwd || true)"
[[ -n "$TARGET" && -d "$TARGET" ]] || { echo "diretorio alvo invalido" >&2; exit 1; }

KEY="${KEY:-$(basename "$TARGET")}"

copy_tree() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ -e "$dest" && "$FORCE" -ne 1 ]]; then
    # merge: rsync sem apagar extras do destino
    rsync -a "$src/" "$dest/"
  else
    rsync -a "$src/" "$dest/"
  fi
}

echo "Kit:     $KIT_ROOT"
echo "Alvo:    $TARGET"
echo "Perfil:  $PROFILE"
echo "Key:     $KEY"
echo

# Sempre: tools/glpi
copy_tree "$KIT_ROOT/tools/glpi" "$TARGET/tools/glpi"
chmod +x "$TARGET/tools/glpi/glpi" "$TARGET/tools/glpi/bin/"* 2>/dev/null || true

# .glpi maps + templates (não sobrescreve project.yaml existente)
mkdir -p "$TARGET/.glpi/maps" "$TARGET/.glpi/templates"
rsync -a "$KIT_ROOT/.glpi/maps/" "$TARGET/.glpi/maps/"
rsync -a "$KIT_ROOT/.glpi/templates/" "$TARGET/.glpi/templates/"

if [[ ! -f "$TARGET/.glpi/project.yaml" ]]; then
  sed -e "s/meu-produto/${KEY}/g" \
      -e "s/ticket_id: 0/ticket_id: ${TICKET:-0}/g" \
      -e "s/project_id: 0/project_id: ${PROJECT:-0}/g" \
      "$KIT_ROOT/.glpi/project.yaml.example" >"$TARGET/.glpi/project.yaml"
  echo "Criado .glpi/project.yaml"
else
  echo "Mantido .glpi/project.yaml existente"
fi

if [[ ! -f "$TARGET/.glpi/workspace.yaml" ]]; then
  sed -e "s/meu-produto/${KEY}/g" \
      -e "s|/caminho/absoluto/do/clone|${TARGET}|g" \
      -e "s/ticket_id: 0/ticket_id: ${TICKET:-0}/g" \
      -e "s/project_id: 0/project_id: ${PROJECT:-0}/g" \
      "$KIT_ROOT/.glpi/workspace.yaml.example" >"$TARGET/.glpi/workspace.yaml"
  echo "Criado .glpi/workspace.yaml"
else
  echo "Mantido .glpi/workspace.yaml existente"
fi

# docs/06_glpi sempre nos perfis com glpi
mkdir -p "$TARGET/docs/06_glpi/retro-scans"
rsync -a --exclude 'retro-scans/*.json' --exclude 'retro-scans/*.md' \
  "$KIT_ROOT/docs/06_glpi/" "$TARGET/docs/06_glpi/"
[[ -f "$TARGET/docs/06_glpi/retro-scans/README.md" ]] || \
  cp "$KIT_ROOT/docs/06_glpi/retro-scans/README.md" "$TARGET/docs/06_glpi/retro-scans/"

install_skill() {
  local name="$1"
  copy_tree "$KIT_ROOT/.github/skills/$name" "$TARGET/.github/skills/$name"
}

case "$PROFILE" in
  glpi-only)
    for s in glpi-followup glpi-task-upsert glpi-project-create glpi-retro-scan; do
      install_skill "$s"
    done
    ;;
  pmf-core|full-skeleton)
    for s in commit documentar exporte importe atualizar backup encerrar-sessao oncoto-oncovo \
             glpi-followup glpi-task-upsert glpi-project-create glpi-retro-scan; do
      install_skill "$s"
    done
    cp "$KIT_ROOT/.github/skills/GUIA_USO_SKILLS.md" "$TARGET/.github/skills/GUIA_USO_SKILLS.md"
    mkdir -p "$TARGET/docs/05_progresso/geral" "$TARGET/docs/05_progresso/infra"
    rsync -a "$KIT_ROOT/docs/05_progresso/" "$TARGET/docs/05_progresso/"
    if [[ ! -f "$TARGET/docs/05_progresso/geral/PLANO_IMPLEMENTACAO.md" ]]; then
      cp "$KIT_ROOT/docs/05_progresso/geral/PLANO_IMPLEMENTACAO.md.example" \
         "$TARGET/docs/05_progresso/geral/PLANO_IMPLEMENTACAO.md.example"
    fi
    ;;
  *)
    echo "perfil invalido: $PROFILE" >&2
    exit 1
    ;;
esac

if [[ "$PROFILE" == "full-skeleton" ]]; then
  for d in 00_visao_geral 01_requisitos 02_arquitetura 03_implementacao 04_operacao \
           07_doc_academica 08_imagens 09_dados_e_tabelas; do
    mkdir -p "$TARGET/docs/$d"
    rsync -a "$KIT_ROOT/docs/$d/" "$TARGET/docs/$d/"
  done
  cp "$KIT_ROOT/docs/README.md" "$TARGET/docs/README.md"
  mkdir -p "$TARGET/.github/workflows"
  if [[ ! -f "$TARGET/.github/workflows/ci.yml" ]]; then
    cp "$KIT_ROOT/.github/workflows/ci.yml.example" "$TARGET/.github/workflows/ci.yml.example"
  fi
  if [[ ! -f "$TARGET/AGENTS.md" ]]; then
    sed "s/{{NOME_PRODUTO}}/${KEY}/g" "$KIT_ROOT/AGENTS.md.example" >"$TARGET/AGENTS.md.example"
  fi
fi

cat <<EOF

Bootstrap concluido.

Proximos passos:
  1. Editar $TARGET/.glpi/project.yaml (ticket_id / project_id)
  2. cd $TARGET && ./tools/glpi/glpi auth
  3. ./tools/glpi/bin/glpi-seed-phases --template=corporate-phases
  4. ./tools/glpi/bin/glpi-retro-scan
  5. Revisar JSON e ./tools/glpi/bin/glpi-retro-apply --from=... [--apply]

Docs GLPI: docs/06_glpi/
Plano:     docs/05_progresso/geral/
EOF
