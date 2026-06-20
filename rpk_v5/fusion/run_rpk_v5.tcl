# RPK v5 Full Synthesis
create_project rpk_v5 ./vivado_rpk -part xc7a200tfbg676-2 -force
set_property target_language VHDL [current_project]
set_property default_lib work [current_project]

add_files -norecurse {
    ../../vhdl/hd_classifier.vhd
    ../../vhdl/popcount_tree.vhd
    ../../vhdl/argmin.vhd
    ../../vhdl/uart_rx.vhd
    ../../vhdl/uart_tx.vhd
}
add_files -norecurse {
    ../../rpk_v5/fusion/rpk_v5_top.vhd
    ../../rpk_v5/fusion/bnn_vision.vhd
    ../../rpk_v5/fusion/fusion_multimodal.vhd
    ../../rpk_v5/vision/gabor_lut/gabor_lut.vhd
    ../../rpk_v5/vision/bnn_ternary/rpk_bnn_pkg.vhd
}
add_files -norecurse {
    ../../rpk_v5/audio/mfcc_lut/mfcc_lut_pkg.vhd
    ../../rpk_v5/audio/mfcc_lut/mfcc_dct_pkg.vhd
}
set_property top rpk_v5_top [current_fileset]

synth_design -top rpk_v5_top -part xc7a200tfbg676-2 -directive AreaOptimized_high

puts "=== UTILIZATION ==="
report_utilization -file rpk_v5_utilization.rpt
puts "=== TIMING ==="
report_timing -max_paths 5 -file rpk_v5_timing.rpt
puts "=== POWER ==="
report_power -file rpk_v5_power.rpt
puts "=== DONE ==="
exit
