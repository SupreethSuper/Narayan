# ================================================================================
# ModelSim Compilation and Simulation Script - v3 (1-cycle latency testbench)
# ================================================================================
# Usage: vsim -c -do compile_and_sim_v3.do
# ================================================================================

set work_dir ./work
set proj_dir [pwd]

# ================================================================================
# STEP 1: Create and map work library
# ================================================================================
if {[file exists $work_dir]} {
    vdel -all -lib $work_dir
}
vlib $work_dir
vmap work $work_dir

# ================================================================================
# STEP 2: Compile Design and Testbench Files (SystemVerilog mode)
# ================================================================================

puts "╔════════════════════════════════════════════════════════════════╗"
puts "║  Compiling Scratchpad Memory with 1-Cycle Latency (v4)        ║"
puts "╚════════════════════════════════════════════════════════════════╝"
puts ""

# Compile design file
puts "Compiling: scratchpad_memory.sv (with 1-cycle latency)"
vlog -sv -work $work_dir "$proj_dir/scratchpad_memory.sv" 2>&1

# Compile latency-aware testbench
puts "Compiling: tb_scratchpad_memory_v4.sv (1-cycle latency testbench)"
vlog -sv -work $work_dir "$proj_dir/tb_scratchpad_memory_v4.sv" 2>&1

puts ""
puts "Compilation complete!"
puts ""

# ================================================================================
# STEP 3: Simulate the 1-Cycle Latency Testbench
# ================================================================================

puts "╔════════════════════════════════════════════════════════════════╗"
puts "║    Running Simulation - 1-Cycle Latency Testbench (v4)       ║"
puts "╚════════════════════════════════════════════════════════════════╝"
puts ""

# Start simulation with testbench as top-level module
vsim -work $work_dir \
     -t 1ps \
     tb_scratchpad_memory_v4

# Run simulation
run 15000ns

# ================================================================================
# STEP 4: Print final message and exit
# ================================================================================

puts ""
puts "╔════════════════════════════════════════════════════════════════╗"
puts "║                Simulation Complete                            ║"
puts "║           Check transcript output above for results           ║"
puts "╚════════════════════════════════════════════════════════════════╝"
puts ""

exit
