#!/usr/bin/env bash
set -euo pipefail
RUN_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$RUN_DIR/RUNINFO.txt"
TEMPLATE="$RUN_DIR/netlist_template/raw"
SRC="${NETLIST_SOURCE:-/home/s5117909/simulation/synapsedualinputtb/spectre/schematic/netlist}"
if [ ! -f "$SRC/input.scs" ]; then
  echo "ERROR: cannot find template input.scs at $SRC/input.scs" >&2
  echo "Run one Cadence/OCEAN netlist first, or set NETLIST_SOURCE=/path/to/netlist." >&2
  exit 1
fi
rm -rf "$TEMPLATE"
mkdir -p "$TEMPLATE"
cp -a "$SRC"/. "$TEMPLATE"/
[ -f "$RUN_DIR/support/ade_e.scs" ] && cp -f "$RUN_DIR/support/ade_e.scs" "$TEMPLATE/ade_e.scs"
python3 - "$TEMPLATE" <<'PY_IMPORT'
import pathlib
import re
import sys
root = pathlib.Path(sys.argv[1])
# Replace any existing PWL path under spike_train_output/st_1 or st_2, with
# optional surrounding quotes. The placeholders are deliberately left bare;
# run_spectre_worker.sh inserts quoted Spectre string values per case.
st1_pat = re.compile(r'"?/home/[^"\s]*?/spike_train_output/st_1/[^"\s]*?\.pwl"?')
st2_pat = re.compile(r'"?/home/[^"\s]*?/spike_train_output/st_2/[^"\s]*?\.pwl"?')
patched = []
for p in root.rglob('*'):
    if not p.is_file():
        continue
    try:
        s = p.read_text(errors='ignore')
    except Exception:
        continue
    ns = st1_pat.sub('__ST1_PWL__', s)
    ns = st2_pat.sub('__ST2_PWL__', ns)
    if ns != s:
        p.write_text(ns)
        patched.append(str(p))
for item in patched:
    print('patched', item)
print(f'patched_files={len(patched)}')
PY_IMPORT
if ! grep -R "__ST1_PWL__" "$TEMPLATE" >/dev/null; then
  echo "ERROR: __ST1_PWL__ placeholder not found in template." >&2
  exit 1
fi
if ! grep -R "__ST2_PWL__" "$TEMPLATE" >/dev/null; then
  echo "ERROR: __ST2_PWL__ placeholder not found in template." >&2
  exit 1
fi
echo "Imported template into $TEMPLATE"
echo "Template placeholders verified."
