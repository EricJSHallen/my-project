#!/usr/bin/env bash
set -u -o pipefail
JOB_INDEX="${1:?usage: run_spectre_worker.sh JOB_INDEX}"
RUN_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RUN_DIR/RUNINFO.txt"
source "$RUN_DIR/setup_spectre_env.sh"

TEMPLATE="$RUN_DIR/netlist_template/raw"
CASES_CSV="$RUN_DIR/cases.csv"
LOG="$RUN_DIR/logs/spectre_worker_${JOB_INDEX}.log"
STATE="$RUN_DIR/worker_state/job_${JOB_INDEX}.state"
EXPORT_OCN="$RUN_DIR/ocn/export_psf_to_txt_v1.ocn"
ASSIGNED_TSV="$RUN_DIR/worker_state/job_${JOB_INDEX}_cases.tsv"

mkdir -p "$RUN_DIR/worker_state" "$RUN_DIR/logs"
echo "worker=$JOB_INDEX start=$(date -Is)" > "$STATE"
echo "SPECTRE_BIN=$SPECTRE_BIN" > "$LOG"
echo "LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-}" >> "$LOG"

if [ ! -d "$TEMPLATE" ]; then
  echo "ERROR: missing template $TEMPLATE. Run ./import_template.sh first." | tee -a "$LOG" >&2
  exit 1
fi

python3 "$RUN_DIR/select_cases.py" "$CASES_CSV" "$JOB_INDEX" "$NUM_JOBS" > "$ASSIGNED_TSV"
total_assigned="$(wc -l < "$ASSIGNED_TSV")"
echo "assigned_cases=$total_assigned" >> "$STATE"
echo "assigned_cases=$total_assigned" >> "$LOG"

while IFS=$'\t' read -r case_id run_name st1_file st2_file case_dir; do
  {
    echo "========== case_id=$case_id run_name=$run_name =========="
    echo "case_dir=$case_dir"
    mkdir -p "$case_dir"

    if [ -f "$case_dir/output_signals.txt" ]; then
      echo "SKIP existing output_signals.txt"
      continue
    fi

    rm -rf "$case_dir/netlist" "$case_dir/psf"
    mkdir -p "$case_dir/netlist"
    cp -a "$TEMPLATE"/. "$case_dir/netlist"/

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
    ns = re.sub(r'(pwlFile_st1\s*=\s*)"[^"]*"', r'\1"' + st1 + '"', ns)
    ns = re.sub(r'(pwlFile_st2\s*=\s*)"[^"]*"', r'\1"' + st2 + '"', ns)
    if ns != s:
        p.write_text(ns)
        changed += 1
print(f"patched_files={changed}")
PY

    if [ ! -f "$case_dir/netlist/input.scs" ]; then
      echo "FAILED case_id=$case_id run_name=$run_name case_dir=$case_dir reason=missing_input_scs"
      continue
    fi

    (
      cd "$case_dir/netlist"
      "$SPECTRE_BIN" input.scs +escchars +log "$case_dir/spectre.out" -format psfxl -raw "$case_dir/psf"
    )
    spectre_rc=$?
    if [ "$spectre_rc" -ne 0 ]; then
      echo "FAILED case_id=$case_id run_name=$run_name case_dir=$case_dir reason=spectre_rc_$spectre_rc"
      continue
    fi

    CAD_CASE_DIR="$case_dir" CAD_BATCH_EXIT=1 ocean -nograph -restore "$EXPORT_OCN" > "$case_dir/export_ocean.log" 2>&1
    export_rc=$?
    if [ "$export_rc" -ne 0 ]; then
      echo "FAILED case_id=$case_id run_name=$run_name case_dir=$case_dir reason=export_rc_$export_rc"
      continue
    fi

    if [ -f "$case_dir/output_signals.txt" ]; then
      echo "DONE $run_name"
    else
      echo "FAILED case_id=$case_id run_name=$run_name case_dir=$case_dir reason=no_output_signals"
    fi
  } >> "$LOG" 2>&1
done < "$ASSIGNED_TSV"

echo "worker=$JOB_INDEX end=$(date -Is)" >> "$STATE"
