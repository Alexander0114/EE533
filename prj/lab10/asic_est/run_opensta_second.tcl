read_liberty nangate45.lib
read_verilog asic_nangate45_mapped.v
link_design soc
read_sdc soc.sdc
set_false_path -from [get_ports rst_n]
set_false_path -from [all_inputs]
set_false_path -to [all_outputs]

puts "===== 1st critical path (SP -> u_fetch/_983_, ~603 MHz) ====="
report_checks -path_delay max -format full -digits 3 -path_group clk \
    -to [get_pins u_sm_core/u_fetch/_983_/D]

puts "\n===== 2nd critical path (SP HCA -> u_sp/_896_, ~629 MHz) ====="
report_checks -path_delay max -format full -digits 3 -path_group clk \
    -to [get_pins u_sm_core/SP_LANE[0].u_sp/_896_/D]

puts "\n===== 3rd critical path (sm_core _5424_ warp state, ~633 MHz) ====="
report_checks -path_delay max -format full -digits 3 -path_group clk \
    -to [get_pins u_sm_core/_5424_/D]
