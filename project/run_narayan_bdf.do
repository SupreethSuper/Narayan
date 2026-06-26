# run_narayan_bdf.do
# Compile and simulate tb_narayan_bdf against narayan_bdf.v (scheduler + scratchpad_memory)

if {[file exists work]} { vdel -lib work -all }
vlib work
vmap work work

vlog -sv -work work +incdir+. scratchpad_memory.sv
vlog -sv -work work +incdir+. scheduler.sv
vlog -sv -work work +incdir+. narayan_bdf.v
vlog -sv -work work +incdir+. tb_narayan_bdf.sv

vsim -t 1ps work.tb_narayan_bdf

run -all
quit -f
