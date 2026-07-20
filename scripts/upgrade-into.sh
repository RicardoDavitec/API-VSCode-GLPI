#!/usr/bin/env bash
# upgrade-into.sh — atualiza tools/skills/docs do kit sem apagar project.yaml / state
set -euo pipefail

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET=""
PROFILE="pmf-core"

usage() {
  echo "Uso: $0 <dir-projeto> [--profile=glpi-only|pmf-core|full-skeleton]"
}

for arg in "$@"; do
  case "$arg" in
    --profile=*) PROFILE="${arg#*=}" ;;
    -h|--help) usage; exit 0 ;;
    -*)
      echo "flag desconhecida: $arg" >&2
      exit 1
      ;;
    *) TARGET="$arg" ;;
  esac
done

[[ -n "$TARGET" ]] || { usage; exit 1; }
TARGET="$(cd "$TARGET" && pwd)"

echo "Upgrade (force tools/skills/docs kit) → $TARGET perfil=$PROFILE"
# Reusa bootstrap com --force; project.yaml existente é preservado pelo bootstrap
exec "$KIT_ROOT/scripts/bootstrap-into.sh" "$TARGET" --profile="$PROFILE" --force
