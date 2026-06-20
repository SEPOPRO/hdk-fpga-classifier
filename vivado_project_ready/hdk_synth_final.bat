@echo off
echo ========================================
echo  HDK v4.8 - Synthesis D=20,000
echo  Corriendo desde C:\hdk\vivado_project_ready
echo ========================================
echo.
cd /d C:\hdk\vivado_project_ready

REM Remove old project files
rmdir /s /q vivado_project 2>nul

REM Write Tcl script
echo create_project hdk_classifier ./vivado_project -part xc7a200tfbg676-2 -force > hdk_synth.tcl
echo set_property target_language VHDL [current_project] >> hdk_synth.tcl
echo set_property default_lib work [current_project] >> hdk_synth.tcl
echo add_files -norecurse {../vhdl/hd_classifier.vhd ../vhdl/popcount_tree.vhd ../vhdl/argmin.vhd ../vhdl/uart_rx.vhd ../vhdl/uart_tx.vhd} >> hdk_synth.tcl
echo set_property top HDK [current_fileset] >> hdk_synth.tcl
echo synth_design -top HDK -part xc7a200tfbg676-2 >> hdk_synth.tcl
echo report_utilization -file hdk_synth_utilization.rpt >> hdk_synth.tcl
echo report_timing -max_paths 5 -file hdk_synth_timing.rpt >> hdk_synth.tcl
echo exit >> hdk_synth.tcl

REM Run
C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat -mode batch -source hdk_synth.tcl

REM Show results
echo.
echo ========================================
if exist hdk_synth_utilization.rpt (
    echo  RESULTADOS REALES DE VIVADO:
    echo.
    type hdk_synth_utilization.rpt | findstr "Slice LUTs Slice Registers DSPs BRAM "
) else (
    echo  ERROR: No se generaron reportes
)
echo ========================================
pause
