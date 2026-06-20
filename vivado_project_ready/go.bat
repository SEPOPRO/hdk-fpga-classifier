@echo off
cd /d C:\hdk\vivado_project_ready
C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat -mode batch -source synth_direct.tcl
pause
