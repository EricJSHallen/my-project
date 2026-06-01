#!/usr/bin/env bash
set -euo pipefail
RUN_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$RUN_DIR/RUNINFO.txt"
TEMPLATE="$RUN_DIR/netlist_template/raw"
SRC="${NETLIST_SOURCE:-/home/s5117909/simulation/synapsedualinputtb/spectre/schematic/netlist}"
if [[ ! -f "$SRC/input.scs" ]]; then
  echo "ERROR: cannot find template input.scs at $SRC/input.scs" >&2
  echo "Run one Cadence/OCEAN netlist first, or set NETLIST_SOURCE=/path/to/netlist." >&2
  exit 1
fi
rm -rf "$TEMPLATE"
mkdir -p "$TEMPLATE"
cp -a "$SRC"/. "$TEMPLATE"/
[[ -f "$RUN_DIR/support/ade_e.scs" ]] && cp -f "$RUN_DIR/support/ade_e.scs" "$TEMPLATE/ade_e.scs"
python3 - "$TEMPLATE" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
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
PY
python3 - "$TEMPLATE" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
input_scs = root / 'input.scs'
if not input_scs.is_file():
    raise SystemExit(f'ERROR: missing {input_scs}')
param_line = (
    'parameters '
    'm2w=3u m2l=200n '
    'm3w=2.1u m3l=4u '
    'm4w=2.1u m4l=1.05u '
    'm5w=2.1u m5l=1.05u '
    'm4wtb=2.1u m4ltb=1.05u '
    'm2wtb=2.1u m2ltb=1.05u '
    'pw=100u T=1m Vin=0 vmax=1.8 '
    'Vw=0.5 Vthr=0.9 Vtau=1.6 '
    'capacitance=6p '
    'pwlFile_st2=__ST2_PWL__ '
    'pwlFile_st1=__ST1_PWL__'
)
s = input_scs.read_text(errors='ignore')
ns, n = re.subn(r'parameters\b.*?(?=\s+include\s+")', param_line + '\n', s, count=1, flags=re.S)
if n != 1:
    raise SystemExit('ERROR: could not replace top-level parameters block in input.scs')
input_scs.write_text(ns)
(root / '.designVariables').write_text(param_line + '\n')
combined = ''
for p in root.rglob('*'):
    if p.is_file():
        try:
            combined += p.read_text(errors='ignore') + '\n'
        except Exception:
            pass
if '__ST1_PWL__' not in combined or '__ST2_PWL__' not in combined:
    raise SystemExit('ERROR: PWL placeholders missing after parameter patch')
block = re.search(r'parameters\b.*?(?=\s+include\s+")', input_scs.read_text(errors='ignore'), flags=re.S).group(0)
for token in ['m2w ', 'm2l ', 'm2wtb ', 'Vw ', 'Vthr ', 'Vtau ', 'capacitance ']:
    if token in block:
        raise SystemExit(f'ERROR: unresolved bare parameter remains in parameter block: {token!r}')
print(f'patched parameters in {input_scs}')
print('template parameter block verified')
PY
echo "Imported template into $TEMPLATE"
echo "Template placeholders and parameters verified."
