#!/usr/bin/env bash
# Usage: ./run_drc.sh <final.gds>
set -euo pipefail
: "${PDK_ROOT:?set PDK_ROOT to your PDK install}"
PDK=${PDK:-sky130A}

export DESIGN_NAME=${DESIGN_NAME:-scratchpad_memory}
export GDS_PATH=${1:?usage: run_drc.sh <final.gds>}
export OUT_DIR=${OUT_DIR:-$(pwd)/drc_out}

magic -dnull -noconsole \
  -rcfile "$PDK_ROOT/$PDK/libs.tech/magic/$PDK.magicrc" \
  "$(dirname "$0")/drc.tcl"
