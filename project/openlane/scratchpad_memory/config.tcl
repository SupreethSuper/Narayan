# =============================================================================
# OpenLane (v1) configuration — scratchpad_memory (5x5x32, 834 FFs)
# Run:  ./flow.tcl -design <this directory> -tag full_flow
# =============================================================================

set ::env(DESIGN_NAME) scratchpad_memory

# --- RTL -------------------------------------------------------------------
set ::env(VERILOG_FILES)        "$::env(DESIGN_DIR)/src/scratchpad_memory.sv"
set ::env(VERILOG_INCLUDE_DIRS) "$::env(DESIGN_DIR)/src"

# --- Clock -----------------------------------------------------------------
set ::env(CLOCK_PORT)    "clk"
set ::env(CLOCK_NET)     "clk"
set ::env(CLOCK_PERIOD)  "10.0"        ;# 100 MHz, matches narayan.sdc
set ::env(BASE_SDC_FILE) "$::env(DESIGN_DIR)/base.sdc"

# --- Chip dimensions ---------------------------------------------------------
# Sizing rationale: ~834 DFFs (~26 um^2 each w/ sky130_fd_sc_hd__dfrtp_1)
# + ~1.9k combinational cells  =>  ~33,000 um^2 of std-cell area.
# At 40% placement density the core needs ~82,500 um^2  =>  ~290 um square.
set ::env(FP_SIZING)         absolute
set ::env(DIE_AREA)          "0 0 320 320"
set ::env(CORE_AREA)         "15 15 305 305"
set ::env(PL_TARGET_DENSITY) 0.40
set ::env(FP_CORE_UTIL)      40        ;# only used if FP_SIZING is relative

# --- Macro vs. chip core -----------------------------------------------------
# This block is hardened as a MACRO (LEF/DEF consumed by the chip top).
# If you ever harden it as the standalone chip core, set DESIGN_IS_CORE 1
# and FP_PDN_CORE_RING 1, and remove the RT_MAX_LAYER cap.
set ::env(DESIGN_IS_CORE)   0
set ::env(FP_PDN_CORE_RING) 0
set ::env(RT_MAX_LAYER)     {met4}

# --- Synthesis ---------------------------------------------------------------
# Overridden by scripts/gen_netlists.sh for the AREA-vs-DELAY comparison.
set ::env(SYNTH_STRATEGY)   "AREA 0"
set ::env(SYNTH_MAX_FANOUT) 10

# --- Pins --------------------------------------------------------------------
set ::env(FP_PIN_ORDER_CFG) "$::env(DESIGN_DIR)/pin_order.cfg"

# --- Signoff -----------------------------------------------------------------
set ::env(RUN_MAGIC_DRC)   1
set ::env(RUN_KLAYOUT_XOR) 0
set ::env(RUN_LVS)         1
