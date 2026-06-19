# Ultra-light reporting for large designs
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
synth_design -top HDK -part xc7a200tfbg676-2

# Ultra-minimal reporting: just get cell counts
set fid [open "synth_results.txt" w]
puts $fid "=== CELL COUNTS ==="
puts $fid [join [get_cells -hierarchical -filter {PRIMITIVE_TYPE =~ "LUT*"}] "\n"]
close $fid
puts "DONE"
exit
