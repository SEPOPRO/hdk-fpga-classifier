create_project rpk_v5 ./vivado_rpk -part xc7a200tfbg676-2 -force
set_property target_language VHDL [current_project]
set_property default_lib work [current_project]
read_vhdl -vhdl2008 ../../vhdl/hd_classifier.vhd
read_vhdl -vhdl2008 ../../vhdl/popcount_tree.vhd
read_vhdl -vhdl2008 ../../vhdl/argmin.vhd
read_vhdl -vhdl2008 ../../vhdl/uart_rx.vhd
read_vhdl -vhdl2008 ../../vhdl/uart_tx.vhd
read_vhdl -vhdl2008 ../../rpk_v5/fusion/rpk_v5_top.vhd
read_vhdl -vhdl2008 ../../rpk_v5/fusion/fusion_multimodal.vhd
read_vhdl -vhdl2008 ../../rpk_v5/vision/gabor_lut/gabor_lut.vhd
read_vhdl -vhdl2008 ../../rpk_v5/audio/mfcc_lut/mfcc_lut_pkg.vhd
read_vhdl -vhdl2008 ../../rpk_v5/audio/mfcc_lut/mfcc_dct_pkg.vhd
read_vhdl -vhdl2008 ../../rpk_v5/audio/mfcc_lut/audio_classifier.vhd
set_property top rpk_v5_top [current_fileset]
launch_runs synth_1 -jobs 4
wait_on_run synth_1
open_run synth_1 -name synth_1
report_utilization -file rpk_v5_utilization.rpt
report_timing -max_paths 5 -file rpk_v5_timing.rpt
report_power -file rpk_v5_power.rpt
puts "=== DONE ==="
exit
