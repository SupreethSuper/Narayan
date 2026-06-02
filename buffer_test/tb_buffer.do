# run.do

# Clean old work library
if [file exists work] {
    vdel -all
}

# Create work library
vlib work
vmap work work

# Compile files
vlog -sv buffer.sv
vlog -sv tb_buffer.sv

# Load simulation
vsim work.tb_buffer

# Add all waves
#add wave -r *

# Run simulation
run -all