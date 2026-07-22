#!/usr/bin/env bash
# install-glpi.sh — assistente de implantacao GLPI (interativo + flags)
# Orquestra bootstrap-into, auth, states discover e seed opcional.
set -euo pipefail

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET=""
PROFILE="pmf-core"
PRESET="api-vscode-glpi"
KEY=""
TICKET=""
PROJECT=""
GLPI_URL=""
SECRETS_FILE="${HOME}/.secrets/glpi.env"
SECRETS_FORMAT="dotenv"
NON_INTERACTIVE=0
SKIP_BOOTSTRAP=0
SKIP_AUTH=0
SKIP_DISCOVER=0
SKIP_SEED=0
FORCE=0
YES=0

usage() {
  cat <<EOF
Uso: $0 [opcoes] [dir-projeto]

Assistente de implantacao da integracao GLPI (pmf-dev-kit).
Preset default: api-vscode-glpi (exemplo PMF Franca).

Opcoes:
  --target=PATH              diretorio do produto (obrigatorio em --non-interactive)
  --profile=PERFIL           glpi-only | pmf-core | full-skeleton (default: pmf-core)
  --preset=PRESET            api-vscode-glpi | generic (default: api-vscode-glpi)
  --key=NOME                 chave em project.yaml
  --ticket=ID                ticket_id GLPI (0 = preencher depois)
  --project=ID               project_id GLPI (0 = preencher depois)
  --glpi-url=URL             base API (ex.: https://host/apirest.php)
  --secrets-file=PATH        default: ~/.secrets/glpi.env
  --secrets-format=dotenv|pmf|generic|env
  --force                    sobrescreve tools/skills/docs no bootstrap
  --non-interactive          sem prompts (requer --target)
  --yes                      aceitar defaults / confirmar --apply automaticamente
  --skip-bootstrap           pular bootstrap-into
  --skip-auth                pular glpi auth
  --skip-discover            pular states discover
  --skip-seed                pular seed-phases
  -h|--help

Exemplos:
  $0
  $0 --target=~/projetos/meu-app --preset=api-vscode-glpi --non-interactive --yes
  $0 --target=~/projetos/app --preset=generic --glpi-url=https://glpi.org/apirest.php --non-interactive
EOF
}

log() { echo "==> $*"; }
prompt() {
  local msg="$1" default="${2:-}"
  if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    echo "$default"
    return 0
  fi
  read -r -p "$msg [$default]: " ans || true
  echo "${ans:-$default}"
}

confirm() {
  local msg="$1"
  if [[ "$YES" -eq 1 || "$NON_INTERACTIVE" -eq 1 ]]; then
    return 0
  fi
  read -r -p "$msg [s/N]: " ans || true
  [[ "${ans,,}" == "s" || "${ans,,}" == "sim" || "${ans,,}" == "y" ]]
}

detect_os() {
  if grep -qi microsoft /proc/version 2>/dev/null; then
    echo "wsl"
  elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    echo "git-bash"
  else
    echo "linux"
  fi
}

check_prereqs() {
  local missing=0 cmd
  for cmd in bash curl jq python3 rsync git; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "  FALTANDO: $cmd" >&2
      missing=1
    fi
  done
  [[ "$missing" -eq 0 ]] || die_prereq
}

die_prereq() {
  echo "Instale dependencias. Debian/Ubuntu/WSL:" >&2
  echo "  sudo apt install -y bash curl jq python3 rsync git" >&2
  exit 1
}

check_secrets() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo "  AVISO: secrets ausentes: $f"
    echo "  Crie com formato pmf (Pessoal/Grupo/URL-API) ou generic (USER_TOKEN/APP_TOKEN/API_URL)."
    echo "  Exemplo PMF: https://suporte.franca.sp.gov.br/apirest.php"
    return 1
  fi
  if ! grep -qiE 'pessoal.*api-glpi|user_token' "$f" 2>/dev/null; then
    echo "  AVISO: token de usuario nao detectado em $f"
    return 1
  fi
  echo "  OK: $f"
  return 0
}

