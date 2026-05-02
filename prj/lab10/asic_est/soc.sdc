# SDC constraints for OpenSTA — NetFPGA SoC top
# Target: 125 MHz (8 ns) matches core_clk in synthesis PAR

create_clock -name clk -period 8.0 [get_ports clk]

# Input delay: assume 2 ns external wire delay (3 ns slack budget)
set_input_delay -clock clk 2.0 [get_ports {rst_n in_data in_ctrl in_wr out_rdy}]

# Output delay: assume 2 ns external setup at receiver
set_output_delay -clock clk 2.0 [get_ports {in_rdy out_data out_ctrl out_wr}]

# Typical drive/load
set_driving_cell -lib_cell INV_X1 -pin ZN [all_inputs]
set_load 0.01 [all_outputs]
