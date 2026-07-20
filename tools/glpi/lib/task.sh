#!/usr/bin/env bash
# Helpers P0 — ProjectTask create/patch/upsert
# shellcheck shell=bash

GLPI_STATES_FILE="${GLPI_STATES_FILE:-${REPO_ROOT}/.glpi/maps/states.json}"

resolve_state_id() {
  # resolve_state_id <alias|id|trecho-do-nome>
  local raw="${1:-}"
  [[ -n "$raw" ]] || return 1

  if [[ "$raw" =~ ^[0-9]+$ ]]; then
    echo "$raw"
    return 0
  fi

  [[ -f "$GLPI_STATES_FILE" ]] || die "mapa de estados ausente: $GLPI_STATES_FILE"

  local key id
  key="$(echo "$raw" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g; s/__*/_/g; s/^_//; s/_$//')"

  id="$(jq -r --arg k "$key" '(.aliases[$k] // empty)|tostring' "$GLPI_STATES_FILE")"
  if [[ -n "$id" && "$id" != "null" && "$id" != "" ]]; then
    echo "$id"
    return 0
  fi

  # aliases com gepN
  if [[ "$key" =~ ^gep([0-9]) ]]; then
    id="$(jq -r --arg k "gep${BASH_REMATCH[1]}" '(.aliases[$k] // empty)|tostring' "$GLPI_STATES_FILE")"
    if [[ -n "$id" && "$id" != "null" && "$id" != "" ]]; then
      echo "$id"
      return 0
    fi
  fi

  id="$(jq -r --arg n "$raw" '
    .by_id | to_entries[]
    | select((.value|ascii_downcase) | contains($n|ascii_downcase))
    | .key
  ' "$GLPI_STATES_FILE" | head -n1)"
  if [[ -n "$id" && "$id" != "null" ]]; then
    echo "$id"
    return 0
  fi

  die "estado desconhecido: '$raw' (use id numerico ou alias em .glpi/maps/states.json)"
}

state_name_for_id() {
  local id="${1:-}"
  [[ -f "$GLPI_STATES_FILE" ]] || { echo "$id"; return 0; }
  jq -r --arg id "$id" '.by_id[$id] // $id' "$GLPI_STATES_FILE"
}

find_task_id_by_code() {
  local code="${1:-}" pid="${2:-}"
  local state_file
  load_project_config
  pid="${pid:-$GLPI_CFG_PROJECT_ID}"
  state_file="${REPO_ROOT}/.glpi/state-project-${pid}.json"
  [[ -f "$state_file" ]] || return 1
  # match case-insensitive
  jq -r --arg c "$code" '
    .tasks[] | select((.code|tostring|ascii_upcase) == ($c|ascii_upcase)) | .id
  ' "$state_file" | head -n1
}

find_task_id_by_name() {
  local name="${1:-}" pid="${2:-}"
  local state_file
  load_project_config
  pid="${pid:-$GLPI_CFG_PROJECT_ID}"
  state_file="${REPO_ROOT}/.glpi/state-project-${pid}.json"
  [[ -f "$state_file" ]] || return 1
  jq -r --arg n "$name" '.tasks[] | select(.name==$n) | .id' "$state_file" | head -n1
}

append_task_to_state() {
  local pid="$1" tid="$2" name="$3" code="${4:-}" kind="${5:-}" parent_code="${6:-}" parent_id="${7:-}"
  local state_file="${REPO_ROOT}/.glpi/state-project-${pid}.json"
  local tmp
  if [[ ! -f "$state_file" ]]; then
    jq -n --argjson pid "$pid" --argjson id "$tid" --arg name "$name" --arg code "$code" \
      --arg kind "$kind" --arg parent_code "$parent_code" --arg parent_id "$parent_id" \
      --arg at "$(date -Iseconds)" \
      '{
        project_id:$pid, template:"manual", hierarchy:"S=phase parent / P=item child",
        updated_at:$at,
        tasks:[{
          id:$id, name:$name, code:$code, kind:$kind,
          parent_code: (if $parent_code=="" then null else $parent_code end),
          parent_id: (if $parent_id=="" then null else ($parent_id|tonumber) end)
        }]
      }' >"$state_file"
    return 0
  fi
  tmp="$(mktemp)"
  jq --argjson id "$tid" --arg name "$name" --arg code "$code" --arg kind "$kind" \
    --arg parent_code "$parent_code" --arg parent_id "$parent_id" --arg at "$(date -Iseconds)" '
    .updated_at = $at |
    .hierarchy = (.hierarchy // "S=phase parent / P=item child") |
    if ([.tasks[].id] | index($id)) then
      .tasks = [.tasks[] | if .id==$id then
        . + {
          name: (if $name=="" then .name else $name end),
          code: (if $code=="" then .code else $code end),
          kind: (if $kind=="" then .kind else $kind end),
          parent_code: (if $parent_code=="" then .parent_code else $parent_code end),
          parent_id: (if $parent_id=="" then .parent_id else ($parent_id|tonumber) end)
        }
      else . end]
    else
      .tasks += [{
        id:$id, name:$name, code:$code,
        kind: (if $kind=="" then null else $kind end),
        parent_code: (if $parent_code=="" then null else $parent_code end),
        parent_id: (if $parent_id=="" then null else ($parent_id|tonumber) end)
      }]
    end
  ' "$state_file" >"$tmp" && mv "$tmp" "$state_file"
}
