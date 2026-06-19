# Power estimation for D=10,000
create_project hdk_power ./vivado_power -part xc7a200tfbg676-2 -force
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

puts "=== POWER ==="
report_power
puts "=== DONE ==="
exit
