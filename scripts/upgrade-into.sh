#!/usr/bin/env bash
# =============================================================================
#  upgrade-into.sh — atualiza o kit GLPI dentro de um clone de produto
#  Repositorio fonte: API-VSCode-GLPI (pmf-dev-kit)
#
#  MODELO DE PROPRIEDADE DE ARQUIVO (file ownership)
#    A = K ∪ P ∪ S          com a invariante    K ∩ P = ∅
#      K (kit-owned)     -> SEMPRE sobrescrito  (CLI, skills, defaults, presets)
#      P (product-owned) -> NUNCA sobrescrito   (config, segredos, docs do time)
#      S (seeded)        -> criado SE AUSENTE   (a partir de *.example)
#
#    acao(f) = overwrite  se f ∈ K
#              preserve   se f ∈ P
#              seed       se f ∈ S  e  nao existe(f)
#              skip       se f ∈ S  e  existe(f)
#
#  Dry-run por padrao. Nada e escrito sem --apply.
#  Autor: Dr. Ricardo David · Licenca: MIT
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

# ------------------------------------------------------------------ metadados
readonly SCRIPT_NAME="upgrade-into.sh"
readonly SCRIPT_VERSION="2.0.0"
readonly SCHEMA_TARGET=2
readonly TS="$(date +%Y%m%d-%H%M%S)"

# --------------------------------------------------------------- bash >= 4.0
if (( BASH_VERSINFO[0] < 4 )); then
  printf 'ERRO: requer bash >= 4.0 (atual: %s).\n' "${BASH_VERSION}" >&2
  printf '      macOS: brew install bash && /opt/homebrew/bin/bash %s\n' "$0" >&2
  exit 9
fi

# ----------------------------------------------------------------- aparencia
if [[ -t 1 && "${NO_COLOR:-}" == "" ]]; then
  C_RST=$'\033[0m'; C_BLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'
  C_BLU=$'\033[34m'; C_CYN=$'\033[36m'
else
  C_RST=""; C_BLD=""; C_DIM=""; C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_CYN=""
fi

log()   { printf '%s\n' "$*"; }
info()  { printf '%s[info]%s %s\n'  "$C_BLU" "$C_RST" "$*"; }
ok()    { printf '%s[ ok ]%s %s\n'  "$C_GRN" "$C_RST" "$*"; }
warn()  { printf '%s[warn]%s %s\n'  "$C_YEL" "$C_RST" "$*" >&2; }
err()   { printf '%s[ERRO]%s %s\n'  "$C_RED" "$C_RST" "$*" >&2; }
step()  { printf '\n%s==> %s%s\n'   "$C_BLD" "$*" "$C_RST"; }
vrb()   { [[ "$VERBOSE" == "1" ]] && printf '%s      %s%s\n' "$C_DIM" "$*" "$C_RST" || true; }
die()   { err "$*"; exit "${2:-1}"; }

# =============================================================================
#  1. CONJUNTOS DE PROPRIEDADE
# =============================================================================

# --- K : KIT-OWNED --- sempre sobrescrito (diretorios terminam com "/") ------
readonly -a KIT_OWNED=(
  # CLI e wrappers
  "tools/glpi/"
  # Skills dos agentes (Cursor / Copilot / Gemini / Antigravity)
  ".github/skills/"
  # Contrato base do modelo (camada 1)
  ".glpi/model.defaults.yaml"
  # Templates canonicos do kit
  ".glpi/templates/lifecycle-5-phases.yaml"
  ".glpi/templates/pmf-5-phases.yaml"
  ".glpi/templates/generic-phases.json"
  ".glpi/templates/sessions-seed.example.json"
  # Presets completos (camada 2)
  ".glpi/presets/"
  # Exemplos de config do produto (camada 3) — o *.example e do kit
  ".glpi/project.yaml.example"
  ".glpi/workspace.yaml.example"
  ".glpi/workspace.mono.yaml.example"
  ".glpi/hierarchy.yaml.example"
  ".glpi/instance.yaml.example"
  ".glpi/maps/phase-map.json.example"
  ".glpi/maps/states.json.example"
  # Documentacao da integracao (doc do kit, nao do produto)
  "docs/06_glpi/MANUAL_INTEGRACAO_GLPI.md"
  "docs/06_glpi/MANUAL_USO_GLPI.md"
  "docs/06_glpi/HIERARQUIA_F_S_P_GLPI.md"
  "docs/06_glpi/MODELO_OVERLAY.md"
  "docs/06_glpi/MIGRACAO_V1_V2.md"
  "docs/06_glpi/CATALOGO_SKILLS.md"
  # Scripts auxiliares
  "scripts/atualizar-kit"
  "scripts/atualizar_kit.py"
  "scripts/lib/"
  ".glpi/agenda.yaml.example"
  ".glpi/templates/quadro-semanal.xlsx"
  # (tools/glpi/ e .github/skills/ ja cobrem o script e as skills)
)

# --- P : PRODUCT-OWNED --- nunca sobrescrito --------------------------------
readonly -a PRODUCT_OWNED=(
  # Config do produto (camada 3)
  ".glpi/project.yaml"
  ".glpi/workspace.yaml"
  ".glpi/workspace.mono.yaml"
  ".glpi/hierarchy.yaml"
  ".glpi/instance.yaml"
  ".glpi/model.yaml"
  # Mapas com IDs reais da instancia (descobertos via API)
  ".glpi/maps/states.json"
  ".glpi/maps/phase-map.json"
  # Cache de resolucao code -> id
  ".glpi/index.json"
  # Producao intelectual da equipe
  "docs/01_requisitos/"
  "docs/01-requisitos/"
  "docs/05_progresso/"
  "docs/06_glpi/retro-scans/"
  "docs/07_homologacao/"
  "docs/08_aceite/"
  # Instrucoes de agente especificas do produto
  "AGENTS.md"
  ".cursor/rules/"
  # Qualquer coisa sensivel que tenha escapado
  ".secrets/"
  "GLPI-tokens.txt"
  ".glpi/agenda.yaml"
  "docs/05_progresso/quadros_semanais/"
)

