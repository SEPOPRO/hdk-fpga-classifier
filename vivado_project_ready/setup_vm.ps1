param(
    [switch]$SkipVivadoInstall
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  HDK v4.8 FULL SETUP - VM Script" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$ErrorActionPreference = "Continue"
Set-Location C:\

# 1. INSTALAR GIT
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "[1/5] Instalando Git..." -ForegroundColor Yellow
    winget install --id Git.Git -e --source winget --accept-package-agreements --silent 2>&1 | Out-Null
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
} else {
    Write-Host "[1/5] Git ya instalado." -ForegroundColor Green
}

# 2. CLONAR REPO
if (-not (Test-Path C:\hdk)) {
    Write-Host "[2/5] Clonando repositorio..." -ForegroundColor Yellow
    git clone https://github.com/SEPOPRO/hdk-fpga-classifier.git C:\hdk 2>&1
} else {
    Write-Host "[2/5] Repositorio ya clonado." -ForegroundColor Green
}

# 3. VERIFICAR VHDL
Write-Host "[3/5] Verificando VHDL..." -ForegroundColor Yellow
$dValue = Select-String "D\s*:\s*:=\s*(\d+)" C:\hdk\vhdl\hd_classifier.vhd | ForEach-Object { $_.Matches.Groups[1].Value }
Write-Host "  D = $dValue" -ForegroundColor Green

# 4. INSTALAR VIVADO
if (-not $SkipVivadoInstall) {
    Write-Host "[4/5] Descargando Vivado Web Installer..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri "https://www.xilinx.com/member/forms/download/designtools-download.html?filename=Vivado_2025.2_Windows_Web.exe" -OutFile C:\Vivado_setup.exe
    Write-Host "" 
    Write-Host "   ⚠️  ABRE C:\Vivado_setup.exe y sigue estos pasos:" -ForegroundColor Yellow
    Write-Host "   1. Next → Vivado ML Standard → Next" -ForegroundColor White
    Write-Host "   2. En Devices, SOLO marca '7 Series'" -ForegroundColor White
    Write-Host "   3. Destino: C:\AMDDesignTools\2025.2" -ForegroundColor White
    Write-Host "   4. Espera ~30 min a que termine" -ForegroundColor White
    Write-Host ""
    Write-Host "   CUANDO TERMINE LA INSTALACION, EJECUTA:" -ForegroundColor Green
    Write-Host '   powershell -File C:\hdk\vivado_project_ready\run_synth.ps1' -ForegroundColor Green
} else {
    # 5. EJECUTAR SINTESIS DIRECTO
    Write-Host "[5/5] Ejecutando síntesis Vivado..." -ForegroundColor Yellow
    Set-Location C:\hdk\vivado_project_ready
    C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat -mode batch -source build_hdk.tcl 2>&1
    Write-Host "✅ SINTESIS COMPLETADA" -ForegroundColor Green
    Get-ChildItem C:\hdk\vivado_project_ready\*.rpt | Select-Object Name, Length
}
