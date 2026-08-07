$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$readmePath = Join-Path $repoRoot 'README.md'
$setupPath = Join-Path $repoRoot 'setup.sh'

$failures = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path -LiteralPath $readmePath)) {
    $failures.Add("README.md is missing at $readmePath.")
}

if (-not (Test-Path -LiteralPath $setupPath)) {
    $failures.Add("setup.sh is missing at $setupPath.")
}

$readmeContent = ''
$setupContent = ''
if ($failures.Count -eq 0) {
    $readmeContent = Get-Content -LiteralPath $readmePath -Raw
    $setupContent = Get-Content -LiteralPath $setupPath -Raw

    $requiredChecks = @(
        @{
            Label = 'Linux quick-start heading'
            Pattern = '(?im)^##\s+Linux Quick Start\s*$'
        },
        @{
            Label = 'Git manual install prerequisite'
            Pattern = '(?is)install git manually first'
        },
        @{
            Label = 'Exact Linux git clone command'
            Pattern = [regex]::Escape('git clone https://github.com/HaberkornJonas/config-v2.git')
        },
        @{
            Label = 'Exact Linux setup.sh command'
            Pattern = [regex]::Escape('./setup.sh')
        },
        @{
            Label = 'Inline setup.sh configuration note'
            Pattern = '(?is)(setup\.sh.*?(carries|contains|keeps).*?bootstrap configuration.*?(inline|top of the script|top of `setup\.sh`))'
        },
        @{
            Label = 'Local checkout requirement explanation'
            Pattern = '(?is)(setup\.sh.*?reads.*?packages/arch\.txt.*?packages/ubuntu\.txt.*?same checkout.*?supported bootstrap path)'
        },
        @{
            Label = 'Windows companion section'
            Pattern = '(?im)^##\s+Windows Companion Bootstrap\s*$'
        },
        @{
            Label = 'Exact Windows companion command'
            Pattern = [regex]::Escape('powershell -ExecutionPolicy Bypass -File .\setup.ps1')
        },
        @{
            Label = 'Two-repo architecture explanation'
            Pattern = '(?is)config-v2.*bootstrap.*dotfiles repo.*chezmoi'
        }
    )

    foreach ($check in $requiredChecks) {
        if ($readmeContent -notmatch $check.Pattern) {
            $failures.Add("Missing README requirement: $($check.Label).")
        }
    }

    if ($readmeContent -match '(?im)\bconfig\.sh\b') {
        $failures.Add('README still references config.sh after the inline configuration change.')
    }

    $requiredSetupAssignments = @(
        'DOTFILES_REPO',
        'GIT_USER_NAME',
        'GIT_USER_EMAIL',
        'GPG_FINGERPRINT',
        'SSH_KEY_FILE'
    )

    foreach ($variableName in $requiredSetupAssignments) {
        if ($setupContent -notmatch "(?m)^\s*$variableName=") {
            $failures.Add("setup.sh is missing inline assignment for $variableName.")
        }
    }

    $setupValuesToBlock = @{
        'DOTFILES_REPO' = $null
        'GIT_USER_EMAIL' = $null
        'GPG_FINGERPRINT' = $null
        'SSH_KEY_FILE' = $null
    }

    foreach ($line in Get-Content -LiteralPath $setupPath) {
        if ($line -match '^\s*([A-Z_]+)=["'']?(.+?)["'']?\s*$') {
            $key = $matches[1]
            $value = $matches[2].Trim()
            if ($setupValuesToBlock.ContainsKey($key)) {
                $setupValuesToBlock[$key] = $value
            }
        }
    }

    foreach ($entry in $setupValuesToBlock.GetEnumerator()) {
        if (-not [string]::IsNullOrWhiteSpace($entry.Value) -and $readmeContent.Contains($entry.Value)) {
            $failures.Add("README exposes setup.sh value for $($entry.Key).")
        }
    }

    $requiredSetupPatterns = @(
        @{
            Label = 'Repo asset requirement helper'
            Pattern = '(?s)require_repo_asset_path\(\).*?Missing \$relative_path relative to setup\.sh\..*?Install Git manually, clone config-v2 locally, and run \./setup\.sh from that checkout\.'
        },
        @{
            Label = 'Arch package manifest local checkout usage'
            Pattern = '(?m)pacman -S --needed --noconfirm - < "\$\(require_repo_asset_path "packages/arch\.txt"\)"'
        },
        @{
            Label = 'Ubuntu package manifest local checkout usage'
            Pattern = '(?m)xargs -a "\$\(require_repo_asset_path "packages/ubuntu\.txt"\)" apt-get install -y'
        }
    )

    foreach ($check in $requiredSetupPatterns) {
        if ($setupContent -notmatch $check.Pattern) {
            $failures.Add("Missing setup.sh requirement: $($check.Label).")
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host 'README validation failed:'
    foreach ($failure in $failures) {
        Write-Host "- $failure"
    }
    exit 1
}

Write-Host 'README validation passed.'
