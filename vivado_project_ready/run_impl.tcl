# Run implementation only (synthesis already done)
open_project vivado_project/hdk_classifier.xpr
launch_runs impl_1 -jobs 4
wait_on_run impl_1
open_run impl_1 -name impl_1
report_utilization -file hdk_impl_utilization.rpt
report_timing -file hdk_impl_timing.rpt
report_power -file hdk_power.rpt
puts "========================================"
puts "HDK FPGA Build Complete"
puts "========================================"
puts "Resources: hdk_impl_utilization.rpt"
puts "Timing:    hdk_impl_timing.rpt"
puts "Power:     hdk_power.rpt"
puts "========================================"
