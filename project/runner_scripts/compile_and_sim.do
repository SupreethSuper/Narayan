# ================================================================================
# ModelSim Compilation and Simulation Script for Scratchpad Memory Testbench
# ================================================================================
# Usage: vsim -c -do compile_and_sim.do
# ================================================================================

# Set project directories
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
puts "║       Compiling Scratchpad Memory Design & Testbench          ║"
puts "╚════════════════════════════════════════════════════════════════╝"
puts ""

# NOTE: Using -sv flag for SystemVerilog syntax support (allows localparam in .vh files)
# Do NOT compile .vh files directly - they will be included via `include statements

# Compile design file (SystemVerilog mode, includes nar_params.vh)
puts "Compiling: scratchpad_memory.sv"
vlog -sv -work $work_dir "$proj_dir/scratchpad_memory.sv" 2>&1

# Compile testbench (SystemVerilog mode, includes nar_params.vh)
puts "Compiling: tb_scratchpad_memory.sv"
vlog -sv -work $work_dir "$proj_dir/tb_scratchpad_memory.sv" 2>&1

puts ""
puts "Compilation complete!"
puts ""

# ================================================================================
# STEP 3: Simulate the Testbench
# ================================================================================

puts "╔════════════════════════════════════════════════════════════════╗"
puts "║              Running Simulation - Testbench                   ║"
puts "╚════════════════════════════════════════════════════════════════╝"
puts ""

# Start simulation with testbench as top-level module
# Run for sufficient time to complete all tests
vsim -work $work_dir \
     -t 1ps \
     tb_scratchpad_memory

# Run simulation for sufficient time
# 66 tests × 10ns average per test ≈ 660ns + overhead = 2000ns
run 5000ns

# ================================================================================
# STEP 4: Print final message and exit
# ================================================================================

puts ""
puts "╔════════════════════════════════════════════════════════════════╗"
puts "║                Simulation Complete                            ║"
puts "║           Check transcript output above for results           ║"
puts "╚════════════════════════════════════════════════════════════════╝"
puts ""

# Exit ModelSim
exit
