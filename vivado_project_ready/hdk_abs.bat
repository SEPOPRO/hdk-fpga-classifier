@echo off
echo HDK v4.8 Synthesis D=20,000
echo ==============================
cd /d %USERPROFILE%\Desktop
rmdir /s /q vivado_project 2>nul
echo create_project hdk_classifier ./vivado_project -part xc7a200tfbg676-2 -force > hdk_run.tcl
echo set_property target_language VHDL [current_project] >> hdk_run.tcl
echo set_property default_lib work [current_project] >> hdk_run.tcl
echo add_files -norecurse {C:/hdk/vhdl/hd_classifier.vhd C:/hdk/vhdl/popcount_tree.vhd C:/hdk/vhdl/argmin.vhd C:/hdk/vhdl/uart_rx.vhd C:/hdk/vhdl/uart_tx.vhd} >> hdk_run.tcl
echo set_property top HDK [current_fileset] >> hdk_run.tcl
echo synth_design -top HDK -part xc7a200tfbg676-2 >> hdk_run.tcl
echo report_utilization -file hdk_synth_utilization.rpt >> hdk_run.tcl
echo report_timing -max_paths 5 -file hdk_synth_timing.rpt >> hdk_run.tcl
echo exit >> hdk_run.tcl
C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat -mode batch -source hdk_run.tcl
echo.
echo ========== RESULTADOS ==========
if exist hdk_synth_utilization.rpt (type hdk_synth_utilization.rpt | findstr "Slice LUTs" & type hdk_synth_utilization.rpt | findstr "Slice Registers" & type hdk_synth_utilization.rpt | findstr "DSPs")
pause
