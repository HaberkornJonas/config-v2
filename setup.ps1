$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = $PSScriptRoot

# --- Bootstrap configuration ---
$scoopManifestPath = Join-Path $repoRoot 'packages\scoop.txt'
$wingetManifestPath = Join-Path $repoRoot 'packages\winget.txt'

function Get-RequiredPackageIds {
    param(
        [string]$ManifestPath,
        [string]$PackageManager
    )

    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        throw "Missing required $PackageManager package manifest at '$ManifestPath'. Clone a complete config-v2 checkout and rerun setup.ps1."
    }

    $packageIds = @(
        Get-Content -LiteralPath $ManifestPath |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_ -notmatch '^\s*#' }
    )
    if ($packageIds.Count -eq 0) {
        throw "The $PackageManager package manifest at '$ManifestPath' contains no package identifiers."
    }

    return $packageIds
}

$scoopPackages = @(Get-RequiredPackageIds -ManifestPath $scoopManifestPath -PackageManager 'Scoop')
$wingetPackages = @(Get-RequiredPackageIds -ManifestPath $wingetManifestPath -PackageManager 'winget')

$wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
if ($null -eq $wingetCommand) {
    throw 'winget is required but was not found. Install Windows App Installer, then rerun setup.ps1.'
}

if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host 'INFO: Installing Scoop with its official PowerShell installer.'
    Invoke-RestMethod -Uri 'https://get.scoop.sh' | Invoke-Expression

    $scoopShimsPath = Join-Path $env:USERPROFILE 'scoop\shims'
    if (Test-Path -LiteralPath $scoopShimsPath -PathType Container) {
        $env:Path = "$scoopShimsPath;$env:Path"
    }
}

if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    throw 'Scoop installation did not provide a scoop command. Check the official installer output and rerun setup.ps1.'
}

Write-Host 'INFO: Installing packages listed in packages\scoop.txt with Scoop.'
$LASTEXITCODE = 0
scoop install @scoopPackages
if ($LASTEXITCODE -ne 0) {
    throw "Scoop package installation failed with exit code $LASTEXITCODE."
}

foreach ($packageId in $wingetPackages) {
    Write-Host "INFO: Installing $packageId with winget."
    winget install --id $packageId --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) {
        throw "winget failed to install '$packageId' with exit code $LASTEXITCODE."
    }
}

Write-Host 'INFO: Windows package bootstrap complete.'
