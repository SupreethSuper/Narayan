# base.sdc — scratchpad_memory timing constraints
set clk_period 10.0

create_clock -name clk -period $clk_period [get_ports clk]
set_clock_uncertainty 0.25 [get_clocks clk]
set_clock_transition  0.15 [get_clocks clk]

# I/O budget: 20% of period on each side
set io_delay [expr {0.2 * $clk_period}]
set all_inputs_no_clk [remove_from_collection [all_inputs] [get_ports clk]]
set_input_delay  $io_delay -clock clk $all_inputs_no_clk
set_output_delay $io_delay -clock clk [all_outputs]

# rst is an asynchronous active-low reset — not a synchronous timing path.
# (Recovery/removal still checked by the lib; deassertion must be synchronized
#  at chip top.)
set_false_path -from [get_ports rst]

# Conservative output load (pF)
set_load 0.05 [all_outputs]
