#!/usr/bin/env bash
set -u -o pipefail

JOB_INDEX="${1:?usage: run_spectre_worker.sh JOB_INDEX}"
RUN_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$RUN_DIR/RUNINFO.txt"
# shellcheck disable=SC1091
source "$RUN_DIR/setup_spectre_env.sh"

TEMPLATE="$RUN_DIR/netlist_template/raw"
LOG="$RUN_DIR/logs/spectre_worker_${JOB_INDEX}.log"
STATE="$RUN_DIR/worker_state/job_${JOB_INDEX}.state"
ASSIGNED_TSV="$RUN_DIR/worker_state/job_${JOB_INDEX}_cases.tsv"
DONE_FILE="$RUN_DIR/worker_state/job_${JOB_INDEX}_done.txt"
FAILED_FILE="$RUN_DIR/worker_state/job_${JOB_INDEX}_failed.txt"
mkdir -p "$RUN_DIR/logs" "$RUN_DIR/worker_state"

{
  echo "worker=$JOB_INDEX start=$(date -Is)"
  echo "SPECTRE_CMD=${SPECTRE_CMD:-unset}"
  echo "runtime_check:"
  check_spectre_runtime || true
} > "$LOG" 2>&1

if ! spectre_runtime_ok; then
  echo "FAILED: Spectre runtime unresolved. Source ./setup_spectre_env.sh and rerun ./refresh_spectre_runtime.sh." | tee -a "$LOG"
  exit 2
fi

if [ ! -f "$TEMPLATE/input.scs" ]; then
  echo "FAILED: missing template $TEMPLATE/input.scs" | tee -a "$LOG"
  exit 1
fi

python3 "$RUN_DIR/select_cases.py" "$RUN_DIR/cases.csv" "$JOB_INDEX" "$NUM_JOBS" > "$ASSIGNED_TSV"
echo "assigned_cases=$(wc -l < "$ASSIGNED_TSV")" | tee -a "$LOG" > "$STATE"

export_case_outputs() {
  local case_dir="$1"
  local ocn="$case_dir/export_output_signals.ocn"
  local out="$case_dir/output_signals.txt"
  local elog="$case_dir/export_output_signals.log"

  rm -f "$out" "$elog" "$ocn"
  cat > "$ocn" <<OCN
simulator('spectre)
openResults("$case_dir/psf")
selectResult('tran)
ocnPrint(
  ?output "$out"
  ?numberNotation 'scientific
  ?numSpaces 1
  v("vpre1")
  v("vpre")
  getData("I56:1")
)
exit()
OCN

  if command -v ocean >/dev/null 2>&1; then
    ocean -nograph -restore "$ocn" > "$elog" 2>&1
  elif command -v virtuoso >/dev/null 2>&1; then
    virtuoso -nograph -restore "$ocn" > "$elog" 2>&1
  else
    echo "No ocean or virtuoso command found for PSF export" > "$elog"
    return 127
  fi

  [ -s "$out" ]
}

while IFS=$'\t' read -r case_id run_name st1_file st2_file case_dir; do
  {
    echo "========== case_id=$case_id run_name=$run_name =========="
    mkdir -p "$case_dir"

    if [ -s "$case_dir/output_signals.txt" ]; then
      echo "SKIP existing output_signals.txt"
      continue
    fi

    rm -rf "$case_dir/netlist" "$case_dir/psf"
    cp -a "$TEMPLATE" "$case_dir/netlist"

    python3 - "$case_dir/netlist" "$st1_file" "$st2_file" <<'PY'
import pathlib
import sys
root = pathlib.Path(sys.argv[1])
st1 = sys.argv[2]
st2 = sys.argv[3]
for p in root.rglob('*'):
    if not p.is_file():
        continue
    try:
        s = p.read_text(errors='ignore')
    except Exception:
        continue
    ns = s.replace('__ST1_PWL__', st1).replace('__ST2_PWL__', st2)
    if ns != s:
        p.write_text(ns)
PY

    ( cd "$case_dir/netlist" || exit 1
      "$SPECTRE_CMD" input.scs +escchars +log "$case_dir/spectre.out" -format psfxl -raw "$case_dir/psf"
    )
    rc=$?
    if [ "$rc" -ne 0 ]; then
      echo "FAILED case_id=$case_id spectre_rc=$rc"
      echo "case_id=$case_id run_name=$run_name stage=spectre rc=$rc" >> "$FAILED_FILE"
      continue
    fi

    if ! export_case_outputs "$case_dir"; then
      erc=$?
      echo "FAILED case_id=$case_id export_rc=$erc"
      echo "case_id=$case_id run_name=$run_name stage=export rc=$erc" >> "$FAILED_FILE"
      tail -80 "$case_dir/export_output_signals.log" 2>/dev/null || true
      continue
    fi

    echo "DONE case_id=$case_id"
    echo "$case_id" >> "$DONE_FILE"
  } >> "$LOG" 2>&1
done < "$ASSIGNED_TSV"

echo "worker=$JOB_INDEX end=$(date -Is)" >> "$LOG"
