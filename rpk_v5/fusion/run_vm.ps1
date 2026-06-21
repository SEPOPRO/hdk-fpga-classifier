# Run RPK synthesis from correct CWD
$log = "C:\rpk_v5_log.txt"
"=== RPK v5 STARTED ===" | Out-File $log

Remove-Item -Recurse -Force C:\hdk -ErrorAction SilentlyContinue
cd C:\
git clone https://github.com/SEPOPRO/hdk-fpga-classifier.git C:\hdk 2>&1 | Out-File $log -Append

cd C:\hdk\rpk_v5\fusion
"Working dir: $(Get-Location)" | Out-File $log -Append

$vivado = "C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat"
if (Test-Path $vivado) {
    "Starting Vivado at $(Get-Date)" | Out-File $log -Append
    & $vivado -mode batch -source run_rpk_v5.tcl 2>&1 | Out-File C:\rpk_v5_vivado_log.txt
    "Completed at $(Get-Date)" | Out-File $log -Append
    
    Start-Sleep -Seconds 2
    $rpts = Get-ChildItem -Path C:\hdk\rpk_v5\fusion -Filter *.rpt
    "Found $($rpts.Count) report files" | Out-File $log -Append
    if ($rpts.Count -eq 0) {
        $rpts = Get-ChildItem -Path C:\hdk\rpk_v5\fusion\vivado_rpk -Filter *.rpt -Recurse
        "Found $($rpts.Count) report files in vivado_rpk/" | Out-File $log -Append
    }
    foreach ($r in $rpts) { "$($r.FullName) - $([math]::Round($r.Length/1KB)) KB" | Out-File $log -Append }
} else {
    "Vivado not found" | Out-File $log -Append
}

"=== DONE ===" | Out-File $log -Append
New-Item -Path C:\RPK_V5_DONE.txt -ItemType File -Force | Out-Null
