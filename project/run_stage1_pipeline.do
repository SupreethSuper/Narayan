# run_stage1_pipeline.do
# Compile and simulate tb_stage1_pipeline against stage1_pipeline
# (narayan_bdf: scheduler + 4x scratchpad_memory, feeding pipeline1)

if {[file exists work]} { vdel -lib work -all }
vlib work
vmap work work

vlog -sv -work work +incdir+. scratchpad_memory.sv
vlog -sv -work work +incdir+. scheduler.sv
vlog -sv -work work +incdir+. pipeline1.sv
vlog -sv -work work +incdir+. narayan_bdf.sv
vlog -sv -work work +incdir+. stage1_pipeline.sv
vlog -sv -work work +incdir+. tb_stage1_pipeline.sv

vsim -t 1ps work.tb_stage1_pipeline

run -all
quit -f