apply_preset_files() {
  local preset="$1" target="$2"
  local preset_dir="${KIT_ROOT}/.glpi/presets/${preset}"
  [[ -d "$preset_dir" ]] || { echo "preset invalido: $preset" >&2; exit 1; }

  mkdir -p "${target}/.glpi/maps" "${target}/.glpi/presets"
  if [[ -f "${preset_dir}/maps/states.json" ]]; then
    cp "${preset_dir}/maps/states.json" "${target}/.glpi/maps/states.json"
  fi
  if [[ ! -f "${target}/.glpi/instance.yaml" ]]; then
    if [[ -f "${preset_dir}/instance.yaml.example" ]]; then
      cp "${preset_dir}/instance.yaml.example" "${target}/.glpi/instance.yaml"
    else
      cp "${KIT_ROOT}/.glpi/instance.yaml.example" "${target}/.glpi/instance.yaml"
      sed -i "s/^preset:.*/preset: ${preset}/" "${target}/.glpi/instance.yaml"
    fi
  fi
  if [[ -n "$GLPI_URL" && -f "${target}/.glpi/instance.yaml" ]]; then
    sed -i "s|^  api_url:.*|  api_url: \"${GLPI_URL}\"|" "${target}/.glpi/instance.yaml"
  fi
}

for arg in "$@"; do
  case "$arg" in
    --target=*) TARGET="${arg#--target=}" ;;
    --profile=*) PROFILE="${arg#*=}" ;;
    --preset=*) PRESET="${arg#*=}" ;;
    --key=*) KEY="${arg#*=}" ;;
    --ticket=*) TICKET="${arg#*=}" ;;
    --project=*) PROJECT="${arg#*=}" ;;
    --glpi-url=*) GLPI_URL="${arg#*=}" ;;
    --secrets-file=*) SECRETS_FILE="${arg#*=}" ;;
    --secrets-format=*) SECRETS_FORMAT="${arg#*=}" ;;
    --force) FORCE=1 ;;
    --non-interactive) NON_INTERACTIVE=1 ;;
    --yes) YES=1 ;;
    --skip-bootstrap) SKIP_BOOTSTRAP=1 ;;
    --skip-auth) SKIP_AUTH=1 ;;
    --skip-discover) SKIP_DISCOVER=1 ;;
    --skip-seed) SKIP_SEED=1 ;;
    -h|--help) usage; exit 0 ;;
    -*)
      echo "flag desconhecida: $arg" >&2
      usage
      exit 1
      ;;
    *)
      [[ -z "$TARGET" ]] && TARGET="$arg" || { echo "argumento extra: $arg" >&2; exit 1; }
      ;;
  esac
done

echo "pmf-dev-kit — install-glpi.sh"
echo "Kit:  $KIT_ROOT"
echo "OS:   $(detect_os)"
echo

check_prereqs

