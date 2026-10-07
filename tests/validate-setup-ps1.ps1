$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$setupPath = Join-Path $repoRoot 'setup.ps1'
$scoopManifestPath = Join-Path $repoRoot 'packages\scoop.txt'
$wingetManifestPath = Join-Path $repoRoot 'packages\winget.txt'

$failures = New-Object System.Collections.Generic.List[string]

foreach ($requiredPath in @($setupPath, $scoopManifestPath, $wingetManifestPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        $failures.Add("Required Windows bootstrap file is missing: $requiredPath")
    }
}

if ($failures.Count -eq 0) {
    $setupContent = Get-Content -LiteralPath $setupPath -Raw
    $requiredChecks = @(
        @{
            Label = 'PowerShell fail-fast behavior'
            Pattern = '(?m)^\$ErrorActionPreference\s*=\s*[''"]Stop[''"]\s*$'
        },
        @{
            Label = 'Strict mode'
            Pattern = '(?m)^Set-StrictMode\s+-Version\s+Latest\s*$'
        },
        @{
            Label = 'Repository root derived from script location'
            Pattern = '(?m)^\s*\$repoRoot\s*=\s*\$PSScriptRoot\s*$'
        },
        @{
            Label = 'Scoop manifest resolved from repository root'
            Pattern = '(?m)Join-Path\s+\$repoRoot\s+[''"]packages\\scoop\.txt[''"]'
        },
        @{
            Label = 'winget manifest resolved from repository root'
            Pattern = '(?m)Join-Path\s+\$repoRoot\s+[''"]packages\\winget\.txt[''"]'
        },
        @{
            Label = 'Required local assets checked before use'
            Pattern = '(?s)Test-Path\s+-LiteralPath.*?Missing required.*?setup\.ps1'
        },
        @{
            Label = 'Scoop package installation delegated from manifest'
            Pattern = '(?s)scoop\s+install\s+@\w+'
        },
        @{
            Label = 'Scoop bootstrapped only when missing'
            Pattern = '(?s)if\s*\(-not\s*\(Get-Command\s+scoop\b.*?Invoke-RestMethod\s+-Uri\s+[''"]https://get\.scoop\.sh'
        },
        @{
            Label = 'winget package installation delegated with deterministic flags'
            Pattern = '(?s)winget\s+install.*?--id.*?--exact.*?--silent.*?--accept-package-agreements.*?--accept-source-agreements.*?--disable-interactivity'
        }
    )

    foreach ($check in $requiredChecks) {
        if ($setupContent -notmatch $check.Pattern) {
            $failures.Add("Missing setup.ps1 requirement: $($check.Label).")
        }
    }

    if ($setupContent -match '(?i)\b(?:DOTFILES_REPO|config\.sh)\b|dotfiles\.git') {
        $failures.Add('setup.ps1 must not restore the remote dotfiles repository or config.sh model.')
    }

    if ($setupContent -match '(?im)^\s*(?:Set-Location|Push-Location)\b|\bCopy-Item\b') {
        $failures.Add('setup.ps1 must not depend on the caller current directory or copy managed dotfiles directly.')
    }

    if ($setupContent -match '(?i)\bwsl(?:\.exe)?\s+--(?:install|import|unregister|set-default-version)\b') {
        $failures.Add('setup.ps1 must not add unsupported WSL or Linux-user provisioning automation.')
    }

    if ($setupContent -match '(?i)\b(?:msiexec|Start-BitsTransfer|Expand-Archive)\b') {
        $failures.Add('Package installation must remain delegated to Scoop and winget.')
    }

    foreach ($manifestPath in @($scoopManifestPath, $wingetManifestPath)) {
        $packageIds = @(
            Get-Content -LiteralPath $manifestPath |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_ -notmatch '^\s*#' }
        )
        if ($packageIds.Count -eq 0) {
            $failures.Add("Package manifest is empty: $manifestPath")
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host 'Windows bootstrap validation failed:'
    foreach ($failure in $failures) {
        Write-Host "- $failure"
    }
    exit 1
}

Write-Host 'Windows bootstrap validation passed.'
