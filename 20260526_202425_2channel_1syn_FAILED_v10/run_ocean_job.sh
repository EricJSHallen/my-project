#!/usr/bin/env bash
set -euo pipefail

job_index="${1:?usage: $0 JOB_INDEX}"

RUN_DIR="/home/s5117909/Documents/thesis/thesis_codebase/thesis_database/20260526_202425_2channel_1syn"
LOG_DIR="/home/s5117909/Documents/thesis/thesis_codebase/thesis_database/20260526_202425_2channel_1syn/logs"
IPC_DIR="/home/s5117909/Documents/thesis/thesis_codebase/thesis_database/20260526_202425_2channel_1syn/ipc_work"
RUN_OCN="/home/s5117909/Documents/thesis/thesis_codebase/thesis_database/20260526_202425_2channel_1syn/ocn/pwl_1synv3.ocn"
OUTPUT_DIR="/home/s5117909/Documents/thesis/thesis_codebase/thesis_database/20260526_202425_2channel_1syn/output_2channel_1syn_data"
SPIKE_ROOT="/home/s5117909/Documents/thesis/thesis_codebase/processing/sim_run_code/spike_train_output"
CADENCE_PROJECT_DIR="/home/s5117909/Documents/thesis/thesis_codebase/thesis_database/20260526_202425_2channel_1syn/cadence_project"
ADE_E_CACHE="/home/s5117909/Documents/thesis/thesis_codebase/thesis_database/20260526_202425_2channel_1syn/support/ade_e.scs"
GLOBAL_NETLIST_DIR="/home/s5117909/simulation/synapsedualinputtb/spectre/schematic/netlist"
NUM_JOBS="4"

jobdir="$IPC_DIR/job$job_index"
projdir="$CADENCE_PROJECT_DIR/job$job_index"
log="$LOG_DIR/ocean_apply_job$job_index.log"

mkdir -p "$jobdir" "$projdir" "$LOG_DIR"

# Copy cached ade_e.scs into every current/future directory containing input.scs.
# This includes the desired per-job project directory and the legacy/global Cadence
# netlist directory if this Cadence environment still uses it despite projectDir.
ade_helper() {
  while true; do
    for root in "$projdir" "$RUN_DIR" "$GLOBAL_NETLIST_DIR"; do
      [ -d "$root" ] || continue
      find "$root" -name input.scs -type f 2>/dev/null | while read -r input; do
        d=$(dirname "$input")
        cp -f "$ADE_E_CACHE" "$d/ade_e.scs" 2>/dev/null || true
      done
      # Also seed obvious netlist dirs before input.scs appears.
      find "$root" -type d \( -name netlist -o -path '*spectre/schematic/netlist' \) 2>/dev/null | while read -r d; do
        cp -f "$ADE_E_CACHE" "$d/ade_e.scs" 2>/dev/null || true
      done
    done
    sleep 0.2
  done
}

ade_helper &
helper_pid=$!
cleanup() {
  kill "$helper_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

cd "$jobdir"

env CAD_NUM_JOBS="$NUM_JOBS"     CAD_JOB_INDEX="$job_index"     CAD_BATCH_EXIT=1     CAD_RUN_DIR="$RUN_DIR"     CAD_OUTPUT_DIR="$OUTPUT_DIR"     CAD_SPIKE_DIR="$SPIKE_ROOT"     CAD_PROJECT_DIR="$projdir"     ADE_E_CACHE="$ADE_E_CACHE"     ocean -nograph -restore "$RUN_OCN" > "$log" 2>&1
