# sim_scratchpad.do
# ModelSim/Questa simulation script for scratchpad_memory

# ── Clean up and create work library ──────────────────────────────────────────
if {[file exists work]} { vdel -lib work -all }
vlib work
vmap work work

# ── Compile design, then testbench (.vh files resolved via +incdir) ───────────
vlog -sv -work work +incdir+. scratchpad_memory.sv
vlog -sv -work work +incdir+. tb_scratchpad_memoryv5.sv

# ── Simulate ──────────────────────────────────────────────────────────────────
vsim -t 1ps work.tb_scratchpad_memory_v5



# ── Run ───────────────────────────────────────────────────────────────────────
run -all

# ── Tidy up view ──────────────────────────────────────────────────────────────
wave zoom full