if [[ "$NON_INTERACTIVE" -eq 0 ]]; then
  echo "Modo interativo. Use --non-interactive para automacao."
  echo
  PRESET="$(prompt "Preset (api-vscode-glpi=PMF Franca | generic)" "$PRESET")"
  PROFILE="$(prompt "Perfil bootstrap (glpi-only|pmf-core|full-skeleton)" "$PROFILE")"
  if [[ -z "$TARGET" ]]; then
    TARGET="$(prompt "Diretorio do produto (absoluto)" "$HOME/projetos/meu-produto")"
  fi
  if [[ -z "$GLPI_URL" && "$PRESET" == "api-vscode-glpi" ]]; then
    GLPI_URL="$(prompt "URL API GLPI" "https://suporte.franca.sp.gov.br/apirest.php")"
  elif [[ -z "$GLPI_URL" ]]; then
    GLPI_URL="$(prompt "URL API GLPI (https://host/apirest.php)" "")"
  fi
  KEY="${KEY:-$(basename "$TARGET")}"
  KEY="$(prompt "Key do produto" "$KEY")"
  TICKET="$(prompt "ticket_id (0=depois)" "${TICKET:-0}")"
  PROJECT="$(prompt "project_id (0=depois)" "${PROJECT:-0}")"
  SECRETS_FILE="$(prompt "Arquivo secrets" "$SECRETS_FILE")"
fi

[[ -n "$TARGET" ]] || { echo "informe --target ou diretorio" >&2; usage; exit 1; }
mkdir -p "$TARGET"
TARGET="$(cd "$TARGET" && pwd)"
KEY="${KEY:-$(basename "$TARGET")}"

log "Alvo: $TARGET | preset: $PRESET | perfil: $PROFILE"
check_secrets "$SECRETS_FILE" || true

if [[ "$SKIP_BOOTSTRAP" -eq 0 ]]; then
  log "Bootstrap..."
  bootstrap_args=("$TARGET" "--profile=$PROFILE" "--key=$KEY" "--preset=$PRESET")
  [[ -n "$TICKET" ]] && bootstrap_args+=("--ticket=$TICKET")
  [[ -n "$PROJECT" ]] && bootstrap_args+=("--project=$PROJECT")
  [[ "$FORCE" -eq 1 ]] && bootstrap_args+=("--force")
  "$KIT_ROOT/scripts/bootstrap-into.sh" "${bootstrap_args[@]}"
else
  log "Bootstrap ignorado (--skip-bootstrap)"
  apply_preset_files "$PRESET" "$TARGET"
fi

# Garantir instance.yaml com preset/url
apply_preset_files "$PRESET" "$TARGET"

if [[ "$SKIP_AUTH" -eq 0 ]]; then
  log "Teste auth GLPI..."
  if (
    cd "$TARGET"
    export GLPI_SECRETS_FILE="$SECRETS_FILE"
    export GLPI_SECRETS_FORMAT="$SECRETS_FORMAT"
    [[ -n "$GLPI_URL" ]] && export GLPI_API_URL="$GLPI_URL"
    ./tools/glpi/glpi auth >/dev/null
  ); then
    echo "  OK: autenticacao"
  else
    echo "  FALHA: auth — verifique secrets e URL" >&2
    exit 1
  fi
fi

if [[ "$SKIP_DISCOVER" -eq 0 ]]; then
  log "Descoberta de estados (ProjectState via API)..."
  discover_args=(--repo-root "$TARGET" --preset "$PRESET" --secrets-file "$SECRETS_FILE" --secrets-format "$SECRETS_FORMAT")
  [[ -n "$GLPI_URL" ]] && discover_args+=(--api-url "$GLPI_URL")
  if confirm "Gravar .glpi/maps/states.json a partir da API?"; then
    if ! python3 "$KIT_ROOT/tools/glpi/lib/states_discover.py" "${discover_args[@]}" --apply; then
      echo "  AVISO: discover falhou — mantendo mapa do preset em .glpi/maps/states.json"
    fi
  else
    python3 "$KIT_ROOT/tools/glpi/lib/states_discover.py" "${discover_args[@]}" || true
  fi
fi

if [[ "$SKIP_SEED" -eq 0 ]]; then
  log "Seed de fases (dry-run)..."
  tpl="corporate-phases"
  [[ "$PRESET" == "generic" ]] && tpl="generic-phases"
  (
    cd "$TARGET"
    export GLPI_SECRETS_FILE="$SECRETS_FILE"
    export GLPI_SECRETS_FORMAT="$SECRETS_FORMAT"
    [[ -n "$GLPI_URL" ]] && export GLPI_API_URL="$GLPI_URL"
    ./tools/glpi/bin/glpi-seed-phases --template="$tpl" || true
  )
  if confirm "Aplicar seed-phases (--apply) no GLPI?"; then
    (
      cd "$TARGET"
      export GLPI_SECRETS_FILE="$SECRETS_FILE"
      export GLPI_SECRETS_FORMAT="$SECRETS_FORMAT"
      [[ -n "$GLPI_URL" ]] && export GLPI_API_URL="$GLPI_URL"
      ./tools/glpi/bin/glpi-seed-phases --template="$tpl" --apply
    )
  fi
fi

cat <<EOF

Instalacao concluida.

Produto:  $TARGET
Preset:   $PRESET
Docs:     $TARGET/docs/06_glpi/
Manual:   docs/06_glpi/MANUAL_INTEGRACAO_GLPI.md

Proximos passos:
  cd $TARGET
  ./tools/glpi/glpi ticket get
  ./tools/glpi/bin/glpi-retro-scan

Assistente Python: python3 $KIT_ROOT/scripts/install_glpi.py --help
EOF
