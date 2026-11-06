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
            Pattern = '(?is)(setup\.sh.*?reads.*?packages/arch\.txt.*?same checkout.*?supported bootstrap path)'
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

    # Arch-only scope (correct-course 2026-10-29). Windows and other distros may still be named as deferred.
    $forbiddenReadmeChecks = @(
        @{ Label = 'Windows Companion Bootstrap section'; Pattern = '(?im)^##\s+Windows Companion Bootstrap\s*$' },
        @{ Label = 'removed Ubuntu manifest reference'; Pattern = 'packages/ubuntu\.txt' },
        @{ Label = 'removed Scoop/winget manifest reference'; Pattern = 'packages/(scoop|winget)\.txt' },
        @{ Label = 'removed setup.ps1 command'; Pattern = '(?i)setup\.ps1' }
    )
    foreach ($check in $forbiddenReadmeChecks) {
        if ($readmeContent -match $check.Pattern) {
            $failures.Add("README still contains a $($check.Label).")
        }
    }

    # AD-5 classification artifact: every bootstrap-touched path has exactly one category.
    $ownershipMatch = [regex]::Match($readmeContent, '(?ims)^##\s+Path Ownership\s*$(?<body>.*?)(?=^##\s|\z)')
    if (-not $ownershipMatch.Success) {
        $failures.Add('Missing README requirement: Path Ownership section.')
    }
    else {
        $ownership = $ownershipMatch.Groups['body'].Value
        $requiredOwnershipPaths = @(
            '~/.zshrc', '~/.gitconfig', '~/.config/starship.toml', '~/.config/nvim/init.lua', '~/.config/tmux/tmux.conf',
            '~/.config/chezmoi/chezmoi.toml', '$SSH_KEY_FILE', '~/.gnupg', '~/.local/share/fnm', 'Login shell', '~/.local/share/chezmoi'
        )
        $rows = @($ownership -split "`r?`n" | Where-Object { $_ -match '^\s*\|' -and $_ -notmatch '^\s*\|\s*Path\s*\|' -and $_ -notmatch '^\s*\|[\s:|-]+\|\s*$' })
        foreach ($path in $requiredOwnershipPaths) {
            # Exactly one table row per path: prose mentions do not count, and a second row would allow a second category.
            $pathRows = @($rows | Where-Object { $_.Contains($path) }).Count
            if ($pathRows -ne 1) {
                $failures.Add("README Path Ownership table must list $path in exactly one row (found $pathRows).")
            }
        }
        if ($rows.Count -eq 0) {
            $failures.Add('README Path Ownership section has no table rows.')
        }
        foreach ($row in $rows) {
            $categories = [regex]::Matches($row, '\b(stateful-asset|chezmoi-managed)\b').Count
            if ($categories -ne 1) {
                $failures.Add("README Path Ownership row must have exactly one category (found $categories): $($row.Trim())")
            }
        }
    }

    $requiredSetupAssignments = @(
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
            Label = 'Arch-only guard'
            Pattern = 'only Arch Linux is supported'
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
