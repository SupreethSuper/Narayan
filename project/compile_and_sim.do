# Compilation script for scratchpad image testbench

# Create/clear work library
vlib work
vmap work work

# Compile all files
vlog -sv nar_defines.vh nar_params.vh scratchpad.sv scratchpad_image_tb.sv

# Run simulation
vsim -c scratchpad_image_tb -do "run -all; quit"