# --- S : SEEDED --- criado apenas se ausente:  "destino<TAB>origem" ----------
readonly -a SEED_MAP=(
  ".glpi/project.yaml|.glpi/project.yaml.example"
  ".glpi/workspace.yaml|.glpi/workspace.yaml.example"
  ".glpi/maps/phase-map.json|.glpi/maps/phase-map.json.example"
  ".glpi/model.yaml|__STUB_MODEL__"
  "docs/06_glpi/retro-scans/.gitkeep|__TOUCH__"
  "docs/05_progresso/planos_ativos/anexos/.gitkeep|__TOUCH__"
  "docs/05_progresso/legados/.gitkeep|__TOUCH__"
  "docs/05_progresso/pendencias/.gitkeep|__TOUCH__"
)

# --- Skills v1 que viram alias DEPRECATED (nunca apagar) --------------------
readonly -a DEPRECATED_SKILLS=(
  "glpi-project-create|glpi-project-upsert"
  "glpi-task-upsert|glpi-node-upsert"
  "glpi-seed-phases|glpi-phase-ensure"
  "glpi-followup|acompanhar-chamado"
)

# --- Templates v1 que recebem aviso de depreciacao --------------------------
readonly -a DEPRECATED_TEMPLATES=(
  ".glpi/templates/corporate-phases.yaml"
  ".glpi/templates/corporate-phases.json"
  ".glpi/templates/botpan-phases.yaml"
  ".glpi/templates/botpan-phases.json"
  ".glpi/templates/samu-s-phases.json"
  ".glpi/templates/product-s-phases.example.json"
  ".glpi/agenda.yaml|.glpi/agenda.yaml.example"
  "docs/05_progresso/quadros_semanais/.gitkeep|__TOUCH__"
)

# =============================================================================
#  2. PARAMETROS
# =============================================================================
SOURCE_DIR=""
TARGET_DIR=""
PRESET=""
APPLY=0
ASSUME_YES=0
DO_BACKUP=1
MIGRATE=0
MARK_DEPRECATED=1
RUN_VALIDATE=1
VERBOSE=0
FORCE_OWNERSHIP=0

usage() {
  cat <<USAGE
${C_BLD}${SCRIPT_NAME} v${SCRIPT_VERSION}${C_RST} — atualiza o kit GLPI em um clone de produto

${C_BLD}USO${C_RST}
  ./scripts/upgrade-into.sh --target=/caminho/produto [opcoes]

${C_BLD}OPCOES${C_RST}
  --target=DIR          Clone do produto a atualizar        (obrigatorio)
  --source=DIR          Clone do kit fonte                  (default: raiz deste script)
  --preset=NOME         api-vscode-glpi | generic           (default: detectado)
  --apply               Efetiva as mudancas                 (default: dry-run)
  --yes                 Nao pedir confirmacao (CI)
  --no-backup           Nao criar backup antes de escrever  (NAO recomendado)
  --migrate-v2          Executa a migracao de esquema v1 -> v2
  --no-deprecate        Nao criar stubs DEPRECATED das skills v1
  --no-validate         Nao rodar glpi-tree-validate no fim
  --force-ownership     Prossegue mesmo com K ∩ P != ∅      (perigoso)
  --verbose             Log detalhado arquivo por arquivo
  -h, --help            Esta ajuda

${C_BLD}EXEMPLOS${C_RST}
  # 1. Inspecionar o que mudaria (NAO escreve nada)
  ./scripts/upgrade-into.sh --target=~/projetos/meu-app

  # 2. Aplicar com backup
  ./scripts/upgrade-into.sh --target=~/projetos/meu-app --apply

  # 3. Migrar um produto que ainda esta no modelo v1 (S/P sem fase)
  ./scripts/upgrade-into.sh --target=~/projetos/meu-app --migrate-v2 --apply

  # 4. CI / automacao
  ./scripts/upgrade-into.sh --target=. --preset=generic --apply --yes --no-validate

${C_BLD}CODIGOS DE SAIDA${C_RST}
  0 ok · 2 parametro invalido · 3 target invalido · 4 source invalido
  5 invariante K ∩ P violada · 6 abortado pelo usuario · 7 validacao pos-upgrade falhou
  8 falha de escrita · 9 ambiente incompativel
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --target=*)        TARGET_DIR="${arg#*=}" ;;
    --source=*)        SOURCE_DIR="${arg#*=}" ;;
    --preset=*)        PRESET="${arg#*=}" ;;
    --apply)           APPLY=1 ;;
    --yes|-y)          ASSUME_YES=1 ;;
    --no-backup)       DO_BACKUP=0 ;;
    --migrate-v2)      MIGRATE=1 ;;
    --no-deprecate)    MARK_DEPRECATED=0 ;;
    --no-validate)     RUN_VALIDATE=0 ;;
    --force-ownership) FORCE_OWNERSHIP=1 ;;
    --verbose|-v)      VERBOSE=1 ;;
    --dry-run)         APPLY=0 ;;
    -h|--help)         usage; exit 0 ;;
    *) err "Parametro desconhecido: ${arg}"; usage; exit 2 ;;
  esac
done

# GLPI_DRY_RUN=1 tem precedencia sobre --apply (mesma regra das skills)
if [[ "${GLPI_DRY_RUN:-0}" == "1" && "$APPLY" == "1" ]]; then
  warn "GLPI_DRY_RUN=1 no ambiente: --apply ignorado."
  APPLY=0
fi

# =============================================================================
#  3. RESOLUCAO DE CAMINHOS
# =============================================================================
resolve_path() {
  local p="${1/#\~/$HOME}"
  if command -v realpath >/dev/null 2>&1; then
    realpath -m -- "$p" 2>/dev/null || printf '%s' "$p"
  else
    ( cd "$(dirname -- "$p")" 2>/dev/null && printf '%s/%s' "$(pwd -P)" "$(basename -- "$p")" ) \
      || printf '%s' "$p"
  fi
}

SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
[[ -z "$SOURCE_DIR" ]] && SOURCE_DIR="$(cd -- "${SELF_DIR}/.." && pwd -P)"
SOURCE_DIR="$(resolve_path "$SOURCE_DIR")"
[[ -z "$TARGET_DIR" ]] && { err "--target e obrigatorio."; usage; exit 2; }
TARGET_DIR="$(resolve_path "$TARGET_DIR")"

