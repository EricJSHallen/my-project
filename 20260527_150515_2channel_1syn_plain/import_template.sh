#!/usr/bin/env bash
set -euo pipefail
RUN_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RUN_DIR/RUNINFO.txt"

SRC="${CADENCE_NETLIST_SOURCE}"
DST="$RUN_DIR/netlist_template/raw"
[ -d "$SRC" ] || { echo "ERROR: netlist source not found: $SRC" >&2; exit 1; }
rm -rf "$DST"
mkdir -p "$DST"
cp -a "$SRC"/. "$DST"/

if [ -f "$RUN_DIR/support/ade_e.scs" ]; then
  cp -f "$RUN_DIR/support/ade_e.scs" "$DST/ade_e.scs"
fi

ST1_TEMPLATE_PATH="$(grep -RhoE '/[^"[:space:]]*/st_1/[^"[:space:]]+\.pwl' "$DST" 2>/dev/null | head -1 || true)"
ST2_TEMPLATE_PATH="$(grep -RhoE '/[^"[:space:]]*/st_2/[^"[:space:]]+\.pwl' "$DST" 2>/dev/null | head -1 || true)"

echo "ST1_TEMPLATE_PATH=$ST1_TEMPLATE_PATH" | tee "$RUN_DIR/netlist_template/template_paths.env"
echo "ST2_TEMPLATE_PATH=$ST2_TEMPLATE_PATH" | tee -a "$RUN_DIR/netlist_template/template_paths.env"

if [ -z "$ST1_TEMPLATE_PATH" ] || [ -z "$ST2_TEMPLATE_PATH" ]; then
  echo "WARNING: Could not find PWL file paths in template." >&2
  echo "Inspect with: grep -RniE 'pwl|st_1|st_2|trial|pwlFile' $DST" >&2
else
  python3 - "$DST" "$ST1_TEMPLATE_PATH" "$ST2_TEMPLATE_PATH" <<'PY'
import pathlib, sys
root = pathlib.Path(sys.argv[1])
st1 = sys.argv[2]
st2 = sys.argv[3]
for p in root.rglob("*"):
    if not p.is_file():
        continue
    try:
        s = p.read_text(errors="ignore")
    except Exception:
        continue
    ns = s.replace(st1, "__ST1_PWL__").replace(st2, "__ST2_PWL__")
    if ns != s:
        p.write_text(ns)
        print(f"patched {p}")
PY
fi

echo "Imported template into: $DST"
echo "Check template with: grep -RniE 'pwl|__ST1_PWL__|__ST2_PWL__|ade_e' $DST | head -80"
