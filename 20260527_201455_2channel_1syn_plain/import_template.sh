#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck disable=SC1091
source ./RUNINFO.txt

RAW="netlist_template/raw"
if [ ! -f "$RAW/input.scs" ]; then
  echo "ERROR: missing $RAW/input.scs. Run ./run_template_ocean.sh first, or use ciw_template_command.il in CIW."
  exit 1
fi

# Replace only the PWL parameter values with stable placeholders.
python3 - "$RAW" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
for p in root.rglob('*'):
    if not p.is_file():
        continue
    try:
        s = p.read_text(errors='ignore')
    except Exception:
        continue
    ns = re.sub(r'pwlFile_st1="[^"]*"', 'pwlFile_st1="__ST1_PWL__"', s)
    ns = re.sub(r'pwlFile_st2="[^"]*"', 'pwlFile_st2="__ST2_PWL__"', ns)
    if ns != s:
        p.write_text(ns)
        print(f"patched {p}")
PY

echo "Imported/cleaned template. Check placeholders with:"
echo "  grep -RniE '__ST1_PWL__|__ST2_PWL__|save .*vpre|I56' netlist_template/raw | head -40"