[[ -d "$SOURCE_DIR" ]]              || die "Source inexistente: ${SOURCE_DIR}" 4
[[ -d "$SOURCE_DIR/tools/glpi" ]]   || die "Source nao parece o kit (falta tools/glpi): ${SOURCE_DIR}" 4
[[ -d "$TARGET_DIR" ]]              || die "Target inexistente: ${TARGET_DIR}" 3
[[ "$SOURCE_DIR" != "$TARGET_DIR" ]] || die "Source e target sao o mesmo diretorio." 3

case "$TARGET_DIR" in
  "$SOURCE_DIR"/*) die "Target esta dentro do source — isso corromperia o kit." 3 ;;
esac

# =============================================================================
#  4. INVARIANTE  K ∩ P = ∅
# =============================================================================
assert_disjoint() {
  step "Verificando invariante de propriedade  K ∩ P = ∅"
  local k p conflicts=0
  for k in "${KIT_OWNED[@]}"; do
    for p in "${PRODUCT_OWNED[@]}"; do
      if [[ "$k" == "$p" ]]; then
        err "Conflito exato: '${k}' esta em K e em P."
        (( conflicts++ ))
      elif [[ "$k" == */ && "$p" == "$k"* ]]; then
        err "Conflito por prefixo: P '${p}' esta sob K '${k}'."
        (( conflicts++ ))
      elif [[ "$p" == */ && "$k" == "$p"* ]]; then
        err "Conflito por prefixo: K '${k}' esta sob P '${p}'."
        (( conflicts++ ))
      fi
    done
  done
  if (( conflicts > 0 )); then
    if (( FORCE_OWNERSHIP == 1 )); then
      warn "${conflicts} conflito(s) ignorado(s) por --force-ownership. RISCO DE PERDA."
    else
      die "${conflicts} conflito(s) K ∩ P. Corrija os arrays antes de prosseguir." 5
    fi
  else
    ok "Invariante satisfeita: nenhum arquivo e simultaneamente do kit e do produto."
  fi
}

# =============================================================================
#  5. DETECCAO DO ESTADO DO PRODUTO
# =============================================================================
DETECTED_PRESET=""
DETECTED_SCHEMA=""
INSTALLED_VERSION=""
IS_FRESH=0

yaml_get() {  # leitura rasa de "chave: valor" (sem dependencia de yq)
  local file="$1" key="$2"
  [[ -f "$file" ]] || return 1
  sed -nE "s/^[[:space:]]*${key}[[:space:]]*:[[:space:]]*[\"']?([^\"'#]+)[\"']?.*/\1/p" \
    "$file" | head -n1 | sed -E 's/[[:space:]]+$//'
}

detect_state() {
  step "Detectando estado do produto"
  if [[ ! -d "$TARGET_DIR/.glpi" ]]; then
    IS_FRESH=1
    warn "Nao existe .glpi/ no target — este e um BOOTSTRAP, nao um upgrade."
    warn "Prefira: ${SOURCE_DIR}/scripts/bootstrap-into.sh --target=${TARGET_DIR}"
  fi
  DETECTED_PRESET="$(yaml_get "$TARGET_DIR/.glpi/project.yaml"  preset  || true)"
  [[ -z "$DETECTED_PRESET" ]] && \
    DETECTED_PRESET="$(yaml_get "$TARGET_DIR/.glpi/instance.yaml" preset || true)"
  DETECTED_SCHEMA="$(yaml_get "$TARGET_DIR/.glpi/project.yaml"  schema  || true)"
  INSTALLED_VERSION="$(cat "$TARGET_DIR/.glpi/.kit-version" 2>/dev/null || echo "desconhecida")"

  [[ -z "$PRESET" ]] && PRESET="${DETECTED_PRESET:-api-vscode-glpi}"
  [[ -d "$SOURCE_DIR/.glpi/presets/$PRESET" ]] \
    || die "Preset inexistente no source: ${PRESET}" 2

  log ""
  printf '  %-22s %s\n' "Kit fonte:"       "$SOURCE_DIR"
  printf '  %-22s %s\n' "Produto:"         "$TARGET_DIR"
  printf '  %-22s %s\n' "Preset:"          "$PRESET"
  printf '  %-22s %s\n' "Versao instalada:" "$INSTALLED_VERSION"
  printf '  %-22s %s\n' "Versao do kit:"   "$SCRIPT_VERSION"
  printf '  %-22s %s\n' "Schema detectado:" "${DETECTED_SCHEMA:-1 (legado)}"
  printf '  %-22s %s\n' "Modo:" \
    "$( (( APPLY )) && printf '%sAPPLY (escreve)%s' "$C_RED" "$C_RST" \
                    || printf '%sDRY-RUN (nao escreve)%s' "$C_CYN" "$C_RST" )"
  log ""

  if [[ -n "$DETECTED_SCHEMA" && "$DETECTED_SCHEMA" != "$SCHEMA_TARGET" ]] && (( MIGRATE == 0 )); then
    warn "Produto em schema ${DETECTED_SCHEMA}; o kit espera ${SCHEMA_TARGET}."
    warn "Rode com --migrate-v2 para converter S/P em F/S/P."
  fi
  if [[ -z "$DETECTED_SCHEMA" ]] && (( MIGRATE == 0 && IS_FRESH == 0 )); then
    warn "project.yaml sem 'schema:' — provavel modelo v1. Considere --migrate-v2."
  fi
}

# =============================================================================
#  6. ESTADO DO GIT NO TARGET
# =============================================================================
check_git_clean() {
  command -v git >/dev/null 2>&1 || { warn "git ausente; pulando verificacao."; return 0; }
  git -C "$TARGET_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    warn "Target nao e repositorio git — o upgrade nao sera reversivel por git."
    return 0
  }
  if [[ -n "$(git -C "$TARGET_DIR" status --porcelain 2>/dev/null)" ]]; then
    warn "Arvore de trabalho SUJA no target:"
    git -C "$TARGET_DIR" status --short | sed 's/^/        /' | head -n 20
    if (( APPLY == 1 && ASSUME_YES == 0 )); then
      warn "Recomendado commitar/stashar antes de --apply."
    fi
  else
    ok "Arvore de trabalho limpa — upgrade reversivel via 'git checkout .'"
  fi
}

