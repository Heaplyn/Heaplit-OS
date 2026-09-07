# load_os.ps1
# Heaplyn 8/16/26
# Loader for JarvisOS, compiles and runs the OS in QEMU

Set-Location "$PSScriptRoot\..\rings\ring_0"
nasm -I./ -f bin base.asm -o base.bin
Stop-Process -Name qemu-system-x86_64 -ErrorAction SilentlyContinue
Start-Process "qemu-system-x86_64" -ArgumentList "-drive format=raw,file=base.bin"
Read-Host "Diagnostic Hold: Press Enter to close this PowerShell window..."