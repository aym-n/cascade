# AWS F1 custom-logic clock target (250 MHz). Reports show whether timing closes.
create_clock -period 4.000 -name clk [get_ports clk]

set_clock_uncertainty 0.050 [get_clocks clk]

# Keep I/O paths out of the critical path for this RTL-only benchmark.
set_input_delay  0.500 -clock clk [all_inputs]
set_output_delay 0.500 -clock clk [all_outputs]