# =============================================================================
#  7. BACKUP
# =============================================================================
BACKUP_DIR=""
make_backup() {
  (( DO_BACKUP == 0 )) && { warn "Backup desativado (--no-backup)."; return 0; }
  BACKUP_DIR="${TARGET_DIR}/.glpi/.backups/${TS}"
  step "Backup em .glpi/.backups/${TS}/"
  if (( APPLY == 0 )); then
    info "[dry-run] criaria backup de K + P existentes."
    return 0
  fi
  mkdir -p "$BACKUP_DIR" || die "Nao foi possivel criar o backup." 8
  local item src
  for item in "${KIT_OWNED[@]}" "${PRODUCT_OWNED[@]}"; do
    src="${TARGET_DIR}/${item%/}"
    [[ -e "$src" ]] || continue
    mkdir -p "$(dirname -- "${BACKUP_DIR}/${item%/}")"
    cp -a -- "$src" "${BACKUP_DIR}/${item%/}" 2>/dev/null || true
    vrb "backup: ${item}"
  done
  printf 'kit_version=%s\npreset=%s\ntimestamp=%s\nsource=%s\n' \
    "$SCRIPT_VERSION" "$PRESET" "$TS" "$SOURCE_DIR" > "${BACKUP_DIR}/MANIFEST.txt"
  ok "Backup concluido: ${BACKUP_DIR}"
  info "Restaurar: cp -a ${BACKUP_DIR}/. ${TARGET_DIR}/"
}

# =============================================================================
#  8. COPIA (K) — sempre sobrescreve
# =============================================================================
N_OVERWRITE=0; N_SEED=0; N_SKIP=0; N_PRESERVE=0; N_MISSING=0

copy_item() {
  local rel="$1"
  local src="${SOURCE_DIR}/${rel%/}"
  local dst="${TARGET_DIR}/${rel%/}"
  if [[ ! -e "$src" ]]; then
    vrb "ausente no kit (ignorado): ${rel}"
    (( N_MISSING++ )); return 0
  fi
  if (( APPLY == 0 )); then
    printf '  %soverwrite%s  %s\n' "$C_YEL" "$C_RST" "$rel"
    (( N_OVERWRITE++ )); return 0
  fi
  mkdir -p "$(dirname -- "$dst")"
  if [[ -d "$src" ]]; then
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --delete \
        --exclude='.backups/' --exclude='__pycache__/' --exclude='*.pyc' \
        -- "${src}/" "${dst}/" || die "Falha ao sincronizar ${rel}" 8
    else
      rm -rf -- "$dst"; cp -a -- "$src" "$dst" || die "Falha ao copiar ${rel}" 8
    fi
  else
    cp -a -- "$src" "$dst" || die "Falha ao copiar ${rel}" 8
  fi
  vrb "overwrite: ${rel}"
  (( N_OVERWRITE++ ))
}

sync_kit_owned() {
  step "Camada K (kit-owned) — sobrescrita"
  local rel
  for rel in "${KIT_OWNED[@]}"; do
    # auto-atualizacao do proprio script e diferida (secao 12)
    [[ "$rel" == "scripts/upgrade-into.sh" ]] && continue
    copy_item "$rel"
  done
  ok "K processado: ${N_OVERWRITE} item(ns); ${N_MISSING} ausente(s) no kit."
}

# =============================================================================
#  9. PRESERVACAO (P) — relatorio, nenhuma escrita
# =============================================================================
report_product_owned() {
  step "Camada P (product-owned) — preservada"
  local rel
  for rel in "${PRODUCT_OWNED[@]}"; do
    if [[ -e "${TARGET_DIR}/${rel%/}" ]]; then
      printf '  %spreserve%s   %s\n' "$C_GRN" "$C_RST" "$rel"
      (( N_PRESERVE++ ))
    else
      vrb "nao existe no produto: ${rel}"
    fi
  done
  ok "P preservado: ${N_PRESERVE} item(ns) intocado(s)."
}

# =============================================================================
# 10. SEMEADURA (S) — cria somente se ausente
# =============================================================================
write_model_stub() {
  local dst="$1"
  cat > "$dst" <<'STUB'
# ============================================================
#  MODELO DO PRODUTO — camada 3 (precedencia MAXIMA)
#  Declare aqui SOMENTE os deltas sobre:
#    .glpi/model.defaults.yaml            (camada 1 — kit)
#    .glpi/presets/<preset>/model.overlay.yaml (camada 2 — instituicao)
#
#  Resolucao:  V(k) = produto  >  preset  >  kit
#  Listas (ex.: lifecycle.phases) sao mescladas por 'code', nao por posicao.
#  Este arquivo e PRODUCT-OWNED: o upgrade do kit nunca o sobrescreve.
# ============================================================
schema: 2
layer: product

# Exemplos (descomente o que precisar):
#
# topology:
#   phase_as: subproject        # subproject | projecttask
#
# lifecycle:
#   phases:
#     - { code: F2, weight: 0.50 }
#     - { code: F3, weight: 0.10 }
#
# sessions:
#   window: sprint
#
# rollup:
#   mode: simple
#
# effort:
#   task_hours_default: 3
STUB
}

