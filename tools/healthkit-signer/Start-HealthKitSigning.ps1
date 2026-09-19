#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Ipa,
    [Parameter(Mandatory)][ValidatePattern('^([0-9A-Fa-f]{40}|[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16})$')][string]$Udid,
    [Parameter(Mandatory)][string]$AdiLibraries,
    [string]$BundleId = 'com.alial.lidllean',
    [string]$Signer = (Join-Path $PSScriptRoot 'LidlLeanSigner.exe'),
    [string]$OpenSSL = 'C:\Program Files\Git\usr\bin\openssl.exe'
)
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'This launcher is for Windows.' }
foreach ($file in @($Ipa, $Signer, $OpenSSL, (Join-Path $PSScriptRoot 'apple-roots.pem'))) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing required file: $file" }
}
foreach ($name in @('libCoreADI.so', 'libstoreservicescore.so')) {
    if (-not (Test-Path -LiteralPath (Join-Path $AdiLibraries $name))) { throw "Missing ADI library: $name" }
}
$python = (Get-Command python -ErrorAction Stop).Source
$state = Join-Path (Join-Path $env:LOCALAPPDATA 'LidlLeanSigner') 'managed-vault-v2'
New-Item -ItemType Directory -Path $state -Force | Out-Null
if ((Get-Item -LiteralPath $state).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Vault cannot be a link.' }
$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
& icacls.exe $state /inheritance:r /grant:r "*${sid}:(OI)(CI)F" '*S-1-5-18:(OI)(CI)F' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not restrict vault permissions.' }
$lock = [IO.File]::Open((Join-Path $state 'run.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
try {
    $managedVaultPath = Join-Path $state 'vault-password.dpapi'
    if (Test-Path -LiteralPath $managedVaultPath -PathType Leaf) {
        $encrypted = [IO.File]::ReadAllBytes($managedVaultPath)
        $vaultBytes = [Security.Cryptography.ProtectedData]::Unprotect($encrypted, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
        $managedVaultPassword = [Text.Encoding]::UTF8.GetString($vaultBytes)
    } else {
        $random = [byte[]]::new(32)
        [Security.Cryptography.RandomNumberGenerator]::Fill($random)
        $managedVaultPassword = [Convert]::ToBase64String($random)
        $encrypted = [Security.Cryptography.ProtectedData]::Protect([Text.Encoding]::UTF8.GetBytes($managedVaultPassword), $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
        [IO.File]::WriteAllBytes($managedVaultPath, $encrypted)
    }
    if ([string]::IsNullOrWhiteSpace($managedVaultPassword)) { throw 'Windows-protected local vault password is empty.' }
    $env:LIDLLEAN_MANAGED_VAULT_PASSWORD = $managedVaultPassword
    Write-Host 'Using a Windows-protected local signing vault (v2).'
    $run = Join-Path $state ([Guid]::NewGuid().ToString())
    $inputFile = (Resolve-Path -LiteralPath $Ipa).Path
    Write-Host 'Experimental signing. No installation or certificate revocation is performed.'
    Write-Host "Input SHA256: $((Get-FileHash -LiteralPath $inputFile -Algorithm SHA256).Hash)"
    $app = & $python (Join-Path $PSScriptRoot 'inspect_ipa.py') --prepare $inputFile --destination $run --bundle-id $BundleId
    if ($LASTEXITCODE -ne 0) { throw 'Input validation failed.' }
    & $Signer --app $app --state $state --libs (Resolve-Path -LiteralPath $AdiLibraries).Path --bundle-id $BundleId --udid $Udid
    if ($LASTEXITCODE -ne 0) { throw 'Signing stopped. Your existing iPhone installation has not been changed.' }
    & $python (Join-Path $PSScriptRoot 'inspect_ipa.py') --app $app --bundle-id $BundleId --udid $Udid --openssl $OpenSSL --roots (Join-Path $PSScriptRoot 'apple-roots.pem')
    if ($LASTEXITCODE -ne 0) { throw 'Independent signature check failed. Do not install the working copy.' }
    $output = Join-Path $run 'LidlLean-healthkit-checked.ipa'
    # Compress only the prepared Payload, never the vault or signing keys.
    & $python (Join-Path $PSScriptRoot 'package_ipa.py') $run $output
    if ($LASTEXITCODE -ne 0) { throw 'Packaging failed.' }
    Write-Host "Checked IPA: $output"
    Write-Host "SHA256: $((Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash)"
    Write-Host 'Not installed. Device acceptance and the Health permission prompt remain unverified.'
    Write-Host 'Do not re-sign this IPA with Sideloadly: that can replace the checked profile.'
} finally {
    Remove-Item Env:LIDLLEAN_MANAGED_VAULT_PASSWORD -ErrorAction SilentlyContinue
    $lock.Dispose()
}
