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
# Preferir dotenv (~/.secrets/glpi.env); fallback legado GLPI-tokens.txt
if [[ -z "${GLPI_SECRETS_FILE:-}" ]]; then
  if [[ -f "${HOME}/.secrets/glpi.env" ]]; then
    GLPI_SECRETS_FILE="${HOME}/.secrets/glpi.env"
  else
    GLPI_SECRETS_FILE="${HOME}/.secrets/GLPI-tokens.txt"
  fi
fi
GLPI_PROJECT_FILE="${GLPI_PROJECT_FILE:-${REPO_ROOT}/.glpi/project.yaml}"
GLPI_INSTANCE_FILE="${GLPI_INSTANCE_FILE:-${REPO_ROOT}/.glpi/instance.yaml}"
GLPI_REQUIRE_APP_TOKEN="${GLPI_REQUIRE_APP_TOKEN:-}"
GLPI_SECRETS_FORMAT="${GLPI_SECRETS_FORMAT:-}"
# prod | homolog — CLI: --env=homolog | --homolog | export GLPI_ENV=homolog
GLPI_ENV="${GLPI_ENV:-}"

GLPI_CFG_TICKET_ID=""
GLPI_CFG_PROJECT_ID=""
GLPI_CFG_KEY=""
GLPI_CFG_PHASE_TEMPLATE=""
GLPI_CFG_PRESET="api-vscode-glpi"
GLPI_API_URL_PROD=""
GLPI_API_URL_HOMOLOG=""
GLPI_UI_URL=""
GLPI_USER_TOKEN_HOMOLOG="${GLPI_USER_TOKEN_HOMOLOG:-}"
GLPI_APP_TOKEN_HOMOLOG="${GLPI_APP_TOKEN_HOMOLOG:-}"

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

normalize_glpi_env_name() {
  local e
  e="$(echo "${1:-prod}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  case "$e" in
    hml|homo|homologacao|homologação|homolog) echo "homolog" ;;
    prod|production|"") echo "prod" ;;
    *) echo "$e" ;;
  esac
}

ensure_apirest_url() {
  local u="${1:-}"
  u="${u%/}"
  [[ -z "$u" ]] && { echo ""; return 0; }
  if [[ "$u" != */apirest.php ]]; then
    u="${u}/apirest.php"
  fi
  echo "$u"
}

# State local separado em homolog para nao misturar IDs com producao
glpi_state_file() {
  local pid="${1:-}"
  local suffix=""
  [[ "$(normalize_glpi_env_name "${GLPI_ENV:-prod}")" == "homolog" ]] && suffix=".homolog"
  echo "${REPO_ROOT}/.glpi/state-project-${pid}${suffix}.json"
}

