#!/usr/bin/env bash
# Biblioteca do CLI GLPI — nucleo generico + preset api-vscode-glpi (PMF)
set -euo pipefail

GLPI_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLPI_ROOT="$(cd "${GLPI_LIB_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${GLPI_ROOT}/../.." && pwd)"

GLPI_SESSION_TOKEN="${GLPI_SESSION_TOKEN:-}"
GLPI_API_URL="${GLPI_API_URL:-}"
GLPI_USER_TOKEN="${GLPI_USER_TOKEN:-}"
GLPI_APP_TOKEN="${GLPI_APP_TOKEN:-}"
GLPI_SECRETS_FILE="${GLPI_SECRETS_FILE:-${HOME}/.secrets/GLPI-tokens.txt}"
GLPI_PROJECT_FILE="${GLPI_PROJECT_FILE:-${REPO_ROOT}/.glpi/project.yaml}"
GLPI_INSTANCE_FILE="${GLPI_INSTANCE_FILE:-${REPO_ROOT}/.glpi/instance.yaml}"
GLPI_REQUIRE_APP_TOKEN="${GLPI_REQUIRE_APP_TOKEN:-}"
GLPI_SECRETS_FORMAT="${GLPI_SECRETS_FORMAT:-}"

GLPI_CFG_TICKET_ID=""
GLPI_CFG_PROJECT_ID=""
GLPI_CFG_KEY=""
GLPI_CFG_PHASE_TEMPLATE=""
GLPI_CFG_PRESET="api-vscode-glpi"

die() {
  echo "erro: $*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "comando obrigatorio ausente: $1"
}

expand_path() {
  local p="${1/#\~/$HOME}"
  echo "$p"
}

# Extrai valor simples de YAML chave: valor (sem parser completo)
yaml_get() {
  local file="$1" key="$2"
  [[ -f "$file" ]] || return 1
  sed -n "s/^[[:space:]]*${key}:[[:space:]]*//p" "$file" | head -n1 | tr -d '"' | tr -d "'"
}

yaml_get_nested() {
  # yaml_get_nested file section key  — leitura simples de bloco glpi:/secrets:
  local file="$1" section="$2" key="$3"
  [[ -f "$file" ]] || return 1
  awk -v section="$section" -v key="$key" '
    function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    $0 ~ "^[ \t]*" section ":[ \t]*$" { insec=1; next }
    insec && $0 ~ /^[^ \t]/ { insec=0 }
    insec && $0 ~ "^[ \t]*" key ":[ \t]*" {
      sub(/^[ \t]*[^ \t]+:[ \t]*/, "", $0)
      gsub(/^["'\'' ]+|["'\'' ]+$/, "", $0)
      print trim($0)
      exit
    }
  ' "$file"
}

load_instance_config() {
  local preset_dir secrets_file
  if [[ ! -f "${GLPI_INSTANCE_FILE}" ]]; then
    GLPI_CFG_PRESET="${GLPI_CFG_PRESET:-api-vscode-glpi}"
    GLPI_CFG_PHASE_TEMPLATE="${GLPI_CFG_PHASE_TEMPLATE:-corporate-phases}"
    return 0
  fi

  GLPI_CFG_PRESET="$(yaml_get "${GLPI_INSTANCE_FILE}" preset || true)"
  GLPI_CFG_PRESET="${GLPI_CFG_PRESET:-api-vscode-glpi}"

  local api_url ui_url req_app secrets_fmt map_file phase_tpl
  api_url="$(yaml_get_nested "${GLPI_INSTANCE_FILE}" glpi api_url || true)"
  ui_url="$(yaml_get_nested "${GLPI_INSTANCE_FILE}" glpi ui_url || true)"
  req_app="$(yaml_get_nested "${GLPI_INSTANCE_FILE}" glpi require_app_token || true)"
  secrets_fmt="$(yaml_get_nested "${GLPI_INSTANCE_FILE}" secrets format || true)"
  secrets_file="$(yaml_get_nested "${GLPI_INSTANCE_FILE}" secrets file || true)"
  map_file="$(yaml_get_nested "${GLPI_INSTANCE_FILE}" states map_file || true)"
  phase_tpl="$(yaml_get_nested "${GLPI_INSTANCE_FILE}" workflow phase_template || true)"

  [[ -n "$api_url" && -z "${GLPI_API_URL}" ]] && GLPI_API_URL="$api_url"
  [[ -n "$secrets_file" ]] && GLPI_SECRETS_FILE="$(expand_path "$secrets_file")"
  [[ -n "$secrets_fmt" ]] && GLPI_SECRETS_FORMAT="$secrets_fmt"
  [[ -n "$map_file" ]] && GLPI_STATES_FILE="${REPO_ROOT}/$(echo "$map_file" | sed 's|^\./||')"
  [[ -n "$phase_tpl" ]] && GLPI_CFG_PHASE_TEMPLATE="$phase_tpl"

  if [[ -n "$req_app" ]]; then
    case "$(echo "$req_app" | tr '[:upper:]' '[:lower:]')" in
      true|1|yes) GLPI_REQUIRE_APP_TOKEN="1" ;;
      false|0|no) GLPI_REQUIRE_APP_TOKEN="0" ;;
    esac
  fi
}

