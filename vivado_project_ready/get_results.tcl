# Get LUT count only - minimal script
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
launch_runs synth_1 -jobs 4
wait_on_run synth_1
open_run synth_1 -name synth_1

# Write results to a simple text file
set fid [open "synth_results.txt" w]
puts $fid "=========================================="
puts $fid "HDK Vivado Synthesis Results"
puts $fid "=========================================="
puts $fid ""

# Report utilization
set util_report [report_utilization -return_string]
puts $fid "UTILIZATION:"
puts $fid $util_report
puts $fid ""

# Report timing summary  
puts $fid "TIMING:"
catch { set timing_report [report_timing -max_paths 5 -return_string] }
puts $fid $timing_report
puts $fid ""

puts $fid "=========================================="
close $fid

puts "DONE - Results written to synth_results.txt"
exit
