#!/usr/bin/env bash
set -euo pipefail
RUN_DIR="$(cd "$(dirname "$0")" && pwd -P)"
source "$RUN_DIR/RUNINFO.txt"
TEMPLATE="$RUN_DIR/netlist_template/raw"
SRC="${NETLIST_SOURCE:-/home/s5117909/simulation/synapsedualinputtb/spectre/schematic/netlist}"
[[ -f "$SRC/input.scs" ]] || { echo "ERROR: cannot find template input.scs at $SRC/input.scs" >&2; exit 1; }
rm -rf "$TEMPLATE"; mkdir -p "$TEMPLATE"; cp -a "$SRC"/. "$TEMPLATE"/
[[ -f "$RUN_DIR/support/ade_e.scs" ]] && cp -f "$RUN_DIR/support/ade_e.scs" "$TEMPLATE/ade_e.scs"
python3 - "$TEMPLATE" <<'PY'
import pathlib, re, sys
root=pathlib.Path(sys.argv[1])
st1_pat=re.compile(r'"?/home/[^"\s]*?/spike_train_output/st_1/[^"\s]*?\.pwl"?')
st2_pat=re.compile(r'"?/home/[^"\s]*?/spike_train_output/st_2/[^"\s]*?\.pwl"?')
patched=[]
for p in root.rglob('*'):
    if not p.is_file(): continue
    try: s=p.read_text(errors='ignore')
    except Exception: continue
    ns=st1_pat.sub('__ST1_PWL__', s); ns=st2_pat.sub('__ST2_PWL__', ns)
    if ns != s: p.write_text(ns); patched.append(str(p))
for item in patched: print('patched', item)
print(f'patched_files={len(patched)}')
PY
python3 - "$TEMPLATE" <<'PY'
import pathlib, re, sys
root=pathlib.Path(sys.argv[1]); input_scs=root/'input.scs'
if not input_scs.is_file(): raise SystemExit(f'ERROR: missing {input_scs}')
param_line=('parameters m2w=3u m2l=200n m3w=2.1u m3l=4u m4w=2.1u m4l=1.05u m5w=2.1u m5l=1.05u '
            'm4wtb=2.1u m4ltb=1.05u m2wtb=2.1u m2ltb=1.05u pw=100u T=1m Vin=0 vmax=1.8 '
            'Vw=0.5 Vthr=0.9 Vtau=1.6 capacitance=6p pwlFile_st2=__ST2_PWL__ pwlFile_st1=__ST1_PWL__')
s=input_scs.read_text(errors='ignore')
ns,n=re.subn(r'parameters\b.*?(?=\s+include\s+")', param_line+'\n', s, count=1, flags=re.S)
if n != 1: raise SystemExit('ERROR: could not replace top-level parameters block in input.scs')
# Insert an ideal zero-volt voltage source between I56's output pin and ground.
# This is the standard non-resistive current probe: it does not add a 1-ohm
# shunt or any deliberate voltage drop. The branch current of VSENSE_I56 is
# then exported as the I56 output current.
ns, n_sense = re.subn(
    r'\bI56\s+\(\s*0\s+Vdd\s+Vin\s+Vtau\s+Vthr\s*\)\s+dynapse1\b',
    'VSENSE_I56 (i56_iout 0) vsource dc=0 type=dc\nI56 (i56_iout Vdd Vin Vtau Vthr) dynapse1',
    ns,
    count=1,
)
if n_sense != 1 and 'VSENSE_I56' not in ns:
    raise SystemExit('ERROR: could not insert VSENSE_I56 current probe before I56')

# Request terminal currents in the PSF. This keeps the current-probe branch
# current available to the OCEAN exporter.
if re.search(r'^saveOptions\s+options\b.*$', ns, flags=re.M):
    ns = re.sub(r'^saveOptions\s+options\b.*$', 'saveOptions options save=allpub currents=all', ns, count=1, flags=re.M)
else:
    ns += '\nsaveOptions options save=allpub currents=all\n'

# Save the two voltage nodes and the current-probe branch current. Different
# Spectre/OCEAN versions expose the current name differently, so the exporter
# also probes several possible names robustly.
ns = re.sub(r'^save\s+.*$', 'save vpre vpre1 VSENSE_I56:p VSENSE_I56:n', ns, count=1, flags=re.M) if re.search(r'^save\s+', ns, flags=re.M) else ns + '\nsave vpre vpre1 VSENSE_I56:p VSENSE_I56:n\n'
input_scs.write_text(ns)
(root/'.designVariables').write_text(param_line+'\n')
block=re.search(r'^saveOptions\s+options\b.*$', ns, flags=re.M)
if not block: raise SystemExit('ERROR: saveOptions was not inserted')
if 'VSENSE_I56' not in ns: raise SystemExit('ERROR: VSENSE_I56 was not inserted into input.scs')
if re.search(r'^save\s+.*VSENSE_I56', ns, flags=re.M) is None: raise SystemExit('ERROR: VSENSE_I56 current probe is not in the save statement')
combined='\n'.join(p.read_text(errors='ignore') for p in root.rglob('*') if p.is_file())
if '__ST1_PWL__' not in combined or '__ST2_PWL__' not in combined: raise SystemExit('ERROR: PWL placeholders missing after parameter patch')
print(f'patched parameters in {input_scs}')
print(f'verified saveOptions: {block.group(0)}')
print('verified ideal current probe: VSENSE_I56 (i56_iout 0) vsource dc=0 type=dc')
print('verified current signal save: VSENSE_I56:p / VSENSE_I56:n')
PY
echo "Imported template into $TEMPLATE"
echo "Template placeholders, parameters, and ideal I56 current-probe saving verified."