load_project_config() {
  load_instance_config
  if [[ -f "${GLPI_PROJECT_FILE}" ]]; then
    GLPI_CFG_TICKET_ID="$(yaml_get "${GLPI_PROJECT_FILE}" ticket_id || true)"
    GLPI_CFG_PROJECT_ID="$(yaml_get "${GLPI_PROJECT_FILE}" project_id || true)"
    GLPI_CFG_KEY="$(yaml_get "${GLPI_PROJECT_FILE}" key || true)"
    local pt
    pt="$(yaml_get "${GLPI_PROJECT_FILE}" phase_template || true)"
    [[ -n "$pt" ]] && GLPI_CFG_PHASE_TEMPLATE="$pt"
  fi
  GLPI_CFG_TICKET_ID="${GLPI_CFG_TICKET_ID:-}"
  GLPI_CFG_PROJECT_ID="${GLPI_CFG_PROJECT_ID:-}"
  GLPI_CFG_KEY="${GLPI_CFG_KEY:-}"
  GLPI_CFG_PHASE_TEMPLATE="${GLPI_CFG_PHASE_TEMPLATE:-corporate-phases}"
}

# Le secrets — formatos: pmf | generic | env (env = so variaveis, ignora arquivo parcial)
load_secrets_file() {
  local file="${1:-$GLPI_SECRETS_FILE}"
  [[ -f "$file" ]] || return 1

  local line personal="" group="" url="" user="" app="" fmt="${GLPI_SECRETS_FORMAT:-pmf}"

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line//$'\r'/}"
    [[ -z "$line" || "$line" =~ ^# ]] && continue

    case "$fmt" in
      generic)
        if [[ "$line" =~ ^[Aa][Pp][Ii]_?[Uu][Rr][Ll]:[[:space:]]*(https?://[^[:space:]]+) ]]; then
          url="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^[Uu][Ss][Ee][Rr]_?[Tt][Oo][Kk][Ee][Nn]:[[:space:]]*(.+) ]]; then
          user="$(echo -n "${BASH_REMATCH[1]}" | tr -d '[:space:]')"
        elif [[ "$line" =~ ^[Aa][Pp][Pp]_?[Tt][Oo][Kk][Ee][Nn]:[[:space:]]*(.+) ]]; then
          app="$(echo -n "${BASH_REMATCH[1]}" | tr -d '[:space:]')"
        fi
        ;;
      env)
        ;;
      pmf|*)
        if [[ "$line" =~ [Uu][Rr][Ll].*[Aa][Pp][Ii].*:[[:space:]]*(https?://[^[:space:]]+) ]]; then
          url="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ [Pp]essoal[[:space:]]+API-GLPI:[[:space:]]*(.+) ]]; then
          personal="$(echo -n "${BASH_REMATCH[1]}" | tr -d '[:space:]')"
        elif [[ "$line" =~ [Gg]rupo[[:space:]]+API-GLPI:[[:space:]]*(.+) ]]; then
          group="$(echo -n "${BASH_REMATCH[1]}" | tr -d '[:space:]')"
        elif [[ "$line" =~ ^[Uu][Ss][Ee][Rr]_?[Tt][Oo][Kk][Ee][Nn]:[[:space:]]*(.+) ]]; then
          user="$(echo -n "${BASH_REMATCH[1]}" | tr -d '[:space:]')"
        elif [[ "$line" =~ ^[Aa][Pp][Pp]_?[Tt][Oo][Kk][Ee][Nn]:[[:space:]]*(.+) ]]; then
          app="$(echo -n "${BASH_REMATCH[1]}" | tr -d '[:space:]')"
        fi
        ;;
    esac
  done <"$file"

  [[ -z "${GLPI_API_URL}" && -n "$url" ]] && GLPI_API_URL="$url"

  if [[ -z "${GLPI_USER_TOKEN}" ]]; then
    if [[ -n "$personal" ]]; then
      GLPI_USER_TOKEN="$personal"
    elif [[ -n "$user" ]]; then
      GLPI_USER_TOKEN="$user"
    fi
  fi

  if [[ -z "${GLPI_APP_TOKEN}" ]]; then
    if [[ -n "$group" ]]; then
      GLPI_APP_TOKEN="$group"
    elif [[ -n "$app" ]]; then
      GLPI_APP_TOKEN="$app"
    fi
  fi
}

load_credentials() {
  load_project_config
  if [[ "${GLPI_SECRETS_FORMAT:-env}" != "env" ]]; then
    load_secrets_file || true
  fi

  GLPI_API_URL="${GLPI_API_URL%/}"

  [[ -n "${GLPI_USER_TOKEN}" ]] || die \
    "GLPI_USER_TOKEN nao definido. Exporte GLPI_USER_TOKEN ou configure secrets em ${GLPI_SECRETS_FILE}"

  local req="${GLPI_REQUIRE_APP_TOKEN:-}"
  if [[ -z "$req" ]]; then
    if [[ "${GLPI_CFG_PRESET:-api-vscode-glpi}" == "generic" ]]; then
      req="0"
    else
      req="1"
    fi
  fi
  if [[ "$req" == "1" && -z "${GLPI_APP_TOKEN}" ]]; then
    die "GLPI_APP_TOKEN obrigatorio nesta instancia. Configure Grupo/APP_TOKEN em ${GLPI_SECRETS_FILE} ou require_app_token: false em .glpi/instance.yaml"
  fi

  [[ -n "${GLPI_API_URL}" ]] || die \
    "GLPI_API_URL nao definido. Configure URL-API/API_URL em ${GLPI_SECRETS_FILE} ou glpi.api_url em ${GLPI_INSTANCE_FILE}"
}

glpi_curl_headers_session() {
  local args=(-H "Content-Type: application/json" -H "Session-Token: ${GLPI_SESSION_TOKEN}")
  if [[ -n "${GLPI_APP_TOKEN}" ]]; then
    args+=(-H "App-Token: ${GLPI_APP_TOKEN}")
  fi
  printf '%s\0' "${args[@]}"
}

glpi_curl() {
  local method="$1" path="$2"
  shift 2
  local url="${GLPI_API_URL}${path}"
  local args=(-sS -X "$method" -H "Content-Type: application/json")

  if [[ -n "${GLPI_APP_TOKEN}" ]]; then
    args+=(-H "App-Token: ${GLPI_APP_TOKEN}")
  fi

  if [[ "$path" == "/initSession" || "$path" == "/initSession/" ]]; then
    args+=(-H "Authorization: user_token ${GLPI_USER_TOKEN}")
  else
    [[ -n "${GLPI_SESSION_TOKEN}" ]] || die "sessao GLPI nao iniciada"
    args+=(-H "Session-Token: ${GLPI_SESSION_TOKEN}")
  fi

  case "$method" in
    POST|PUT|PATCH)
      args+=(-d @-)
      ;;
  esac

  curl "${args[@]}" "$@" "$url"
}

glpi_init_session() {
  load_credentials
  need_cmd curl
  need_cmd jq

  local resp http_code curl_args=(-sS -w '\n%{http_code}' -X GET \
    -H "Content-Type: application/json" \
    -H "Authorization: user_token ${GLPI_USER_TOKEN}")

  if [[ -n "${GLPI_APP_TOKEN}" ]]; then
    curl_args+=(-H "App-Token: ${GLPI_APP_TOKEN}")
  fi

  resp="$(curl "${curl_args[@]}" "${GLPI_API_URL}/initSession/")" || die "falha em initSession (rede)"
  http_code="$(echo "$resp" | tail -n1)"
  resp="$(echo "$resp" | sed '$d')"

  if echo "$resp" | jq -e 'type=="object" and (.session_token|type=="string")' >/dev/null 2>&1; then
    GLPI_SESSION_TOKEN="$(echo "$resp" | jq -r '.session_token')"
    return 0
  fi
  die "initSession HTTP ${http_code}: $resp"
}

glpi_kill_session() {
  if [[ -n "${GLPI_SESSION_TOKEN:-}" ]]; then
    glpi_curl GET "/killSession/" >/dev/null 2>&1 || true
    GLPI_SESSION_TOKEN=""
  fi
}

with_session() {
  glpi_init_session
  trap 'glpi_kill_session' EXIT
  "$@"
}

json_escape() {
  jq -Rn --arg s "$1" '$s'
}

resolve_ticket_id() {
  local id="${1:-}"
  if [[ -z "$id" || "$id" == "-" ]]; then
    load_project_config
    id="${GLPI_CFG_TICKET_ID}"
  fi
  [[ -n "$id" && "$id" != "0" ]] || die "ticket_id nao informado e ausente em .glpi/project.yaml"
  echo "$id"
}

resolve_project_id() {
  local id="${1:-}"
  if [[ -z "$id" || "$id" == "-" ]]; then
    load_project_config
    id="${GLPI_CFG_PROJECT_ID}"
  fi
  [[ -n "$id" && "$id" != "0" ]] || die "project_id nao informado e ausente em .glpi/project.yaml"
  echo "$id"
}
