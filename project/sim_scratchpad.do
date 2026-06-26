# sim_scratchpad.do
# ModelSim/Questa simulation script for scratchpad_memory

# ── Clean up and create work library ──────────────────────────────────────────
if {[file exists work]} { vdel -lib work -all }
vlib work
vmap work work

# ── Compile design, then testbench (.vh files resolved via +incdir) ───────────
#vlog -sv -work work +incdir+. narayan_bdf.v
vlog -sv -work work +incdir+. scratchpad_memory.sv
#vlog -sv -work work +incdir+. scheduler.sv
#vlog -sv -work work +incdir+. tb_narayan_bdf.sv
vlog -sv -work work +incdir+. tb_scratchpad_memoryv10.sv

# ── Simulate ──────────────────────────────────────────────────────────────────
vsim -t 1ps work.tb_scratchpad_memoryv10



# ── Run ───────────────────────────────────────────────────────────────────────
run -all
quit -f
