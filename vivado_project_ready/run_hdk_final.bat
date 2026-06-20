@echo off
setlocal enabledelayedexpansion
echo ========================================
echo  HDK v4.8 Synthesis D=20,000
echo ========================================
echo.

cd /d C:\hdk\vivado_project_ready

REM Delete old project
rmdir /s /q vivado_project 2>nul

REM Create Tcl script
del run_now.tcl 2>nul
echo create_project hdk_classifier ./vivado_project -part xc7a200tfbg676-2 -force >> run_now.tcl
echo set_property target_language VHDL [current_project] >> run_now.tcl
echo set_property default_lib work [current_project] >> run_now.tcl
echo add_files -norecurse { >> run_now.tcl
echo     ../vhdl/hd_classifier.vhd >> run_now.tcl
echo     ../vhdl/popcount_tree.vhd >> run_now.tcl
echo     ../vhdl/argmin.vhd >> run_now.tcl
echo     ../vhdl/uart_rx.vhd >> run_now.tcl
echo     ../vhdl/uart_tx.vhd >> run_now.tcl
echo } >> run_now.tcl
echo set_property top HDK [current_fileset] >> run_now.tcl
echo synth_design -top HDK -part xc7a200tfbg676-2 >> run_now.tcl
echo puts "=== UTILIZATION ===" >> run_now.tcl
echo report_utilization -file hdk_synth_utilization.rpt >> run_now.tcl
echo puts "=== TIMING ===" >> run_now.tcl
echo report_timing -max_paths 5 -file hdk_synth_timing.rpt >> run_now.tcl
echo puts "=== DONE ===" >> run_now.tcl
echo exit >> run_now.tcl

echo Running Vivado synthesis...
echo This takes ~15-20 min. Do NOT close this window.
echo.

C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat -mode batch -source run_now.tcl

echo.
echo ========================================
if exist hdk_synth_utilization.rpt (
    echo RESULTS - Slice LUTs:
    type hdk_synth_utilization.rpt | findstr "Slice LUTs"
    type hdk_synth_utilization.rpt | findstr "Slice Registers"
    type hdk_synth_utilization.rpt | findstr "DSPs"
    type hdk_synth_utilization.rpt | findstr "BRAM"
) else (
    echo ERROR: No report files generated
)
echo.
echo Press any key to exit.
pause >nul