glpi_env_banner() {
  local env_name api
  env_name="$(normalize_glpi_env_name "${GLPI_ENV:-prod}")"
  api="${GLPI_API_URL:-?}"
  if [[ "$env_name" == "homolog" ]]; then
    echo "╔══════════════════════════════════════════════════════════╗" >&2
    echo "║  GLPI ENV: HOMOLOG  (escritas NAO vao para producao)    ║" >&2
    echo "║  API: ${api}" >&2
    echo "╚══════════════════════════════════════════════════════════╝" >&2
  else
    echo "[glpi-env] prod → ${api}" >&2
  fi
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
  local secrets_file
  if [[ ! -f "${GLPI_INSTANCE_FILE}" ]]; then
    GLPI_CFG_PRESET="${GLPI_CFG_PRESET:-api-vscode-glpi}"
    GLPI_CFG_PHASE_TEMPLATE="${GLPI_CFG_PHASE_TEMPLATE:-corporate-phases}"
    return 0
  fi

  GLPI_CFG_PRESET="$(yaml_get "${GLPI_INSTANCE_FILE}" preset || true)"
  GLPI_CFG_PRESET="${GLPI_CFG_PRESET:-api-vscode-glpi}"

  local api_url ui_url req_app secrets_fmt map_file phase_tpl env_default api_prod api_hml
  api_url="$(yaml_get_nested "${GLPI_INSTANCE_FILE}" glpi api_url || true)"
  ui_url="$(yaml_get_nested "${GLPI_INSTANCE_FILE}" glpi ui_url || true)"
  req_app="$(yaml_get_nested "${GLPI_INSTANCE_FILE}" glpi require_app_token || true)"
  secrets_fmt="$(yaml_get_nested "${GLPI_INSTANCE_FILE}" secrets format || true)"
  secrets_file="$(yaml_get_nested "${GLPI_INSTANCE_FILE}" secrets file || true)"
  map_file="$(yaml_get_nested "${GLPI_INSTANCE_FILE}" states map_file || true)"
  phase_tpl="$(yaml_get_nested "${GLPI_INSTANCE_FILE}" workflow phase_template || true)"
  env_default="$(yaml_get "${GLPI_INSTANCE_FILE}" environment || true)"

  api_prod="$(awk '
    BEGIN{sec=""}
    /^environments:/ {top=1; next}
    top && /^[^ \t#]/ {top=0}
    top && /^[ \t]*prod:[ \t]*$/ {sec="prod"; next}
    top && /^[ \t]*homolog:[ \t]*$/ {sec="homolog"; next}
    top && sec!="" && /^[ \t]+[a-z_]+:/ {
      key=$1; sub(/:/,"",key); gsub(/^[ \t]+|[ \t]+$/,"",key)
      val=$0; sub(/^[ \t]*[^:]+:[ \t]*/,"",val); gsub(/["'\'']/,"",val); gsub(/^[ \t]+|[ \t]+$/,"",val)
      if (sec=="prod" && key=="api_url") print val
    }
  ' "${GLPI_INSTANCE_FILE}" | head -n1)"
  api_hml="$(awk '
    BEGIN{sec=""}
    /^environments:/ {top=1; next}
    top && /^[^ \t#]/ {top=0}
    top && /^[ \t]*prod:[ \t]*$/ {sec="prod"; next}
    top && /^[ \t]*homolog:[ \t]*$/ {sec="homolog"; next}
    top && sec!="" && /^[ \t]+[a-z_]+:/ {
      key=$1; sub(/:/,"",key); gsub(/^[ \t]+|[ \t]+$/,"",key)
      val=$0; sub(/^[ \t]*[^:]+:[ \t]*/,"",val); gsub(/["'\'']/,"",val); gsub(/^[ \t]+|[ \t]+$/,"",val)
      if (sec=="homolog" && key=="api_url") print val
    }
  ' "${GLPI_INSTANCE_FILE}" | head -n1)"

  [[ -n "$api_prod" ]] && GLPI_API_URL_PROD="$(ensure_apirest_url "$api_prod")"
  [[ -n "$api_hml" ]] && GLPI_API_URL_HOMOLOG="$(ensure_apirest_url "$api_hml")"
  [[ -n "$api_url" && -z "${GLPI_API_URL_PROD}" ]] && GLPI_API_URL_PROD="$(ensure_apirest_url "$api_url")"
  [[ -n "$ui_url" ]] && GLPI_UI_URL="$ui_url"

  if [[ -z "${GLPI_ENV}" && -n "$env_default" ]]; then
    GLPI_ENV="$(normalize_glpi_env_name "$env_default")"
  fi

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
  # Homolog: preferir project.homolog.yaml se existir
  local env_name pf
  env_name="$(normalize_glpi_env_name "${GLPI_ENV:-prod}")"
  pf="${GLPI_PROJECT_FILE}"
  if [[ "$env_name" == "homolog" && -f "${REPO_ROOT}/.glpi/project.homolog.yaml" ]]; then
    pf="${REPO_ROOT}/.glpi/project.homolog.yaml"
  fi
  if [[ -f "$pf" ]]; then
    GLPI_CFG_TICKET_ID="$(yaml_get "$pf" ticket_id || true)"
    GLPI_CFG_PROJECT_ID="$(yaml_get "$pf" project_id || true)"
    GLPI_CFG_KEY="$(yaml_get "$pf" key || true)"
    local pt
    pt="$(yaml_get "$pf" phase_template || true)"
    [[ -n "$pt" ]] && GLPI_CFG_PHASE_TEMPLATE="$pt"
    # Overrides opcionales: homolog.project_id / homolog.ticket_id no project.yaml principal
    if [[ "$env_name" == "homolog" && "$pf" == "${GLPI_PROJECT_FILE}" ]]; then
      local hp ht
      hp="$(yaml_get_nested "$pf" homolog project_id || true)"
      ht="$(yaml_get_nested "$pf" homolog ticket_id || true)"
      [[ -n "$hp" ]] && GLPI_CFG_PROJECT_ID="$hp"
      [[ -n "$ht" ]] && GLPI_CFG_TICKET_ID="$ht"
    fi
  fi
  GLPI_CFG_TICKET_ID="${GLPI_CFG_TICKET_ID:-}"
  GLPI_CFG_PROJECT_ID="${GLPI_CFG_PROJECT_ID:-}"
  GLPI_CFG_KEY="${GLPI_CFG_KEY:-}"
  GLPI_CFG_PHASE_TEMPLATE="${GLPI_CFG_PHASE_TEMPLATE:-corporate-phases}"
}

# Le secrets — formatos: dotenv|pmf|generic|env
load_secrets_file() {
  local file="${1:-$GLPI_SECRETS_FILE}"
  [[ -f "$file" ]] || return 1

  local line personal="" group="" url="" url_prod="" url_hml="" user="" app="" fmt="${GLPI_SECRETS_FORMAT:-}"
  local base
  base="$(basename "$file")"

  # Auto-detect formato
  if [[ -z "$fmt" ]]; then
    if [[ "$base" == *.env || "$base" == "glpi.env" ]]; then
      fmt="dotenv"
    else
      fmt="pmf"
    fi
  fi
  case "$fmt" in
    dotenv|envfile) fmt="dotenv" ;;
  esac

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line//$'\r'/}"
    [[ -z "$line" || "$line" =~ ^# ]] && continue

    case "$fmt" in
      dotenv)
        if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
          local k="${BASH_REMATCH[1]}" v="${BASH_REMATCH[2]}"
          v="${v%\"}"; v="${v#\"}"; v="${v%\'}"; v="${v#\'}"
          case "$k" in
            GLPI_USER_TOKEN|USER_TOKEN) user="$(echo -n "$v" | tr -d '[:space:]')" ;;
            GLPI_APP_TOKEN|APP_TOKEN) app="$(echo -n "$v" | tr -d '[:space:]')" ;;
            GLPI_USER_TOKEN_HOMOLOG) GLPI_USER_TOKEN_HOMOLOG="$(echo -n "$v" | tr -d '[:space:]')" ;;
            GLPI_APP_TOKEN_HOMOLOG) GLPI_APP_TOKEN_HOMOLOG="$(echo -n "$v" | tr -d '[:space:]')" ;;
            GLPI_API_URL_PROD) url_prod="$(ensure_apirest_url "$v")" ;;
            GLPI_API_URL_HOMOLOG) url_hml="$(ensure_apirest_url "$v")" ;;
            GLPI_API_URL|API_URL) url="$(ensure_apirest_url "$v")" ;;
            GLPI_ENV_DEFAULT)
              if [[ -z "${GLPI_ENV}" ]]; then
                GLPI_ENV="$(normalize_glpi_env_name "$v")"
              fi
              ;;
          esac
        fi
        ;;
      generic)
        if [[ "$line" =~ ^[Aa][Pp][Ii]_?[Uu][Rr][Ll]:[[:space:]]*(https?://[^[:space:]]+) ]]; then
          url="$(ensure_apirest_url "${BASH_REMATCH[1]}")"
        elif [[ "$line" =~ ^[Uu][Ss][Ee][Rr]_?[Tt][Oo][Kk][Ee][Nn]:[[:space:]]*(.+) ]]; then
          user="$(echo -n "${BASH_REMATCH[1]}" | tr -d '[:space:]')"
        elif [[ "$line" =~ ^[Aa][Pp][Pp]_?[Tt][Oo][Kk][Ee][Nn]:[[:space:]]*(.+) ]]; then
          app="$(echo -n "${BASH_REMATCH[1]}" | tr -d '[:space:]')"
        fi
        ;;
      env)
        ;;
      pmf|*)
        if [[ "$line" =~ [Uu][Rr][Ll].*[Aa][Pp][Ii].*[Hh][Oo][Mm][Oo][Ll] ]]; then
          if [[ "$line" =~ (https?://[^[:space:]]+) ]]; then
            url_hml="$(ensure_apirest_url "${BASH_REMATCH[1]}")"
          fi
        elif [[ "$line" =~ [Uu][Rr][Ll].*[Aa][Pp][Ii].*:[[:space:]]*(https?://[^[:space:]]+) ]]; then
          url_prod="$(ensure_apirest_url "${BASH_REMATCH[1]}")"
          url="$url_prod"
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

  [[ -n "$url_prod" ]] && GLPI_API_URL_PROD="$url_prod"
  [[ -n "$url_hml" ]] && GLPI_API_URL_HOMOLOG="$url_hml"
  [[ -n "$url" && -z "${GLPI_API_URL_PROD}" ]] && GLPI_API_URL_PROD="$url"

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
  if [[ "${GLPI_SECRETS_FORMAT:-}" != "env" ]]; then
    load_secrets_file || true
  fi

  GLPI_ENV="$(normalize_glpi_env_name "${GLPI_ENV:-prod}")"

  # Tokens especificos de homolog (se existirem)
  if [[ "${GLPI_ENV}" == "homolog" ]]; then
    [[ -n "${GLPI_USER_TOKEN_HOMOLOG:-}" ]] && GLPI_USER_TOKEN="$GLPI_USER_TOKEN_HOMOLOG"
    [[ -n "${GLPI_APP_TOKEN_HOMOLOG:-}" ]] && GLPI_APP_TOKEN="$GLPI_APP_TOKEN_HOMOLOG"
  fi

  # Seleciona URL conforme ambiente
  if [[ "${GLPI_ENV}" == "homolog" ]]; then
    if [[ -n "${GLPI_API_URL_HOMOLOG}" ]]; then
      GLPI_API_URL="$(ensure_apirest_url "$GLPI_API_URL_HOMOLOG")"
    elif [[ -n "${GLPI_API_URL}" && "${GLPI_API_URL}" == *homolog* ]]; then
      GLPI_API_URL="$(ensure_apirest_url "$GLPI_API_URL")"
    else
      die "GLPI_API_URL_HOMOLOG nao definido. Configure em ~/.secrets/glpi.env ou URL-API Homologacao no legado"
    fi
  else
    if [[ -z "${GLPI_API_URL}" || "${GLPI_API_URL}" == *homolog* ]]; then
      if [[ -n "${GLPI_API_URL_PROD}" ]]; then
        GLPI_API_URL="$(ensure_apirest_url "$GLPI_API_URL_PROD")"
      fi
    fi
    GLPI_API_URL="$(ensure_apirest_url "${GLPI_API_URL}")"
  fi

  GLPI_API_URL="${GLPI_API_URL%/}"
  glpi_env_banner

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
  # Sem App-Token: limpa o valor carregado do secrets (initSession nao envia o header)
  if [[ "$req" == "0" ]]; then
    GLPI_APP_TOKEN=""
  fi
  if [[ "$req" == "1" && -z "${GLPI_APP_TOKEN}" ]]; then
    die "GLPI_APP_TOKEN obrigatorio nesta instancia. Em homolog, registre o cliente API ou use GLPI_APP_TOKEN_HOMOLOG / GLPI_REQUIRE_APP_TOKEN=0"
  fi

  [[ -n "${GLPI_API_URL}" ]] || die \
    "GLPI_API_URL nao definido. Configure URL-API em ${GLPI_SECRETS_FILE} ou glpi.api_url em ${GLPI_INSTANCE_FILE}"
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

# Upload Document (multipart) + opcional vínculo Document_Item.
# Uso: glpi_document_upload_and_link <arquivo> <nome_doc> <itemtype> <items_id>
# Retorna JSON {documents_id, document_item_id?, message} via stdout.
glpi_document_upload_and_link() {
  local file="$1" doc_name="$2" itemtype="$3" items_id="$4"
  local base fname manifest resp doc_id link_payload link_resp link_id

  [[ -f "$file" ]] || die "arquivo nao encontrado: $file"
  case "$(basename "$file" | tr '[:upper:]' '[:lower:]')" in
    .env|.env.*|*token*|*secret*|*credential*|*password*)
      die "recusado: arquivo parece conter segredo ($(basename "$file"))"
      ;;
  esac

  [[ -n "${GLPI_SESSION_TOKEN}" ]] || die "sessao GLPI nao iniciada"
  [[ -n "$itemtype" && -n "$items_id" ]] || die "itemtype e items_id obrigatorios"

  base="$(basename "$file")"
  fname="${doc_name:-$base}"
  manifest="$(jq -nc \
    --arg name "$fname" \
    --arg fn "$base" \
    '{input: {name: $name, _filename: [$fn]}}')"

  local curl_args=(-sS -X POST)
  if [[ -n "${GLPI_APP_TOKEN}" ]]; then
    curl_args+=(-H "App-Token: ${GLPI_APP_TOKEN}")
  fi
  curl_args+=(
    -H "Session-Token: ${GLPI_SESSION_TOKEN}"
    -F "uploadManifest=${manifest};type=application/json"
    -F "filename[0]=@${file}"
  )

  resp="$(curl "${curl_args[@]}" "${GLPI_API_URL}/Document/")" || die "falha no upload Document (rede)"
  doc_id="$(echo "$resp" | jq -r 'if type=="object" then .id // empty elif type=="array" then .[0].id // empty else empty end')"
  [[ -n "$doc_id" && "$doc_id" != "null" ]] || die "upload Document falhou: $resp"

  link_payload="$(jq -nc \
    --argjson did "$doc_id" \
    --arg it "$itemtype" \
    --argjson iid "$items_id" \
    '{input: {documents_id: $did, itemtype: $it, items_id: $iid}}')"

  link_resp="$(echo "$link_payload" | glpi_curl POST "/Document_Item/")"
  link_id="$(echo "$link_resp" | jq -r 'if type=="object" then .id // empty elif type=="array" then .[0].id // empty else empty end')"
  [[ -n "$link_id" && "$link_id" != "null" ]] || link_id="null"

  jq -nc \
    --argjson documents_id "$doc_id" \
    --argjson document_item_id "$link_id" \
    --arg itemtype "$itemtype" \
    --argjson items_id "$items_id" \
    --arg file "$file" \
    --arg name "$fname" \
    --argjson upload "$resp" \
    --argjson link "$link_resp" \
    '{
      ok: true,
      documents_id: $documents_id,
      document_item_id: $document_item_id,
      itemtype: $itemtype,
      items_id: $items_id,
      file: $file,
      name: $name,
      upload: $upload,
      link: $link
    }'
}
