# ============================================================================
# build_hdk.tcl — Vivado project build script for HDK classifier
#
# Usage:
#   vivado -mode batch -source build_hdk.tcl
#
# Requirements:
#   - Vivado 2020.1+ (WebPack is free)
#   - Artix-7 XC7A200T device support installed
# ============================================================================

# Project name and directory
set project_name "hdk_classifier"
set project_dir "./vivado_project"

# Create project
create_project $project_name $project_dir -part xc7a200tfbg676-2 -force

# Set project properties
set_property target_language VHDL [current_project]
set_property simulator_language VHDL [current_project]
set_property default_lib work [current_project]

# Add VHDL source files
add_files -fileset sources_1 -norecurse {
    ../vhdl/hd_classifier.vhd
    ../vhdl/popcount_tree.vhd
    ../vhdl/argmin.vhd
    ../vhdl/uart_rx.vhd
    ../vhdl/uart_tx.vhd
}

# Add testbench
add_files -fileset sim_1 -norecurse {
    ../vhdl/tb_hd_classifier.vhd
}

# Add constraints file
# create_fileset -constrset constrs_1
# add_files -fileset constrs_1 -norecurse { ../vhdl/hdk_constraints.xdc }

# Set top module
set_property top HDK [current_fileset]

# Set simulation top
set_property top tb_hd_classifier [get_filesets sim_1]

# Run synthesis
launch_runs synth_1 -jobs 4
wait_on_run synth_1
open_run synth_1 -name synth_1

# Report resource utilization
report_utilization -file hdk_synth_utilization.rpt
report_timing -file hdk_synth_timing.rpt

# Run implementation (place & route)
launch_runs impl_1 -jobs 4
wait_on_run impl_1
open_run impl_1 -name impl_1

# Report post-implementation results
report_utilization -file hdk_impl_utilization.rpt
report_timing -file hdk_impl_timing.rpt
report_power -file hdk_power.rpt

# Generate bitstream
# launch_runs impl_1 -to_step write_bitstream
# wait_on_run impl_1

puts "========================================"
puts "HDK FPGA Build Complete"
puts "========================================"
puts "Resources: hdk_impl_utilization.rpt"
puts "Timing:    hdk_impl_timing.rpt"
puts "Power:     hdk_power.rpt"
puts "========================================"
