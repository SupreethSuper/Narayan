#!/usr/bin/env bash
# =============================================================================
# run_lvs.sh — layout-vs-schematic with Magic (extraction) + Netgen (compare)
#
# Usage:
#   ./run_lvs.sh <final.gds> <gate_level_netlist.v>
#
#   <final.gds>             runs/<tag>/results/final/gds/scratchpad_memory.gds
#   <gate_level_netlist.v>  runs/<tag>/results/final/verilog/gl/scratchpad_memory.v
#                           (use the powered GL netlist — it has VPWR/VGND)
#
# Result: lvs_out/scratchpad_memory.lvs.rpt  (look for "Circuits match uniquely")
# =============================================================================
set -euo pipefail
: "${PDK_ROOT:?set PDK_ROOT to your PDK install}"
PDK=${PDK:-sky130A}

export DESIGN_NAME=${DESIGN_NAME:-scratchpad_memory}
export GDS_PATH=${1:?usage: run_lvs.sh <final.gds> <gl_netlist.v>}
NETLIST=${2:?usage: run_lvs.sh <final.gds> <gl_netlist.v>}
export OUT_DIR=${OUT_DIR:-$(pwd)/lvs_out}
mkdir -p "$OUT_DIR"

# 1) GDS -> SPICE
magic -dnull -noconsole \
  -rcfile "$PDK_ROOT/$PDK/libs.tech/magic/$PDK.magicrc" \
  "$(dirname "$0")/extract_spice.tcl"

# 2) SPICE (layout) vs Verilog (schematic)
netgen -batch lvs \
  "$OUT_DIR/$DESIGN_NAME.spice $DESIGN_NAME" \
  "$NETLIST $DESIGN_NAME" \
  "$PDK_ROOT/$PDK/libs.tech/netgen/${PDK}_setup.tcl" \
  "$OUT_DIR/$DESIGN_NAME.lvs.rpt" -json

echo "----------------------------------------"
grep -E "Circuits match|Netlists do not match|match uniquely" \
  "$OUT_DIR/$DESIGN_NAME.lvs.rpt" || true
echo "Full report: $OUT_DIR/$DESIGN_NAME.lvs.rpt"
