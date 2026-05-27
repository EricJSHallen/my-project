#!/usr/bin/env bash
set -u -o pipefail
JOB_INDEX="${1:?usage: run_spectre_worker.sh JOB_INDEX}"
RUN_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RUN_DIR/RUNINFO.txt"
source "$RUN_DIR/setup_spectre_env.sh"
TEMPLATE="$RUN_DIR/netlist_template/raw"
LOG="$RUN_DIR/logs/spectre_worker_${JOB_INDEX}.log"
STATE="$RUN_DIR/worker_state/job_${JOB_INDEX}.state"
ASSIGNED_TSV="$RUN_DIR/worker_state/job_${JOB_INDEX}_cases.tsv"
EXPORT_OCN="$RUN_DIR/ocn/export_psf_to_txt_v1.ocn"
mkdir -p "$RUN_DIR/logs" "$RUN_DIR/worker_state"
{
  echo "worker=$JOB_INDEX start=$(date -Is)"
  echo "SPECTRE_BIN=$SPECTRE_BIN"
  echo "LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-}"
  echo "runtime_missing_libs:"
  check_spectre_runtime
} > "$LOG" 2>&1
if [ ! -f "$TEMPLATE/input.scs" ]; then
  echo "ERROR: missing $TEMPLATE/input.scs" | tee -a "$LOG"
  exit 1
fi
python3 "$RUN_DIR/select_cases.py" "$RUN_DIR/cases.csv" "$JOB_INDEX" "$NUM_JOBS" > "$ASSIGNED_TSV"
echo "assigned_cases=$(wc -l < "$ASSIGNED_TSV")" | tee -a "$LOG" > "$STATE"
while IFS=$'\t' read -r case_id run_name st1_file st2_file case_dir; do
  {
    echo "========== case_id=$case_id run_name=$run_name =========="
    if [ -f "$case_dir/output_signals.txt" ]; then
      echo "SKIP existing output_signals.txt"
      continue
    fi
    rm -rf "$case_dir/netlist" "$case_dir/psf"
    mkdir -p "$case_dir/netlist"
    cp -a "$TEMPLATE"/. "$case_dir/netlist"/
    [ -f "$RUN_DIR/support/ade_e.scs" ] && cp -f "$RUN_DIR/support/ade_e.scs" "$case_dir/netlist/ade_e.scs"
    python3 - "$case_dir/netlist" "$st1_file" "$st2_file" <<'PY'
import pathlib, sys
root=pathlib.Path(sys.argv[1]); st1=sys.argv[2]; st2=sys.argv[3]
changed=0
for p in root.rglob('*'):
    if not p.is_file():
        continue
    try:
        s=p.read_text(errors='ignore')
    except Exception:
        continue
    ns=s.replace('__ST1_PWL__', st1).replace('__ST2_PWL__', st2)
    if ns != s:
        p.write_text(ns); changed += 1
print(f"patched_files={changed}")
PY
    ( cd "$case_dir/netlist" && "$SPECTRE_BIN" input.scs +escchars +log "$case_dir/spectre.out" -format psfxl -raw "$case_dir/psf" )
    rc=$?
    if [ "$rc" -ne 0 ]; then
      echo "FAILED case_id=$case_id run_name=$run_name reason=spectre_rc_$rc"
      continue
    fi
    CAD_CASE_DIR="$case_dir" CAD_BATCH_EXIT=1 ocean -nograph -restore "$EXPORT_OCN" > "$case_dir/export_ocean.log" 2>&1
    rc=$?
    if [ "$rc" -ne 0 ]; then
      echo "FAILED case_id=$case_id run_name=$run_name reason=export_rc_$rc"
      continue
    fi
    [ -f "$case_dir/output_signals.txt" ] && echo "DONE $run_name" || echo "FAILED case_id=$case_id run_name=$run_name reason=no_output_signals"
  } >> "$LOG" 2>&1
done < "$ASSIGNED_TSV"
echo "worker=$JOB_INDEX end=$(date -Is)" >> "$STATE"
