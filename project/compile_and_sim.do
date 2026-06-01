# Compilation script for scratchpad image testbench

# Remove and recreate work library (force fresh compile)
if {[file exists work]} {
    vdel -all -lib work
}
vlib work
vmap work work

# Compile all files (remove explicit .vh includes - they're included in source files)
vlog -sv scratchpad.sv scratchpad_image_tb.sv

# Run simulation
vsim -c scratchpad_image_tb -do "run -all; quit"
