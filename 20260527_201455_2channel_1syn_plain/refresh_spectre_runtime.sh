#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# This script intentionally only re-sources the generated environment and reports status.
# It is kept for compatibility with the older workflow.
# shellcheck disable=SC1091
source ./setup_spectre_env.sh
check_spectre_runtime || true
