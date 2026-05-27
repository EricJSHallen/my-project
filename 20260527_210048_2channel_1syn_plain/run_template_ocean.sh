#!/usr/bin/env bash
set -euo pipefail
RUN_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$RUN_DIR/RUNINFO.txt"
mkdir -p "$RUN_DIR/logs" "$RUN_DIR/ocn"
cat > "$RUN_DIR/ocn/template_netlist.ocn" <<'OCN'
simulator('spectre)
design("sebastian_thesis_pilot" "synapsedualinputtb" "schematic")
resultsDir(strcat(getShellEnvVar("RUN_DIR") "/netlist_template/raw"))
analysis('tran ?stop "0.5s")
desVar("pwlFile_st1" strcat(getShellEnvVar("REPO_ROOT") "/processing/sim_run_code/spike_train_output/st_1/31_hz/trial_2.pwl"))
desVar("pwlFile_st2" strcat(getShellEnvVar("REPO_ROOT") "/processing/sim_run_code/spike_train_output/st_2/451_hz/trial_2.pwl"))
save('i "/I56/Iout")
save('v "/vpre")
save('v "/vpre1")
createNetlist(?recreateAll t)
exit()
OCN
export RUN_DIR REPO_ROOT
if command -v ocean >/dev/null 2>&1; then
  ocean -nograph -restore "$RUN_DIR/ocn/template_netlist.ocn" > "$RUN_DIR/logs/template_netlist.log" 2>&1
else
  echo "ocean not found in this shell. Use ciw_template_command.il in CIW instead."
  exit 1
fi
