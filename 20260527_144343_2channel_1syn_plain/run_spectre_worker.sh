#!/usr/bin/env bash
set -euo pipefail
JOB_INDEX="${1:?usage: run_spectre_worker.sh JOB_INDEX}"
RUN_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RUN_DIR/RUNINFO.txt"
NUM_JOBS="${NUM_JOBS:?}"
TEMPLATE="$RUN_DIR/netlist_template/raw"
CASES_CSV="$RUN_DIR/cases.csv"
LOG="$RUN_DIR/logs/spectre_worker_${JOB_INDEX}.log"
STATE="$RUN_DIR/worker_state/job_${JOB_INDEX}.state"
EXPORT_OCN="$RUN_DIR/ocn/export_psf_to_txt_v1.ocn"

[ -d "$TEMPLATE" ] || { echo "ERROR: missing template $TEMPLATE. Run ./import_template.sh first." >&2; exit 1; }

mkdir -p "$RUN_DIR/worker_state"
echo "worker=$JOB_INDEX start=$(date -Is)" > "$STATE"

python3 "$RUN_DIR/select_cases.py" "$CASES_CSV" "$JOB_INDEX" "$NUM_JOBS" | while IFS=$'\t' read -r case_id run_name st1_file st2_file case_dir; do
  {
    echo "========== case_id=$case_id run_name=$run_name =========="
    echo "case_dir=$case_dir"
    mkdir -p "$case_dir"

    if [ -f "$case_dir/output_signals.txt" ]; then
      echo "SKIP existing output_signals.txt"
      exit 0
    fi

    rm -rf "$case_dir/netlist" "$case_dir/psf"
    mkdir -p "$case_dir/netlist"
    cp -a "$TEMPLATE"/. "$case_dir/netlist"/

    # Ensure ade_e.scs is local, not dependent on a shared global netlist directory.
    if [ -f "$RUN_DIR/support/ade_e.scs" ]; then
      cp -f "$RUN_DIR/support/ade_e.scs" "$case_dir/netlist/ade_e.scs"
    fi

    python3 - "$case_dir/netlist" "$st1_file" "$st2_file" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
st1 = sys.argv[2]
st2 = sys.argv[3]
changed = 0
for p in root.rglob("*"):
    if not p.is_file():
        continue
    try:
        s = p.read_text(errors="ignore")
    except Exception:
        continue
    ns = s.replace("__ST1_PWL__", st1).replace("__ST2_PWL__", st2)
    # Also handle common parameter assignments if placeholders were not detected.
    ns = re.sub(r'(pwlFile_st1\s*=\s*)"[^"]*"', r'\1"' + st1 + '"', ns)
    ns = re.sub(r'(pwlFile_st2\s*=\s*)"[^"]*"', r'\1"' + st2 + '"', ns)
    if ns != s:
        p.write_text(ns)
        changed += 1
print(f"patched_files={changed}")
PY

    cd "$case_dir/netlist"
    if [ ! -f input.scs ]; then
      echo "ERROR: input.scs missing in $case_dir/netlist"
      exit 2
    fi

    ${SPECTRE_BIN:-spectre} input.scs +escchars +log "$case_dir/spectre.out" -format psfxl -raw "$case_dir/psf"

    CAD_CASE_DIR="$case_dir" CAD_BATCH_EXIT=1 ocean -nograph -restore "$EXPORT_OCN" > "$case_dir/export_ocean.log" 2>&1

    if [ -f "$case_dir/output_signals.txt" ]; then
      echo "DONE $run_name"
    else
      echo "ERROR: Spectre finished but output_signals.txt was not created"
      exit 3
    fi
  } >> "$LOG" 2>&1 || {
    echo "FAILED case_id=$case_id run_name=$run_name case_dir=$case_dir" >> "$LOG"
  }
done

echo "worker=$JOB_INDEX end=$(date -Is)" >> "$STATE"

# The Python command above emits tab-separated case rows owned by this worker.
# It is placed at the end of this file only to keep the worker self-contained.

