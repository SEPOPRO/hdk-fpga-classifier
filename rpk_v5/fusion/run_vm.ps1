# Find RPT files after synthesis
$log = "C:\rpk_v5_log.txt"

cd C:\hdk
git clone https://github.com/SEPOPRO/hdk-fpga-classifier.git C:\hdk 2>&1 | Out-File $log -Append

cd C:\hdk\rpk_v5\fusion

$vivado = "C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat"
& $vivado -mode batch -source run_rpk_v5.tcl 2>&1 | Out-File C:\rpk_v5_vivado_log.txt

# Search EVERYWHERE for .rpt files
$all_rpts = Get-ChildItem -Path C:\hdk -Filter *.rpt -Recurse -ErrorAction SilentlyContinue
"Found $($all_rpts.Count) report files:" | Out-File $log -Append
foreach ($r in $all_rpts) { "$($r.FullName) - $([math]::Round($r.Length/1KB)) KB" | Out-File $log -Append }

# Also search for .dcp and .xml
$dcp = Get-ChildItem -Path C:\hdk -Filter *.dcp -Recurse -ErrorAction SilentlyContinue
"Found $($dcp.Count) checkpoint files:" | Out-File $log -Append
foreach ($d in $dcp) { "$($d.FullName) - $([math]::Round($d.Length/1MB)) MB" | Out-File $log -Append }

# Search runs directory specifically
$runs = Get-ChildItem -Path C:\hdk\rpk_v5\fusion\vivado_rpk -Recurse -ErrorAction SilentlyContinue
"=== vivado_rpk contents ($($runs.Count) items) ===" | Out-File $log -Append
foreach ($r in $runs) { 
    $type = if ($r.PSIsContainer) { "DIR" } else { "FILE" }
    "$type $($r.Name) - $([math]::Round($r.Length/1KB)) KB" | Out-File $log -Append 
}

"=== DONE ===" | Out-File $log -Append
New-Item -Path C:\RPK_V5_DONE.txt -ItemType File -Force | Out-Null
