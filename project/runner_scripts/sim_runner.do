quit -sim
vlib work
vmap work work

vlog -sv nar_defines.vh nar_params.vh scratchpad.sv scratchpad_tb.sv

vsim work.scratchpad_tb

add wave *
run -all

wave zoom full