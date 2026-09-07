# =============================================================================
# Heaplit OS - Staged Bootloader Compiler & QEMU Launcher
# =============================================================================

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Heaplit OS: Staged Assembly Build Pipeline" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

$BootPath = Join-Path $PSScriptRoot "..\rings\ring_3\boot"
$SourceFile = Join-Path $BootPath "base.asm"
$OutputFile = Join-Path $BootPath "base.bin"

if (-not (Test-Path $SourceFile)) {
    Write-Host "[ERROR] Cannot find source file: $SourceFile" -ForegroundColor Red
    exit 1
}

Write-Host "[1/3] Compiling Staged Bootloader with NASM..." -ForegroundColor Yellow
Set-Location $BootPath
nasm -I./ -I../../../ring_0/ -I../../../ring_1/ -I../../../ring_2/ -I../../../ring_3/ -f bin base.asm -o base.bin

if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAILED] NASM compilation failed with exit code $LASTEXITCODE" -ForegroundColor Red
    Set-Location $PSScriptRoot
    Read-Host "Press Enter to exit..."
    exit 1
}

$BinarySize = (Get-Item $OutputFile).Length
$SectorCount = [math]::Ceiling($BinarySize / 512)
Write-Host "[SUCCESS] base.bin built successfully! ($BinarySize bytes, $SectorCount sectors)" -ForegroundColor Green

Write-Host "[2/3] Terminating any existing QEMU instances..." -ForegroundColor Yellow
Stop-Process -Name "qemu-system-x86_64" -ErrorAction SilentlyContinue

Write-Host "[3/3] Launching Heaplit OS in QEMU..." -ForegroundColor Yellow
$QemuArgs = @(
    "-drive", "format=raw,file=base.bin",
    "-m", "512M",
    "-cpu", "max",
    "-vga", "std"
)

Start-Process "qemu-system-x86_64" -ArgumentList $QemuArgs

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Heaplit OS running in QEMU." -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan

Set-Location $PSScriptRoot
Read-Host "Diagnostic Hold: Press Enter to close this PowerShell window..."