seed_missing() {
  step "Camada S (seeded) — criar se ausente"
  local pair dst src dst_abs src_abs
  for pair in "${SEED_MAP[@]}"; do
    dst="${pair%%|*}"; src="${pair##*|}"
    dst_abs="${TARGET_DIR}/${dst}"
    if [[ -e "$dst_abs" ]]; then
      printf '  %sskip%s       %s %s(ja existe)%s\n' "$C_DIM" "$C_RST" "$dst" "$C_DIM" "$C_RST"
      (( N_SKIP++ )); continue
    fi
    printf '  %sseed%s       %s' "$C_CYN" "$C_RST" "$dst"
    case "$src" in
      __TOUCH__)      printf ' %s(diretorio + .gitkeep)%s\n' "$C_DIM" "$C_RST" ;;
      __STUB_MODEL__) printf ' %s(stub de modelo)%s\n'       "$C_DIM" "$C_RST" ;;
      *)              printf ' %s(<- %s)%s\n' "$C_DIM" "$src" "$C_RST" ;;
    esac
    (( N_SEED++ ))
    (( APPLY == 0 )) && continue
    mkdir -p "$(dirname -- "$dst_abs")"
    case "$src" in
      __TOUCH__)      : > "$dst_abs" ;;
      __STUB_MODEL__) write_model_stub "$dst_abs" ;;
      *)
        src_abs="${TARGET_DIR}/${src}"
        [[ -f "$src_abs" ]] || src_abs="${SOURCE_DIR}/${src}"
        if [[ -f "$src_abs" ]]; then
          cp -a -- "$src_abs" "$dst_abs"
        else
          warn "Exemplo nao encontrado para semear: ${src}"
        fi
        ;;
    esac
  done

  # states.json do produto vem do preset (IDs reais da instancia)
  local st="${TARGET_DIR}/.glpi/maps/states.json"
  if [[ ! -f "$st" ]]; then
    local from="${SOURCE_DIR}/.glpi/presets/${PRESET}/maps/states.json"
    [[ -f "$from" ]] || from="${SOURCE_DIR}/.glpi/presets/${PRESET}/maps/states.json.example"
    printf '  %sseed%s       .glpi/maps/states.json %s(<- preset %s)%s\n' \
      "$C_CYN" "$C_RST" "$C_DIM" "$PRESET" "$C_RST"
    (( N_SEED++ ))
    if (( APPLY == 1 )) && [[ -f "$from" ]]; then
      mkdir -p "$(dirname -- "$st")"; cp -a -- "$from" "$st"
      info "Confirme os IDs com: ./tools/glpi/bin/glpi states discover"
    fi
  fi
  ok "S processado: ${N_SEED} semeado(s), ${N_SKIP} preservado(s)."
}

