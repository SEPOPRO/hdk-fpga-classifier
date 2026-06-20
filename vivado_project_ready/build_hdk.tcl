# build_hdk.tcl — Direct synthesis (no launch_runs)
create_project hdk_classifier ./vivado_project -part xc7a200tfbg676-2 -force
set_property target_language VHDL [current_project]
set_property default_lib work [current_project]
add_files -norecurse {
    ../vhdl/hd_classifier.vhd
    ../vhdl/popcount_tree.vhd
    ../vhdl/argmin.vhd
    ../vhdl/uart_rx.vhd
    ../vhdl/uart_tx.vhd
}
set_property top HDK [current_fileset]

# Direct synthesis — blocks until done
synth_design -top HDK -part xc7a200tfbg676-2

# Reports
puts "=== SYNTHESIS DONE, GENERATING REPORTS ==="
report_utilization -file hdk_synth_utilization.rpt
report_timing -max_paths 5 -file hdk_synth_timing.rpt

puts "========================================"
puts "HDK FPGA Build Complete"
puts "========================================"
puts "Resources: hdk_synth_utilization.rpt"
puts "Timing:    hdk_synth_timing.rpt"
puts "========================================"
exit
