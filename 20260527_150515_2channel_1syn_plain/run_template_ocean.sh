#!/usr/bin/env bash
set -euo pipefail
cd "/home/s5117909/Documents/thesis/thesis_codebase/thesis_database/20260527_150515_2channel_1syn_plain"
export CAD_REPO_DIR="/home/s5117909/Documents/thesis/thesis_codebase"
export CAD_SPIKE_DIR="/home/s5117909/Documents/thesis/thesis_codebase/processing/sim_run_code/spike_train_output"
export CAD_TEMPLATE_DIR="/home/s5117909/Documents/thesis/thesis_codebase/thesis_database/20260527_150515_2channel_1syn_plain/template_ocean_result"
export CAD_PROJECT_DIR="/home/s5117909/Documents/thesis/thesis_codebase/thesis_database/20260527_150515_2channel_1syn_plain/template_project"
export CAD_BATCH_EXIT=1

echo "Running one OCEAN/Virtuoso template generation pass..."
ocean -nograph -restore "/home/s5117909/Documents/thesis/thesis_codebase/thesis_database/20260527_150515_2channel_1syn_plain/ocn/make_spectre_template_v1.ocn" > "/home/s5117909/Documents/thesis/thesis_codebase/thesis_database/20260527_150515_2channel_1syn_plain/logs/template_ocean.log" 2>&1
