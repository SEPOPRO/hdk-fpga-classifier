# Test with D=1000 for quick results
create_project hdk_test ./vivado_test -part xc7a200tfbg676-2 -force
set_property target_language VHDL [current_project]

# Need to use a modified top-level with smaller D
# Instead, override the generic via script
set_property generic {D=1000 N_CLASSES=20} [current_fileset]

add_files -norecurse {
    ../vhdl/hd_classifier.vhd
    ../vhdl/popcount_tree.vhd
    ../vhdl/argmin.vhd
    ../vhdl/uart_rx.vhd
    ../vhdl/uart_tx.vhd
}
set_property top HDK [current_fileset]
synth_design -top HDK -part xc7a200tfbg676-2

# Quick report
puts "UTILIZATION:"
report_utilization -quiet
puts "TIMING:"
report_timing -max_paths 3 -quiet
puts "DONE"
exit
