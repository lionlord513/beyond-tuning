param([string]$Zig = 'zig')
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    & $Zig cc -target x86_64-windows-gnu -O2 -shared native/preset_bridge.c -o mod/BeyondTuning/assets/native/BeyondTuningNative.dll -lcomdlg32 -lshell32 -luser32 -lgdi32 -lole32 -lwindowscodecs -luuid
    if ($LASTEXITCODE -ne 0) { throw 'Native build failed' }
    python tools/package.py
    if ($LASTEXITCODE -ne 0) { throw 'Packaging failed' }
} finally { Pop-Location }
