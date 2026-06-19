# run_synth.ps1 - Ejecutar síntesis HDK v4.8 D=20,000
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  HDK v4.8 - SINTESIS VIVADO D=20,000" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

Set-Location C:\hdk\vivado_project_ready

# Verificar Vivado
$vivado = "C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat"
if (-not (Test-Path $vivado)) {
    Write-Host "❌ Vivado no encontrado en $vivado" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Vivado encontrado" -ForegroundColor Green
Write-Host "Iniciando síntesis (esto toma ~30-40 min)..." -ForegroundColor Yellow
Write-Host ""

# Ejecutar
& $vivado -mode batch -source build_hdk.tcl 2>&1

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  RESULTADOS" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$rpts = Get-ChildItem *.rpt
if ($rpts.Count -gt 0) {
    foreach ($r in $rpts) {
        Write-Host "  📄 $($r.Name) - $([math]::Round($r.Length/1KB)) KB" -ForegroundColor Green
    }
    Write-Host ""
    Write-Host "MOSTRANDO UTILIZACION:" -ForegroundColor Yellow
    Get-Content hdk_impl_utilization.rpt -TotalCount 50 | Select-String "Slice LUTs|LUT as|Register|DSP|BRAM|Slice"
} else {
    Write-Host "⚠️ No se encontraron archivos .rpt" -ForegroundColor Red
}

Write-Host ""
Write-Host "✅ COMPLETADO" -ForegroundColor Green
