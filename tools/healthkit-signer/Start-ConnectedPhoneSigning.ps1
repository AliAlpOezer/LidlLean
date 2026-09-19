#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Ipa,
    [Parameter(Mandatory)][string]$AdiLibraries,
    [string]$BundleId = 'com.alial.lidllean'
)
$ErrorActionPreference = 'Stop'
$python = (Get-Command python -ErrorAction Stop).Source
try {
    $devices = @(& $python -m pymobiledevice3 usbmux list 2>$null | ConvertFrom-Json)
} catch {
    throw 'Could not read a trusted iPhone. Keep it connected and unlocked, tap Trust if prompted, then try again.'
}
$usbDevices = @($devices | Where-Object { $_.ConnectionType -eq 'USB' -and $_.UniqueDeviceID })
if ($usbDevices.Count -eq 0) { throw 'No trusted iPhone was found over USB.' }
if ($usbDevices.Count -gt 1) { throw 'More than one iPhone is connected. Disconnect all but the iPhone you want to sign for.' }
$device = $usbDevices[0]
Write-Host "Detected $($device.DeviceName) ($($device.ProductType))."
& (Join-Path $PSScriptRoot 'Start-HealthKitSigning.ps1') -Ipa $Ipa -Udid $device.UniqueDeviceID -AdiLibraries $AdiLibraries -BundleId $BundleId
