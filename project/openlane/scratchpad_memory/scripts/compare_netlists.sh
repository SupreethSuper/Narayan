#!/usr/bin/env bash
# =============================================================================
# compare_netlists.sh — area & timing comparison of the two synthesis runs
# Run after scripts/gen_netlists.sh.
# =============================================================================
set -uo pipefail
DESIGN_DIR="$(cd "$(dirname "$0")/.." && pwd)"

for tag in netlist_area netlist_delay; do
    run="$DESIGN_DIR/runs/$tag"
    echo "=============================================="
    echo " Run: $tag"
    echo "=============================================="
    if [ ! -d "$run" ]; then echo "  (missing — run gen_netlists.sh first)"; continue; fi

    # Cell count + chip area from the yosys stat report
    stat_rpt=$(ls "$run"/reports/synthesis/*stat* 2>/dev/null | head -1)
    [ -n "${stat_rpt:-}" ] && grep -E "Number of cells|Chip area" "$stat_rpt" | sed 's/^/  /'

    # Worst slack from the synthesis STA report
    sta_rpt=$(ls "$run"/reports/synthesis/*sta* 2>/dev/null | head -1)
    [ -n "${sta_rpt:-}" ] && grep -E "wns|worst slack|slack \(" "$sta_rpt" | head -4 | sed 's/^/  /'

    # Flow metrics, if present
    [ -f "$run/reports/metrics.csv" ] && \
      python3 - "$run/reports/metrics.csv" <<'EOF'
import csv, sys
with open(sys.argv[1]) as f:
    row = next(csv.DictReader(f))
for k in ("synth_cell_count", "CellPer_mm^2", "wns", "tns", "AREA_0"):
    if k in row: print(f"  {k}: {row[k]}")
EOF
done

echo
echo "Pick: smaller 'Chip area' => cheaper; larger (less negative) wns => faster."
echo "To harden with the winner, set SYNTH_STRATEGY in config.tcl and run the full flow."
