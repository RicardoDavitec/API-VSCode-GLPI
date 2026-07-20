#!/usr/bin/env bash
# Biblioteca do CLI GLPI deste repositorio (samu-operacional / PMF)
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

die() {
  echo "erro: $*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "comando obrigatorio ausente: $1"
}

# Extrai valor simples de YAML chave: valor (sem parser completo)
yaml_get() {
  local file="$1" key="$2"
  [[ -f "$file" ]] || return 1
  sed -n "s/^[[:space:]]*${key}:[[:space:]]*//p" "$file" | head -n1 | tr -d '"' | tr -d "'"
}

load_project_config() {
  if [[ -f "${GLPI_PROJECT_FILE}" ]]; then
    GLPI_CFG_TICKET_ID="$(yaml_get "${GLPI_PROJECT_FILE}" ticket_id || true)"
    GLPI_CFG_PROJECT_ID="$(yaml_get "${GLPI_PROJECT_FILE}" project_id || true)"
    GLPI_CFG_KEY="$(yaml_get "${GLPI_PROJECT_FILE}" key || true)"
    GLPI_CFG_PHASE_TEMPLATE="$(yaml_get "${GLPI_PROJECT_FILE}" phase_template || true)"
  fi
  GLPI_CFG_TICKET_ID="${GLPI_CFG_TICKET_ID:-}"
  GLPI_CFG_PROJECT_ID="${GLPI_CFG_PROJECT_ID:-}"
  GLPI_CFG_KEY="${GLPI_CFG_KEY:-}"
  GLPI_CFG_PHASE_TEMPLATE="${GLPI_CFG_PHASE_TEMPLATE:-corporate-phases}"
}

# Lê tokens do arquivo ~/.secrets/GLPI-tokens.txt
# Convencao PMF validada na API:
#   Pessoal API-GLPI → user_token
#   Grupo   API-GLPI → App-Token (cliente API)
load_secrets_file() {
  local file="${1:-$GLPI_SECRETS_FILE}"
  [[ -f "$file" ]] || return 1

  local line personal="" group="" url=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line//$'\r'/}"
    [[ -z "$line" || "$line" =~ ^# ]] && continue

    if [[ "$line" =~ [Uu][Rr][Ll].*[Aa][Pp][Ii].*:[[:space:]]*(https?://[^[:space:]]+) ]]; then
      url="${BASH_REMATCH[1]}"
      continue
    fi
    if [[ "$line" =~ [Pp]essoal[[:space:]]+API-GLPI:[[:space:]]*(.+) ]]; then
      personal="$(echo -n "${BASH_REMATCH[1]}" | tr -d '[:space:]')"
      continue
    fi
    if [[ "$line" =~ [Gg]rupo[[:space:]]+API-GLPI:[[:space:]]*(.+) ]]; then
      group="$(echo -n "${BASH_REMATCH[1]}" | tr -d '[:space:]')"
      continue
    fi
  done <"$file"

  if [[ -z "${GLPI_API_URL}" && -n "$url" ]]; then
    GLPI_API_URL="$url"
  fi

  # user_token = pessoal (obrigatorio na instancia atual)
  if [[ -z "${GLPI_USER_TOKEN}" && -n "$personal" ]]; then
    GLPI_USER_TOKEN="$personal"
  fi

  # App-Token = grupo (obrigatorio — ERROR_APP_TOKEN_PARAMETERS_MISSING sem ele)
  if [[ -z "${GLPI_APP_TOKEN}" && -n "$group" ]]; then
    GLPI_APP_TOKEN="$group"
  fi
}

load_credentials() {
  load_project_config
  load_secrets_file || true

  GLPI_API_URL="${GLPI_API_URL:-https://suporte.franca.sp.gov.br/apirest.php}"
  # remove barra final
  GLPI_API_URL="${GLPI_API_URL%/}"

  [[ -n "${GLPI_USER_TOKEN}" ]] || die \
    "GLPI_USER_TOKEN nao definido. Exporte a variavel ou configure Pessoal API-GLPI em ${GLPI_SECRETS_FILE}"
  [[ -n "${GLPI_APP_TOKEN}" ]] || die \
    "GLPI_APP_TOKEN nao definido. Exporte a variavel ou configure Grupo API-GLPI em ${GLPI_SECRETS_FILE}"
}

glpi_headers_auth() {
  local args=(-H "Content-Type: application/json" -H "Authorization: user_token ${GLPI_USER_TOKEN}")
  if [[ -n "${GLPI_APP_TOKEN}" ]]; then
    args+=(-H "App-Token: ${GLPI_APP_TOKEN}")
  fi
  printf '%s\0' "${args[@]}"
}

glpi_curl() {
  # uso: glpi_curl METHOD PATH [curl extras...]  — body via stdin se METHOD POST/PUT/PATCH
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

  local resp http_code
  resp="$(curl -sS -w '\n%{http_code}' -X GET \
    -H "Content-Type: application/json" \
    -H "Authorization: user_token ${GLPI_USER_TOKEN}" \
    -H "App-Token: ${GLPI_APP_TOKEN}" \
    "${GLPI_API_URL}/initSession/")" || die "falha em initSession (rede)"
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
  [[ -n "$id" ]] || die "ticket_id nao informado e ausente em .glpi/project.yaml"
  echo "$id"
}

resolve_project_id() {
  local id="${1:-}"
  if [[ -z "$id" || "$id" == "-" ]]; then
    load_project_config
    id="${GLPI_CFG_PROJECT_ID}"
  fi
  [[ -n "$id" ]] || die "project_id nao informado e ausente em .glpi/project.yaml"
  echo "$id"
}
