#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck disable=SC1091
source ./RUNINFO.txt

mkdir -p ocn logs netlist_template/raw
cat > ocn/template_netlist.ocn <<'OCN'
; Template-generation OCEAN script.
; Run this inside a Cadence/OCEAN-capable shell or paste ciw_template_command.il in CIW.
simulator('spectre)
design("sebastian_thesis_pilot" "synapsedualinputtb" "schematic")
resultsDir(strcat(getShellEnvVar("RUN_DIR") "/netlist_template/raw"))
envOption('analysisOrder list("tran"))
analysis('tran ?stop "0.5s")
desVar("pwlFile_st1" strcat(getShellEnvVar("REPO_ROOT") "/processing/sim_run_code/spike_train_output/st_1/31_hz/trial_2.pwl"))
desVar("pwlFile_st2" strcat(getShellEnvVar("REPO_ROOT") "/processing/sim_run_code/spike_train_output/st_2/451_hz/trial_2.pwl"))
save('v "vpre1")
save('v "vpre")
save('i "I56:1")
createNetlist(?recreateAll t)
exit()
OCN

export RUN_DIR REPO_ROOT
if command -v ocean >/dev/null 2>&1; then
  echo "Running one OCEAN/Virtuoso template generation pass..."
  ocean -nograph -restore ocn/template_netlist.ocn > logs/template_netlist.log 2>&1 || {
    echo "Template generation failed. Check logs/template_netlist.log"
    exit 1
  }
else
  echo "ocean not found in this shell. Use ciw_template_command.il in CIW instead."
  exit 1
fi
