# ================================================================================
# ModelSim Compilation and Simulation Script - Simple TB
# ================================================================================
# Usage: vsim -c -do compile_and_sim_simple.do
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
puts "║     Compiling Scratchpad Memory - Simple TB                   ║"
puts "╚════════════════════════════════════════════════════════════════╝"
puts ""

# Compile design file
puts "Compiling: scratchpad_memory.sv (with write_done flag & 2D memory)"
vlog -sv -work $work_dir "$proj_dir/scratchpad_memory.sv" 2>&1

# Compile simple testbench
puts "Compiling: tb_scratchpad_memory_simple.sv (self-checking TB)"
vlog -sv -work $work_dir "$proj_dir/tb_scratchpad_memory_simple.sv" 2>&1

puts ""
puts "Compilation complete!"
puts ""

# ================================================================================
# STEP 3: Simulate the Simple Testbench
# ================================================================================

puts "╔════════════════════════════════════════════════════════════════╗"
puts "║         Running Simulation - Simple TB with Assertions        ║"
puts "╚════════════════════════════════════════════════════════════════╝"
puts ""

# Start simulation with testbench as top-level module
vsim -work $work_dir \
     -t 1ps \
     tb_scratchpad_memory_simple

# Run simulation
run 2000ns

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
