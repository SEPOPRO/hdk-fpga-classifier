@echo off
echo HDK v4.8 - Synthesis D=20,000
echo ===============================
echo.

cd /d %USERPROFILE%\Desktop

REM Download latest build_hdk.tcl from GitHub
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/SEPOPRO/hdk-fpga-classifier/master/vivado_project_ready/build_hdk.tcl' -OutFile '%USERPROFILE%\Desktop\build_hdk.tcl'"

REM Run Vivado
C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat -mode batch -source %USERPROFILE%\Desktop\build_hdk.tcl

echo.
echo ===============================
echo  RESULTS
echo ===============================
if exist hdk_synth_utilization.rpt (
    echo Slice LUTs:
    type hdk_synth_utilization.rpt | findstr "Slice LUTs Slice Registers DSPs BRAM "
) else (
    for /r %%f in (*.rpt) do (
        echo Found: %%f
        type "%%f" | findstr "Slice LUTs Slice Registers DSPs BRAM "
    )
)
echo.
pause
