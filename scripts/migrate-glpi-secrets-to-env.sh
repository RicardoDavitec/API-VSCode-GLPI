#!/usr/bin/env bash
# migrate-glpi-secrets-to-env.sh — gera ~/.secrets/glpi.env a partir de GLPI-tokens.txt (pmf)
set -euo pipefail

SRC="${GLPI_SECRETS_SRC:-${HOME}/.secrets/GLPI-tokens.txt}"
DST="${GLPI_SECRETS_DST:-${HOME}/.secrets/glpi.env}"
FORCE=0

usage() {
  echo "Uso: $0 [--src=PATH] [--dst=PATH] [--force]"
  echo "  Le o arquivo legado pmf e escreve dotenv otimizado (sem ecoar tokens)."
}

for arg in "$@"; do
  case "$arg" in
    --src=*) SRC="${arg#*=}" ;;
    --dst=*) DST="${arg#*=}" ;;
    --force) FORCE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "flag desconhecida: $arg" >&2; exit 1 ;;
  esac
done

[[ -f "$SRC" ]] || { echo "erro: origem ausente: $SRC" >&2; exit 1; }
if [[ -f "$DST" && "$FORCE" -ne 1 ]]; then
  echo "erro: destino ja existe: $DST (use --force)" >&2
  exit 1
fi

mkdir -p "$(dirname "$DST")"
chmod 700 "$(dirname "$DST")" 2>/dev/null || true

python3 - "$SRC" "$DST" <<'PY'
import re, sys
from pathlib import Path

src, dst = Path(sys.argv[1]), Path(sys.argv[2])
text = src.read_text(encoding="utf-8", errors="replace")
personal = group = url_prod = url_homolog = ""

for raw in text.splitlines():
    line = raw.strip().replace("\r", "")
    if not line or line.startswith("#"):
        continue
    m = re.search(r"pessoal\s+api-glpi\s*:\s*(.+)", line, re.I)
    if m:
        personal = re.sub(r"\s+", "", m.group(1))
        continue
    m = re.search(r"grupo\s+api-glpi\s*:\s*(.+)", line, re.I)
    if m:
        group = re.sub(r"\s+", "", m.group(1))
        continue
    m = re.search(r"url-?\s*api\s*homolog", line, re.I)
    if m:
        um = re.search(r"(https?://\S+)", line)
        if um:
            url_homolog = um.group(1).rstrip("/").rstrip(";")
        continue
    m = re.search(r"url-?\s*api\s*:", line, re.I)
    if m and "homolog" not in line.lower():
        um = re.search(r"(https?://\S+)", line)
        if um:
            url_prod = um.group(1).rstrip("/").rstrip(";")
        continue

def ensure_apirest(u: str) -> str:
    if not u:
        return u
    u = u.rstrip("/")
    if not u.endswith("apirest.php"):
        u = u + "/apirest.php"
    return u

url_prod = ensure_apirest(url_prod) or "https://suporte.franca.sp.gov.br/apirest.php"
url_homolog = ensure_apirest(url_homolog) or "https://suporte-homolog.franca.sp.gov.br/apirest.php"

ui_prod = url_prod.replace("/apirest.php", "")
ui_homolog = url_homolog.replace("/apirest.php", "")

if not personal:
    print("erro: Pessoal API-GLPI nao encontrado na origem", file=sys.stderr)
    sys.exit(1)

lines = [
    "# Gerado por scripts/migrate-glpi-secrets-to-env.sh — nao versionar",
    "# Formato dotenv para pmf-dev-kit / API-VSCode-GLPI",
    "",
    f"GLPI_USER_TOKEN={personal}",
]
if group:
    lines.append(f"GLPI_APP_TOKEN={group}")
lines += [
    "",
    f"GLPI_API_URL_PROD={url_prod}",
    f"GLPI_UI_URL_PROD={ui_prod}",
    "",
    f"GLPI_API_URL_HOMOLOG={url_homolog}",
    f"GLPI_UI_URL_HOMOLOG={ui_homolog}",
    "",
    "GLPI_ENV_DEFAULT=prod",
    "",
]
dst.write_text("\n".join(lines), encoding="utf-8")
print(f"OK: escrito {dst} (tokens omitidos deste log)")
print(f"  PROD    API: {url_prod}")
print(f"  HOMOLOG API: {url_homolog}")
print(f"  USER_TOKEN: presente ({len(personal)} chars)")
print(f"  APP_TOKEN: {'presente ('+str(len(group))+' chars)' if group else 'ausente'}")
PY

chmod 600 "$DST"
echo "Permissao: chmod 600 $DST"
echo "Proximos passos:"
echo "  export GLPI_SECRETS_FILE=$DST"
echo "  ./tools/glpi/glpi --env=homolog auth"
echo "  # legado GLPI-tokens.txt pode permanecer como backup"
