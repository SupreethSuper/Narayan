#!/usr/bin/env bash
# =============================================================================
# gen_netlists.sh — produce TWO sky130-mapped netlists for comparison
#
#   Netlist A: SYNTH_STRATEGY "AREA 0"   (smallest)
#   Netlist B: SYNTH_STRATEGY "DELAY 0"  (fastest)
#
# Usage (from your OpenLane v1 checkout):
#   export OPENLANE_ROOT=/path/to/OpenLane
#   ./scripts/gen_netlists.sh
#
# Netlists land in:
#   <design_dir>/runs/netlist_area/results/synthesis/scratchpad_memory.v
#   <design_dir>/runs/netlist_delay/results/synthesis/scratchpad_memory.v
#
# Then: ./scripts/compare_netlists.sh   to see which one wins.
# =============================================================================
set -euo pipefail
: "${OPENLANE_ROOT:?set OPENLANE_ROOT to your OpenLane v1 checkout}"

DESIGN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$OPENLANE_ROOT"

echo "==> Netlist A (area-optimized)"
./flow.tcl -design "$DESIGN_DIR" -tag netlist_area  -overwrite -to synthesis \
  -override_env SYNTH_STRATEGY="AREA 0"

echo "==> Netlist B (delay-optimized)"
./flow.tcl -design "$DESIGN_DIR" -tag netlist_delay -overwrite -to synthesis \
  -override_env SYNTH_STRATEGY="DELAY 0"

echo
echo "Done. Netlists:"
ls -l "$DESIGN_DIR"/runs/netlist_*/results/synthesis/*.v
