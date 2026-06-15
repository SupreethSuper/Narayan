# scratchpad_memory — OpenLane hardening kit

Self-contained design folder. Point OpenLane v1 at this directory:

```bash
cd $OPENLANE_ROOT
./flow.tcl -design /path/to/project/openlane/scratchpad_memory -tag full_flow
```

## Layout

| File | Purpose |
|---|---|
| `config.tcl` | Full OpenLane config incl. **chip dimensions** (`DIE_AREA` 320×320 µm, core 290×290 µm, 40% density) |
| `base.sdc` | Clock (10 ns), I/O delays, async-reset false path |
| `pin_order.cfg` | Pin placement: clk/rst N, control W, data_in S, data_out E |
| `src/` | RTL snapshot (scratchpad_memory.sv + headers) |
| `netlist/scratchpad_memory.generic.v` | **Netlist #0** — technology-independent yosys netlist (already generated; 834 FFs, 28-level worst path). Good for gate-level sim / sanity diffing. |
| `scripts/gen_netlists.sh` | Generates **Netlist A** (`SYNTH_STRATEGY "AREA 0"`) and **Netlist B** (`"DELAY 0"`), sky130-mapped |
| `scripts/compare_netlists.sh` | Side-by-side area / cell count / worst-slack comparison of A vs B |
| `scripts/run_drc.sh` + `scripts/drc.tcl` | Batch Magic DRC on the final GDS (full rule deck, euclidean), writes violation report, nonzero exit on failure |
| `scripts/run_lvs.sh` + `scripts/extract_spice.tcl` | Magic GDS→SPICE extraction + Netgen LVS vs the powered gate-level netlist |

## Typical flow

```bash
export PDK_ROOT=...; export OPENLANE_ROOT=...

# 1. Two netlists, pick a winner
./scripts/gen_netlists.sh
./scripts/compare_netlists.sh        # smaller area vs better wns

# 2. Set the winning SYNTH_STRATEGY in config.tcl, run full flow
cd $OPENLANE_ROOT && ./flow.tcl -design <this dir> -tag full_flow

# 3. Signoff
./scripts/run_drc.sh runs/full_flow/results/final/gds/scratchpad_memory.gds
./scripts/run_lvs.sh runs/full_flow/results/final/gds/scratchpad_memory.gds \
                     runs/full_flow/results/final/verilog/gl/scratchpad_memory.v
```

## Notes

- Sized for the current 5×5×32 config (834 FFs, ~33k µm² std-cell area). If you
  grow `NAR_MAT_ROWS/COLS`, re-scale `DIE_AREA` — FF count scales as ROWS×COLS×32.
- Configured as a **macro** (`DESIGN_IS_CORE 0`, routing capped at met4) since the
  LEF/DEF are integrated at chip top. Flip the flags in config.tcl for standalone.
- The 28-level worst path is the `wr_addr / 5` and `% 5` divider. If DELAY
  strategy still misses timing, replace div/mod with a small row/col counter or
  make COLS a power of two (8) and slice address bits.
