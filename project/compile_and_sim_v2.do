# ================================================================================
# ModelSim Compilation and Simulation Script - v2 (FSM-based testbench)
# ================================================================================
# Usage: vsim -c -do compile_and_sim_v2.do
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
puts "║   Compiling Scratchpad Memory FSM Design & Testbench (v2)     ║"
puts "╚════════════════════════════════════════════════════════════════╝"
puts ""

# Compile design file
puts "Compiling: scratchpad_memory.sv (FSM-based design)"
vlog -sv -work $work_dir "$proj_dir/scratchpad_memory.sv" 2>&1

# Compile FSM testbench
puts "Compiling: tb_scratchpad_memory_v2.sv (FSM testbench)"
vlog -sv -work $work_dir "$proj_dir/tb_scratchpad_memory_v2.sv" 2>&1

puts ""
puts "Compilation complete!"
puts ""

# ================================================================================
# STEP 3: Simulate the FSM Testbench
# ================================================================================

puts "╔════════════════════════════════════════════════════════════════╗"
puts "║         Running FSM Simulation - Testbench v2                ║"
puts "╚════════════════════════════════════════════════════════════════╝"
puts ""

# Start simulation with testbench as top-level module
vsim -work $work_dir \
     -t 1ps \
     tb_scratchpad_memory_v2

# Run simulation
run 10000ns

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