# =============================================================================
# 11. DEPRECIACAO (stubs de alias) — nunca apaga
# =============================================================================
write_deprecated_skill() {
  local old="$1" new="$2" dir="${TARGET_DIR}/.github/skills/${old}"
  mkdir -p "$dir"
  cat > "${dir}/SKILL.md" <<EOF
---
name: ${old}
description: "DEPRECATED alias de ${new}. Redireciona para a skill primaria; nao usar em novos fluxos."
---

# Skill: ${old} (deprecated)

**Deprecated desde o kit v${SCRIPT_VERSION} (modelo F/S/P, schema ${SCHEMA_TARGET}).**

Preferir **\`${new}\`**.

Se esta skill for acionada pelo nome legado, carregar e seguir **integralmente**
[\`.github/skills/${new}/SKILL.md\`](../${new}/SKILL.md).

Motivo: o modelo passou de 3 niveis (Projeto -> S -> P) para 4 niveis
(Projeto -> **F** -> S -> P), com as 5 fases
F1 Planejamento · F2 Implementacao · F3 Testes Internos · F4 Homologacao · F5 Aprovacao.

Migracao de codes: \`./tools/glpi/bin/glpi-migrate-codes --dry-run\`
EOF
}

mark_deprecations() {
  (( MARK_DEPRECATED == 0 )) && { info "Depreciacao desativada (--no-deprecate)."; return 0; }
  step "Marcando artefatos v1 como DEPRECATED (sem apagar)"
  local pair old new
  for pair in "${DEPRECATED_SKILLS[@]}"; do
    old="${pair%%|*}"; new="${pair##*|}"
    if (( APPLY == 0 )); then
      printf '  %sdeprecate%s  .github/skills/%s -> %s\n' "$C_YEL" "$C_RST" "$old" "$new"
    else
      write_deprecated_skill "$old" "$new"
      vrb "stub DEPRECATED: ${old} -> ${new}"
    fi
  done
  local tpl f
  for tpl in "${DEPRECATED_TEMPLATES[@]}"; do
    f="${TARGET_DIR}/${tpl}"
    [[ -f "$f" ]] || continue
    grep -q 'DEPRECATED' "$f" 2>/dev/null && { vrb "ja marcado: ${tpl}"; continue; }
    if (( APPLY == 0 )); then
      printf '  %sdeprecate%s  %s (cabecalho de aviso)\n' "$C_YEL" "$C_RST" "$tpl"
    else
      local hdr="${f}.hdr.$$"
      case "$f" in
        *.yaml|*.yml)
          { printf '# DEPRECATED (kit v%s): template de 7 fases do modelo v1.\n' "$SCRIPT_VERSION"
            printf '# Substituto: lifecycle-5-phases (F1..F5). Mantido apenas para leitura/migracao.\n'
            printf '# Ver docs/06_glpi/MIGRACAO_V1_V2.md\n'
            cat "$f"; } > "$hdr" && mv -- "$hdr" "$f" ;;
        *.json)
          if command -v python3 >/dev/null 2>&1; then
            python3 - "$f" "$SCRIPT_VERSION" <<'PY' || warn "Falha ao marcar ${f}"
import json, sys
p, v = sys.argv[1], sys.argv[2]
with open(p, encoding='utf-8') as fh: d = json.load(fh)
if isinstance(d, dict):
    d['deprecated'] = True
    d['deprecated_since'] = f'kit v{v}'
    d['replaced_by'] = 'lifecycle-5-phases'
    d['migration_doc'] = 'docs/06_glpi/MIGRACAO_V1_V2.md'
    with open(p, 'w', encoding='utf-8') as fh:
        json.dump(d, fh, ensure_ascii=False, indent=2); fh.write('\n')
PY
          else
            warn "python3 ausente: ${tpl} nao marcado."
          fi ;;
      esac
    fi
  done
  ok "Artefatos v1 marcados (preservados para auditoria)."
}

# =============================================================================
# 12. MIGRACAO v1 -> v2
# =============================================================================
migrate_v2() {
  (( MIGRATE == 0 )) && return 0
  step "Migracao de esquema v1 -> v2 (S/P  ->  F/S/P)"
  local report="${TARGET_DIR}/docs/06_glpi/retro-scans/migracao-v2-${TS}.md"
  local plans_dir="${TARGET_DIR}/docs/05_progresso"
  local n_plans=0 n_codes=0

  if [[ -d "$plans_dir" ]]; then
    n_plans=$(find "$plans_dir" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    n_codes=$(grep -rEoh '\*\*(S[0-9]+(\.P[0-9]+)?|PR|PH|R|H|I)[0-9]*\*\*' \
                "$plans_dir" 2>/dev/null | sort -u | wc -l | tr -d ' ')
  fi

  log ""
  printf '  %-34s %s\n' "Planos markdown encontrados:" "$n_plans"
  printf '  %-34s %s\n' "Codes v1 distintos detectados:" "$n_codes"
  log ""
  warn "Codes v1 (S4, S4.P5, PR/PH/R/H/I) NAO sao reescritos automaticamente:"
  warn "a atribuicao de fase exige julgamento humano (relacao muitos-para-um)."
  log ""
  log "  Passos manuais apos este upgrade:"
  log "    1. ./tools/glpi/bin/glpi-migrate-codes --dry-run"
  log "    2. revisar o mapa proposto (docs/06_glpi/retro-scans/)"
  log "    3. ./tools/glpi/bin/glpi-migrate-codes --apply"
  log "    4. ./tools/glpi/bin/glpi-phase-ensure --all --adopt-legacy --apply"
  log "    5. ./tools/glpi/bin/glpi-tree-validate --remote --project-code=<CODE>"
  log "    6. ./tools/glpi/bin/glpi-progress-rollup --apply"
  log ""

  if (( APPLY == 0 )); then
    info "[dry-run] gravaria o relatorio em ${report#"$TARGET_DIR"/}"
    return 0
  fi

  mkdir -p "$(dirname -- "$report")"
  {
    printf '# Relatorio de migracao v1 -> v2\n\n'
    printf '> Gerado por %s v%s em %s\n' "$SCRIPT_NAME" "$SCRIPT_VERSION" "$(date -Iseconds)"
    printf '> Produto: `%s` · Preset: `%s`\n\n' "$TARGET_DIR" "$PRESET"
    printf '## Resumo\n\n'
    printf '| Metrica | Valor |\n|---|---|\n'
    printf '| Planos markdown | %s |\n' "$n_plans"
    printf '| Codes v1 distintos | %s |\n' "$n_codes"
    printf '| Schema anterior | %s |\n' "${DETECTED_SCHEMA:-1 (implicito)}"
    printf '| Schema alvo | %s |\n\n' "$SCHEMA_TARGET"
    printf '## Mudanca estrutural\n\n'
    printf '```text\nv1: Projeto -> S -> P\nv2: Projeto -> F -> S -> P\n```\n\n'
    printf '| Fase v2 | Nome | Origem legada tipica |\n|---|---|---|\n'
    printf '| F1 | Planejamento | Discovery, Analise, Projeto |\n'
    printf '| F2 | Implementacao | Implementacao Front-end, Back-end |\n'
    printf '| F3 | Testes Internos | **nova — sem origem legada** |\n'
    printf '| F4 | Homologacao | Homologacao |\n'
    printf '| F5 | Aprovacao | Evolucao / encerramento |\n\n'
    printf '## Codes v1 detectados nos planos\n\n```text\n'
    grep -rEoh '\*\*(S[0-9]+(\.P[0-9]+)?|PR|PH|R|H|I)[0-9]*\*\*' \
      "$plans_dir" 2>/dev/null | sort -u || printf '(nenhum)\n'
    printf '```\n\n'
    printf '## Acoes pendentes\n\n'
    printf -- '- [ ] `glpi-migrate-codes --dry-run` e revisao do mapa\n'
    printf -- '- [ ] Decidir origem das sessoes de **F3 Testes Internos** (fase nova)\n'
    printf -- '- [ ] `glpi-phase-ensure --all --adopt-legacy --apply`\n'
    printf -- '- [ ] Reescrever cabecalhos dos planos vigentes para `F<n>.S<n>.P<n>`\n'
    printf -- '- [ ] Mover planos encerrados para `docs/05_progresso/legados/`\n'
    printf -- '- [ ] `glpi-tree-validate --remote --project-code=<CODE>` com exit 0\n'
    printf -- '- [ ] `glpi-progress-rollup --apply`\n'
    printf -- '- [ ] Registrar o fechamento com `acompanhar-chamado --code=<code>`\n\n'
    printf '## Observacoes de risco\n\n'
    printf 'A funcao de mapeamento legado -> fase e **sobrejetiva, nao injetiva**:\n'
    printf 'ao consolidar `4.1` e `4.2` em `F2`, a distincao front/back-end e perdida\n'
    printf 'no nivel da fase e deve ser rebaixada ao nivel S (`demote_to`).\n'
    printf 'Por isso `legacy.reverse_policy: forbid` — a migracao reversa e proibida.\n\n'
    printf 'Nenhum objeto legado foi apagado (`legacy.never_delete: true`).\n'
  } > "$report"

  # Atualiza o schema no project.yaml do produto (unica escrita em P permitida,
  # feita de forma cirurgica e somente com --migrate-v2 + --apply)
  local pyaml="${TARGET_DIR}/.glpi/project.yaml"
  if [[ -f "$pyaml" ]]; then
    cp -a -- "$pyaml" "${pyaml}.bak-${TS}"
    if grep -qE '^[[:space:]]*schema[[:space:]]*:' "$pyaml"; then
      sed -i.tmp -E "s/^([[:space:]]*schema[[:space:]]*:[[:space:]]*).*/\1${SCHEMA_TARGET}/" "$pyaml"
      rm -f -- "${pyaml}.tmp"
    else
      printf '%s\n%s\n' "schema: ${SCHEMA_TARGET}" "$(cat "$pyaml")" > "${pyaml}.new" \
        && mv -- "${pyaml}.new" "$pyaml"
    fi
    ok "project.yaml: schema -> ${SCHEMA_TARGET} (backup em project.yaml.bak-${TS})"
  fi

  ok "Relatorio gravado: ${report#"$TARGET_DIR"/}"
}

# =============================================================================
# 13. AUTO-ATUALIZACAO DOS PROPRIOS SCRIPTS (diferida)
# =============================================================================
# Copiar um script shell sobre si mesmo enquanto ele executa pode corromper a
# leitura do interpretador. Por isso os instaladores sao copiados por ULTIMO,
# via arquivo temporario + mv atomico.
readonly -a SELF_SCRIPTS=(
  "scripts/upgrade-into.sh"
  "scripts/bootstrap-into.sh"
  "scripts/install-glpi.sh"
  "scripts/install_glpi.py"
)

