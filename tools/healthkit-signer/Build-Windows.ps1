# Run in a Swift 6.0.3 / MSVC x64 developer shell. No Apple account required.
#requires -Version 7.0
param([Parameter(Mandatory)][string]$Source, [Parameter(Mandatory)][string]$Output)
$ErrorActionPreference = 'Stop'
$Source = (Resolve-Path -LiteralPath $Source).Path
$Output = [IO.Path]::GetFullPath($Output)
if (Test-Path -LiteralPath $Output) { throw 'Output directory must be new.' }
python (Join-Path $PSScriptRoot 'prepare-source.py') $Source
if ($LASTEXITCODE -ne 0) { throw 'Source overlay failed.' }
$deps = Join-Path $Source '.build/native'
New-Item -ItemType Directory -Path $deps -Force | Out-Null
$archive = Join-Path $deps 'unicorn.zip'
Invoke-WebRequest 'https://github.com/mahee96/unicorn/releases/download/2.1.4-multiarch/unicorn-windows-x64.zip' -OutFile $archive
if ((Get-FileHash $archive -Algorithm SHA256).Hash -ne 'B17F03EA800A0B552970FF98CEA633F7DB335FFF035766FB353D35D6393D568D') { throw 'Unicorn checksum mismatch.' }
Expand-Archive -LiteralPath $archive -DestinationPath $deps -Force
& vcpkg install zlib:x64-windows-static "--x-install-root=$deps/vcpkg"
if ($LASTEXITCODE -ne 0) { throw 'zlib build failed.' }
$zlib = Join-Path $deps 'vcpkg/x64-windows-static'
$zlibLibrary = @('zlib.lib', 'zlibstatic.lib', 'z.lib') | ForEach-Object { Join-Path "$zlib/lib" $_ } | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $zlibLibrary) { throw "No supported zlib static library found in $zlib/lib" }
Write-Host "Using zlib library: $zlibLibrary"
$env:INCLUDE = "$env:INCLUDE;$deps/include;$zlib/include"
$env:LIB = "$env:LIB;$deps/lib;$zlib/lib"
$env:_CL_ = '/D_ALLOW_COMPILER_AND_STL_VERSION_MISMATCH'
Push-Location $Source
try {
    swift build -c release --force-resolved-versions --product sidesign `
        -Xcc "-I$deps/include" -Xcc "-I$zlib/include" -Xcc -DWIN32=1 -Xcc -DZ_HAVE_UNISTD_H=0 `
        -Xcc -D_ALLOW_COMPILER_AND_STL_VERSION_MISMATCH -Xcxx -D_ALLOW_COMPILER_AND_STL_VERSION_MISMATCH `
        -Xcc -D_CRT_SECURE_NO_WARNINGS -Xcc -D_CRT_NONSTDC_NO_WARNINGS `
        -Xcxx "-I$deps/include" -Xlinker "/LIBPATH:$deps/lib" -Xlinker $zlibLibrary
    if ($LASTEXITCODE -ne 0) { throw 'Swift compilation failed.' }
    $binary = Get-ChildItem .build -Recurse -Filter sidesign.exe | Where-Object FullName -Match '[\\/]release[\\/]' | Select-Object -First 1
    if (-not $binary) { throw 'Compiler produced no executable.' }
    New-Item -ItemType Directory -Path $Output | Out-Null
    Copy-Item -LiteralPath $binary.FullName -Destination (Join-Path $Output 'LidlLeanSigner.exe')
    # Windows Swift binaries need their runtime DLLs on machines without the SDK.
    $runtime = Split-Path (Get-Command swift).Source
    Get-ChildItem $runtime -Filter '*.dll' | Copy-Item -Destination $Output
    if ($env:SDKROOT) {
        Get-ChildItem "$env:SDKROOT/usr/bin" -Filter '*.dll' -ErrorAction SilentlyContinue | Copy-Item -Destination $Output
    }
    $env:PATH -split ';' | Where-Object { $_ -match 'Swift' -and (Test-Path -LiteralPath $_ -PathType Container) } | Select-Object -Unique | ForEach-Object {
        Get-ChildItem -LiteralPath $_ -Filter '*.dll' | Copy-Item -Destination $Output
    }
    foreach ($name in @('Start-HealthKitSigning.ps1', 'inspect_ipa.py', 'package_ipa.py', 'README.md', 'Setup-LocalDependencies.py')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $Output
    }
    & (Join-Path $Output 'LidlLeanSigner.exe') --self-test
    if ($LASTEXITCODE -ne 0) { throw 'Compiled helper failed its offline smoke test.' }
    git diff --exit-code -- Package.resolved
    if ($LASTEXITCODE -ne 0) { throw 'Build changed the upstream dependency lockfile.' }
} finally { Pop-Location }
