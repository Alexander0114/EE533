# OpenSTA script: load liberty + mapped netlist + SDC, report Fmax
# Usage: ~/tools/OpenSTA/build/sta -exit run_opensta.tcl

read_liberty nangate45.lib
read_verilog asic_nangate45_mapped.v
link_design soc

read_sdc soc.sdc

# Exclude async reset paths — they don't have a buffer tree and distort WNS.
set_false_path -from [get_ports rst_n]

# Sanity check — any unclocked regs or unconstrained paths
puts "===== check_setup ====="
check_setup

# Top 5 worst-slack setup paths (reg-to-reg only)
puts "\n===== report_checks -path_delay max (top 5, reg-to-reg) ====="
report_checks -path_delay max -format full -digits 3 -group_path_count 5

# Pure reg-to-reg (exclude I/O paths) — set_false_path on primary IO to clean view
set_false_path -from [all_inputs]
set_false_path -to [all_outputs]
puts "\n===== reg-to-reg only ====="
report_checks -path_delay max -format full -digits 3 -group_path_count 3 -path_group clk

# Clock min period = Fmax — derive from WNS
puts "\n===== Fmax ====="

# Summary — report worst-slack setup path via report_checks machinery.
puts "\n===== Fmax (reg-to-reg setup) ====="
# report_checks -path_group clk limits to synchronous (skips async group)
set wns_path [report_checks -path_delay max -path_group clk -group_path_count 1 -format end -digits 4]
puts $wns_path

# Critical path detail
puts "\n===== full critical path ====="
report_checks -path_delay max -format full_clock_expanded -digits 3 -group_count 1