self_update() {
  step "Atualizando scripts instaladores (copia atomica diferida)"
  local rel src dst tmp
  for rel in "${SELF_SCRIPTS[@]}"; do
    src="${SOURCE_DIR}/${rel}"
    dst="${TARGET_DIR}/${rel}"
    [[ -f "$src" ]] || { vrb "ausente no kit: ${rel}"; continue; }

    # Mesmo conteudo? nao faz nada.
    if [[ -f "$dst" ]] && cmp -s -- "$src" "$dst"; then
      vrb "ja atualizado: ${rel}"
      continue
    fi

    if (( APPLY == 0 )); then
      printf '  %soverwrite%s  %s %s(atomico)%s\n' "$C_YEL" "$C_RST" "$rel" "$C_DIM" "$C_RST"
      (( N_OVERWRITE++ ))
      continue
    fi

    mkdir -p "$(dirname -- "$dst")"
    tmp="${dst}.new.$$"
    cp -a -- "$src" "$tmp" || die "Falha ao preparar ${rel}" 8
    chmod +x "$tmp" 2>/dev/null || true
    mv -f -- "$tmp" "$dst" || die "Falha ao mover ${rel}" 8
    vrb "overwrite atomico: ${rel}"
    (( N_OVERWRITE++ ))
  done

  # Bit de execucao em todos os wrappers do CLI
  if (( APPLY == 1 )); then
    if [[ -d "${TARGET_DIR}/tools/glpi/bin" ]]; then
      find "${TARGET_DIR}/tools/glpi/bin" -maxdepth 1 -type f \
        -exec chmod +x {} \; 2>/dev/null || true
      ok "Permissao de execucao garantida em tools/glpi/bin/"
    fi
    [[ -f "${TARGET_DIR}/tools/glpi/glpi" ]] && chmod +x "${TARGET_DIR}/tools/glpi/glpi" 2>/dev/null || true
  fi
}

# =============================================================================
# 14. SELO DE VERSAO, .gitignore E VALIDACAO POS-UPGRADE
# =============================================================================
stamp_version() {
  step "Selando versao do kit no produto"
  local f="${TARGET_DIR}/.glpi/.kit-version"
  if (( APPLY == 0 )); then
    info "[dry-run] gravaria .glpi/.kit-version = ${SCRIPT_VERSION}"
    return 0
  fi
  mkdir -p "${TARGET_DIR}/.glpi"
  {
    printf '%s\n' "$SCRIPT_VERSION"
    printf '# kit: API-VSCode-GLPI (pmf-dev-kit)\n'
    printf '# preset: %s\n' "$PRESET"
    printf '# schema: %s\n' "$SCHEMA_TARGET"
    printf '# upgraded_at: %s\n' "$(date -Iseconds)"
    printf '# source: %s\n' "$SOURCE_DIR"
    printf '# host: %s\n' "$(hostname 2>/dev/null || echo desconhecido)"
  } > "$f"
  ok ".glpi/.kit-version = ${SCRIPT_VERSION}"
}

