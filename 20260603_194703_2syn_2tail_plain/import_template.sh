#!/usr/bin/env bash
set -euo pipefail
RUN_DIR="$(cd "$(dirname "$0")" && pwd -P)"
# shellcheck disable=SC1090
source "$RUN_DIR/RUNINFO.txt"
TEMPLATE="$RUN_DIR/netlist_template/raw"
SRC="${NETLIST_SOURCE:-/home/s5117909/simulation/dynapsetb1/spectre/schematic/netlist}"
[[ -f "$SRC/input.scs" ]] || { echo "ERROR: cannot find template input.scs at $SRC/input.scs" >&2; exit 1; }
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
    print('patched PWL placeholder', item)
print(f'pwl_placeholder_patched_files={len(patched)}')
PY
python3 - "$TEMPLATE" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
input_scs = root / 'input.scs'
if not input_scs.is_file():
    raise SystemExit(f'ERROR: missing {input_scs}')
param_line = (
    'parameters m2w=3u m2l=200n m3w=2.1u m3l=4u m4w=2.1u m4l=1.05u m5w=2.1u m5l=1.05u '
    'm4wtb=2.1u m4ltb=1.05u m2wtb=2.1u m2ltb=1.05u pw=100u T=1m Vin=0 vmax=1.8 '
    'Vw=0.5 Vthr=0.9 Vtau=1.6 capacitance=6p pwlFile_st2=__ST2_PWL__ pwlFile_st1=__ST1_PWL__'
)
s = input_scs.read_text(errors='ignore')
ns, n = re.subn(r'parameters\b.*?(?=\s+include\s+")', param_line + '\n', s, count=1, flags=re.S)
if n != 1:
    raise SystemExit('ERROR: could not replace top-level parameters block in input.scs')

# Insert ideal zero-volt current probes on I172/Iout and I56/Iout when the instance
# line has the common dynapse1 form. This does not add a 1-ohm shunt.
probe_specs = [
    ('I172', 'VSENSE_I172', 'i172_iout'),
    ('I56',  'VSENSE_I56',  'i56_iout'),
]
for inst, sense, node in probe_specs:
    if sense in ns:
        continue
    # Preserve every original terminal after the Iout terminal. This handles the
    # two-synapse testbench where I56 uses Vin but I172 uses Vin1:
    #   I56  (0 Vdd Vin  Vtau Vthr) dynapse1
    #   I172 (0 Vdd Vin1 Vtau Vthr) dynapse1
    pat = rf'\b{inst}\s+\(\s*0\s+([^)]*?)\)\s+dynapse1\b'
    repl = rf'{sense} ({node} 0) vsource dc=0 type=dc\n{inst} ({node} \1) dynapse1'
    ns, changed = re.subn(pat, repl, ns, count=1)
    if changed == 0:
        print(f'WARNING: could not insert {sense}; exporter will try original {inst}/Iout current names.')
    else:
        print(f'inserted ideal current probe {sense}')

if re.search(r'^saveOptions\s+options\b.*$', ns, flags=re.M):
    ns = re.sub(r'^saveOptions\s+options\b.*$', 'saveOptions options save=allpub currents=all', ns, count=1, flags=re.M)
else:
    ns += '\nsaveOptions options save=allpub currents=all\n'

save_line = 'save vpre vpre1 VSENSE_I172:p VSENSE_I172:n VSENSE_I56:p VSENSE_I56:n I172:Iout I56:Iout'
if re.search(r'^save\s+', ns, flags=re.M):
    ns = re.sub(r'^save\s+.*$', save_line, ns, count=1, flags=re.M)
else:
    ns += '\n' + save_line + '\n'

ns = re.sub(r'\bstrobeperiod\s*=\s*\S+', '', ns)
if 'strobeperiod' in ns.lower():
    raise SystemExit('ERROR: strobeperiod still present after removal')
input_scs.write_text(ns)
(root / '.designVariables').write_text(param_line + '\n')
combined = '\n'.join(p.read_text(errors='ignore') for p in root.rglob('*') if p.is_file())
if '__ST1_PWL__' not in combined or '__ST2_PWL__' not in combined:
    raise SystemExit('ERROR: PWL placeholders missing after parameter patch')
print(f'patched parameters in {input_scs}')
for required_probe in ('VSENSE_I172', 'VSENSE_I56'):
    if required_probe not in ns:
        raise SystemExit(f'ERROR: required ideal current probe missing after patch: {required_probe}')
print('verified saveOptions options save=allpub currents=all')
print('verified ideal current probes: VSENSE_I172 VSENSE_I56')
print('verified output columns: iout_172 iout_56 vpre vpre1')
print('verified no transient strobeperiod: full adaptive-output data will be exported')
PY
echo "Imported template into $TEMPLATE"
echo "Template placeholders, parameters, saveOptions, and two-current export support verified."
