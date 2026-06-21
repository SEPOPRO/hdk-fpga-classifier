# RPK v5 Synthesis + Checkpoint + Reports
create_project rpk_v5 ./vivado_rpk -part xc7a200tfbg676-2 -force
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
set_property top rpk_v5_top [current_fileset]
synth_design -top rpk_v5_top -part xc7a200tfbg676-2

# Write checkpoint so we can re-run reports
write_checkpoint -force rpk_v5_post_synth.dcp

# Utilization to stdout + file
puts "=== UTILIZATION ==="
report_utilization -file rpk_v5_util.rpt
set fp [open "rpk_v5_util_summary.txt" w]
set util_raw [report_utilization -return_string]
puts $fp $util_raw
close $fp
puts "=== UTIL DONE ==="

# Timing
puts "=== TIMING ==="
report_timing -max_paths 5 -file rpk_v5_timing.rpt
puts "=== TIMING DONE ==="

# Power  
puts "=== POWER ==="
report_power -file rpk_v5_power.rpt
puts "=== POWER DONE ==="

puts "=== ALL DONE ==="
exit