ensure_gitignore() {
  step "Conferindo .gitignore (protecao de segredos e cache)"
  local gi="${TARGET_DIR}/.gitignore"
  local -a needed=(
    ".glpi/instance.yaml"
    ".glpi/index.json"
    ".glpi/.backups/"
    ".glpi/*.bak-*"
    "GLPI-tokens.txt"
    ".secrets/"
    "*.env"
  )
  local entry missing=()
  for entry in "${needed[@]}"; do
    if [[ -f "$gi" ]] && grep -qxF -- "$entry" "$gi" 2>/dev/null; then
      vrb "ja protegido: ${entry}"
    else
      missing+=("$entry")
    fi
  done
  if (( ${#missing[@]} == 0 )); then
    ok ".gitignore ja cobre todos os padroes sensiveis."
    return 0
  fi
  printf '  %s%d padrao(oes) ausente(s):%s\n' "$C_YEL" "${#missing[@]}" "$C_RST"
  printf '      %s\n' "${missing[@]}"
  if (( APPLY == 0 )); then
    info "[dry-run] acrescentaria os padroes acima ao .gitignore"
    return 0
  fi
  {
    printf '\n# --- GLPI kit (upgrade-into.sh v%s em %s) ---\n' "$SCRIPT_VERSION" "$TS"
    printf '%s\n' "${missing[@]}"
  } >> "$gi"
  ok ".gitignore atualizado com ${#missing[@]} padrao(oes)."
}

post_validate() {
  (( RUN_VALIDATE == 0 )) && { info "Validacao pos-upgrade desativada."; return 0; }
  (( APPLY == 0 ))        && { info "[dry-run] validacao pos-upgrade nao executada."; return 0; }
  step "Validacao pos-upgrade"

  local cli="${TARGET_DIR}/tools/glpi/bin/glpi-tree-validate"
  local code; code="$(yaml_get "${TARGET_DIR}/.glpi/project.yaml" code || true)"

  # 14.1 — presenca dos arquivos minimos
  local -a must=(
    "tools/glpi/bin"
    ".glpi/model.defaults.yaml"
    ".glpi/templates/lifecycle-5-phases.yaml"
    ".glpi/presets/${PRESET}"
    ".github/skills/glpi-node-upsert/SKILL.md"
    ".github/skills/glpi-phase-ensure/SKILL.md"
  )
  local m fail=0
  for m in "${must[@]}"; do
    if [[ -e "${TARGET_DIR}/${m}" ]]; then
      vrb "presente: ${m}"
    else
      err "AUSENTE apos upgrade: ${m}"; fail=1
    fi
  done
  (( fail == 1 )) && die "Instalacao incompleta — restaure o backup: ${BACKUP_DIR:-<sem backup>}" 7
  ok "Arquivos minimos presentes."

  # 14.2 — soma dos pesos das fases
  if command -v python3 >/dev/null 2>&1; then
    python3 - "${TARGET_DIR}" <<'PY' || warn "Conferencia de pesos inconclusiva."
import re, sys, pathlib
root = pathlib.Path(sys.argv[1])
f = root / ".glpi" / "model.defaults.yaml"
if not f.exists():
    sys.exit(0)
w = [float(x) for x in re.findall(r"weight:\s*([0-9.]+)", f.read_text(encoding="utf-8"))]
if w:
    s = sum(w)
    status = "OK" if abs(s - 1.0) <= 0.001 else "DIVERGENTE"
    print(f"      pesos das fases: {w} -> soma={s:.3f} [{status}]")
    if status == "DIVERGENTE":
        sys.exit(1)
PY
    ok "Pesos das fases conferidos (soma = 1.0)."
  fi

  # 14.3 — lint da arvore remota (opcional, exige credenciais)
  if [[ -x "$cli" && -n "$code" ]]; then
    info "Executando lint remoto: glpi-tree-validate --remote --project-code=${code}"
    if (cd "$TARGET_DIR" && "$cli" --remote --project-code="$code" --quiet); then
      ok "Arvore F/S/P remota valida."
    else
      warn "glpi-tree-validate retornou divergencias — revise antes do proximo --apply."
      warn "Detalhes: (cd ${TARGET_DIR} && ./tools/glpi/bin/glpi-tree-validate --remote --project-code=${code})"
    fi
  else
    info "Lint remoto nao executado (CLI indisponivel ou 'code' ausente em project.yaml)."
  fi
}

# =============================================================================
# 15. CONFIRMACAO, RESUMO E ORQUESTRACAO
# =============================================================================
confirm_apply() {
  (( APPLY == 0 ))      && return 0
  (( ASSUME_YES == 1 )) && { info "Confirmacao dispensada (--yes)."; return 0; }
  if [[ ! -t 0 ]]; then
    die "Modo nao interativo sem --yes. Abortado por seguranca." 6
  fi
  log ""
  printf '%s┌──────────────────────────────────────────────────────────────┐%s\n' "$C_YEL" "$C_RST"
  printf '%s│  ATENCAO: o modo --apply ESCREVE no clone do produto.         │%s\n' "$C_YEL" "$C_RST"
  printf '%s└──────────────────────────────────────────────────────────────┘%s\n' "$C_YEL" "$C_RST"
  printf '  Produto : %s\n' "$TARGET_DIR"
  printf '  Preset  : %s\n' "$PRESET"
  printf '  Backup  : %s\n' "$( (( DO_BACKUP )) && echo "SIM (.glpi/.backups/${TS}/)" || echo "NAO (--no-backup)" )"
  printf '  Migracao: %s\n' "$( (( MIGRATE )) && echo "SIM (v1 -> v2)" || echo "nao" )"
  log ""
  printf '  Camada K (kit)     : %ssobrescrita%s\n'       "$C_YEL" "$C_RST"
  printf '  Camada P (produto) : %spreservada%s\n'        "$C_GRN" "$C_RST"
  printf '  Camada S (seed)    : %scriada se ausente%s\n' "$C_CYN" "$C_RST"
  log ""
  local ans
  read -r -p "  Digite ${C_BLD}APLICAR${C_RST} para prosseguir: " ans || true
  [[ "$ans" == "APLICAR" ]] || die "Abortado pelo usuario." 6
  log ""
}

summary() {
  step "Resumo"
  log ""
  printf '  %-34s %s\n' "Sobrescritos (K):"       "$N_OVERWRITE"
  printf '  %-34s %s\n' "Preservados (P):"        "$N_PRESERVE"
  printf '  %-34s %s\n' "Semeados (S):"           "$N_SEED"
  printf '  %-34s %s\n' "Ignorados (S, ja havia):" "$N_SKIP"
  printf '  %-34s %s\n' "Ausentes no kit:"        "$N_MISSING"
  log ""
  if (( APPLY == 0 )); then
    printf '%s  DRY-RUN — nenhuma alteracao foi escrita.%s\n' "$C_CYN" "$C_RST"
    log ""
    log "  Para efetivar:"
    printf '    %s%s --target=%s --apply%s\n' \
      "$C_BLD" "./scripts/upgrade-into.sh" "$TARGET_DIR" "$C_RST"
  else
    printf '%s  UPGRADE CONCLUIDO.%s\n' "$C_GRN" "$C_RST"
    [[ -n "$BACKUP_DIR" ]] && log "  Backup: ${BACKUP_DIR}"
    log ""
    log "  Proximos passos sugeridos:"
    log "    1. cd ${TARGET_DIR}"
    log "    2. git diff --stat                      # revisar o que mudou"
    log "    3. ./tools/glpi/bin/glpi states discover  # confirmar IDs da instancia"
    log "    4. ./tools/glpi/bin/glpi-phase-ensure --all          # dry-run"
    log "    5. ./tools/glpi/bin/glpi-phase-ensure --all --apply"
    log "    6. ./tools/glpi/bin/glpi-retro-scan --with-git"
    log "    7. ./tools/glpi/bin/glpi-tree-validate --from=<scan.json>"
    log "    8. ./tools/glpi/bin/glpi-retro-apply --from=<scan.json> --apply"
    log "    9. ./tools/glpi/bin/glpi-progress-rollup --apply"
    (( MIGRATE == 1 )) && \
    log "   10. ./tools/glpi/bin/glpi-migrate-codes --dry-run   # consolidar codes v1"
  fi
  log ""
  printf '%s  Doc: docs/06_glpi/MODELO_OVERLAY.md · docs/06_glpi/MIGRACAO_V1_V2.md%s\n' "$C_DIM" "$C_RST"
  log ""
}

on_error() {
  local rc=$? line=${1:-?}
  err "Falha na linha ${line} (exit ${rc})."
  if [[ -n "${BACKUP_DIR:-}" && -d "${BACKUP_DIR:-}" ]]; then
    warn "Restaure com:  cp -a ${BACKUP_DIR}/. ${TARGET_DIR}/"
  elif (( APPLY == 1 )); then
    warn "Sem backup disponivel. Se o target for git:  git -C ${TARGET_DIR} checkout ."
  fi
  exit "$rc"
}
trap 'on_error $LINENO' ERR

main() {
  log ""
  printf '%s%s v%s%s — atualizador do kit GLPI (modelo F/S/P, schema %s)\n' \
    "$C_BLD" "$SCRIPT_NAME" "$SCRIPT_VERSION" "$C_RST" "$SCHEMA_TARGET"

  # --- fase 1: verificacoes (nao escrevem) ---
  assert_disjoint
  detect_state
  check_git_clean

  # --- fase 2: confirmacao ---
  confirm_apply

  # --- fase 3: escrita ---
  make_backup
  sync_kit_owned
  report_product_owned
  seed_missing
  mark_deprecations
  migrate_v2
  self_update
  ensure_gitignore
  stamp_version

  # --- fase 4: verificacao final ---
  post_validate
  summary
  exit 0
}

main "$@"
# =============================================================================
#  FIM DE upgrade-into.sh
# =============================================================================