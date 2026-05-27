#!/usr/bin/env bash
set -euo pipefail
RUN_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RUN_DIR/RUNINFO.txt"
TEMPLATE="$RUN_DIR/netlist_template/raw"
SRC="${NETLIST_SOURCE:-/home/s5117909/simulation/synapsedualinputtb/spectre/schematic/netlist}"
if [ ! -f "$SRC/input.scs" ]; then
  echo "ERROR: cannot find template input.scs at $SRC/input.scs" >&2
  echo "Set NETLIST_SOURCE=/path/to/netlist and rerun ./import_template.sh" >&2
  exit 1
fi
rm -rf "$TEMPLATE"; mkdir -p "$TEMPLATE"
cp -a "$SRC"/. "$TEMPLATE"/
[ -f "$RUN_DIR/support/ade_e.scs" ] && cp -f "$RUN_DIR/support/ade_e.scs" "$TEMPLATE/ade_e.scs"
first=$(awk -F, 'NR==2{print $3 "\n" $4}' "$RUN_DIR/cases.csv")
st1=$(echo "$first" | sed -n '1p')
st2=$(echo "$first" | sed -n '2p')
python3 - "$TEMPLATE" "$st1" "$st2" <<'PY'
import pathlib, sys
root=pathlib.Path(sys.argv[1]); st1=sys.argv[2]; st2=sys.argv[3]
for p in root.rglob('*'):
    if not p.is_file():
        continue
    try:
        s=p.read_text(errors='ignore')
    except Exception:
        continue
    ns=s.replace(st1, '__ST1_PWL__').replace(st2, '__ST2_PWL__')
    if ns != s:
        p.write_text(ns)
        print('patched', p)
PY
echo "Imported template into $TEMPLATE"
grep -RniE 'pwl|__ST1_PWL__|__ST2_PWL__|ade_e' "$TEMPLATE" | head -80 || true
