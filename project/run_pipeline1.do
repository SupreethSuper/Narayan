# run_pipeline1.do
# Compile and simulate tb_pipeline1 against pipeline1.sv (combinational pass-through)

if {[file exists work]} { vdel -lib work -all }
vlib work
vmap work work

vlog -sv -work work +incdir+. pipeline1.sv
vlog -sv -work work +incdir+. tb_pipeline1.sv

vsim -t 1ps work.tb_pipeline1

run -all
quit -f
