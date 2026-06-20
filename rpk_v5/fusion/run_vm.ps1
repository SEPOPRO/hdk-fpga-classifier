# RPK v5 Synthesis — Auto-run on VM startup
$log = "C:\rpk_v5_log.txt"
"=== RPK v5 SYNTHESIS STARTED ===" | Out-File $log

# Update repo to get fixed run_rpk_v5.tcl
Set-Location C:\hdk
git pull origin master 2>&1 | Out-File $log -Append

# Verify file exists
if (Test-Path "C:\hdk\rpk_v5\fusion\run_rpk_v5.tcl") {
    "run_rpk_v5.tcl found" | Out-File $log -Append
} else {
    "run_rpk_v5.tcl NOT found" | Out-File $log -Append
}

# Run RPK v5 synthesis from correct directory
Set-Location C:\hdk\rpk_v5\fusion
$vivado = "C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat"
if (Test-Path $vivado) {
    "Starting Vivado RPK v5 at $(Get-Date)" | Out-File $log -Append
    & $vivado -mode batch -source run_rpk_v5.tcl 2>&1 | Out-File C:\rpk_v5_vivado_log.txt
    "Completed at $(Get-Date)" | Out-File $log -Append
    
    # Show results
    $rpts = Get-ChildItem C:\hdk\rpk_v5\fusion\*.rpt
    "Found $($rpts.Count) report files:" | Out-File $log -Append
    foreach ($r in $rpts) { "$($r.Name) - $([math]::Round($r.Length/1KB)) KB" | Out-File $log -Append }
    
    # Show utilization in log
    if (Test-Path "C:\hdk\rpk_v5\fusion\rpk_v5_utilization.rpt") {
        Select-String -Path "C:\hdk\rpk_v5\fusion\rpk_v5_utilization.rpt" -Pattern "Slice LUTs|Slice Registers|DSPs|BRAM|F7 Muxes|BUFG" | Out-File $log -Append
    }
} else {
    "Vivado not found" | Out-File $log -Append
}

"=== DONE ===" | Out-File $log -Append
New-Item -Path C:\RPK_V5_DONE.txt -ItemType File -Force | Out-Null
