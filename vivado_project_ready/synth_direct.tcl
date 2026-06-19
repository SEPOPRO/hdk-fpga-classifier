# Direct synthesis - no launch_runs
create_project hdk_classifier ./vivado_project -part xc7a200tfbg676-2 -force
set_property target_language VHDL [current_project]
add_files -norecurse {
    ../vhdl/hd_classifier.vhd
    ../vhdl/popcount_tree.vhd
    ../vhdl/argmin.vhd
    ../vhdl/uart_rx.vhd
    ../vhdl/uart_tx.vhd
}
set_property top HDK [current_fileset]
synth_design -top HDK -part xc7a200tfbg676-2 -directive AreaOptimized_high

puts "REPORT_UTILIZATION:"
report_utilization -file hdk_synth_utilization.rpt
puts "REPORT_TIMING:"
report_timing -max_paths 5 -file hdk_synth_timing.rpt
puts "DONE"
exit
