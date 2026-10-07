param(
    # Leave the config-v2-test WSL instance in place after the run for debugging.
    [switch]$KeepInstance
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$dotfilesDir = Join-Path $repoRoot 'dotfiles'
$setupPath = Join-Path $repoRoot 'setup.sh'
$configTemplatePath = Join-Path $dotfilesDir '.chezmoi.toml.tmpl'

. (Join-Path $PSScriptRoot 'lib/WslTestInstance.ps1')

$failures = New-Object System.Collections.Generic.List[string]

$requiredSourceFiles = @(
    '.chezmoi.toml.tmpl',
    'dot_zshrc',
    'dot_gitconfig.tmpl',
    'dot_config/starship.toml',
    'dot_config/nvim/init.lua',
    'dot_config/tmux/tmux.conf'
)

$managedTargets = @(
    '.zshrc',
    '.gitconfig',
    '.config/starship.toml',
    '.config/nvim/init.lua',
    '.config/tmux/tmux.conf'
)

$identityKeys = @('GIT_USER_NAME', 'GIT_USER_EMAIL', 'GPG_FINGERPRINT')
$linuxSandboxRoot = '/var/tmp/config-v2-dotfiles'

function Get-RelativeSourcePath([string]$fullPath) {
    return $fullPath.Substring($dotfilesDir.Length).TrimStart('\', '/').Replace('\', '/')
}

# Bash prelude for a scenario sandbox inside the test instance: every chezmoi call is isolated
# to the sandbox source, destination, config, state, and cache.
function Get-SandboxPrelude([string]$scenario) {
    return (
        "sandbox='$linuxSandboxRoot/$scenario'",
        'cz() { chezmoi "$@" --source "$sandbox/source" --destination "$sandbox/home" --config "$sandbox/chezmoi.toml" --persistent-state "$sandbox/state.boltdb" --cache "$sandbox/cache" --no-tty; }'
    ) -join "`n"
}

# Copies the working-tree dotfiles/ into a fresh sandbox in the test instance, renders
# .chezmoi.toml.tmpl, and applies. Scripts are excluded so a stray run_ script never executes.
function Invoke-SandboxApply([string]$scenario, [hashtable]$identity) {
    $unsetKeys = @($identityKeys | Where-Object { -not $identity.ContainsKey($_) })
    $environment = @{ DOTFILES_WINDOWS_PATH = $dotfilesDir } + $identity
    $lines = @(
        (Get-SandboxPrelude $scenario),
        $(if ($unsetKeys.Count -gt 0) { 'unset ' + ($unsetKeys -join ' ') } else { ':' }),
        'rm -rf "$sandbox"',
        'mkdir -p "$sandbox/home"',
        'cp -r "$(wslpath -a "$DOTFILES_WINDOWS_PATH")" "$sandbox/source"',
        'cz execute-template --init --file "$sandbox/source/.chezmoi.toml.tmpl" > "$sandbox/chezmoi.toml.rendered" || { echo "Rendering .chezmoi.toml.tmpl failed."; exit 10; }',
        'mv "$sandbox/chezmoi.toml.rendered" "$sandbox/chezmoi.toml"',
        'cz apply --force --exclude scripts || { echo "chezmoi apply failed."; exit 11; }'
    )
    $result = Invoke-ConfigV2TestInstance ($lines -join "`n") $environment
    if ($result.ExitCode -ne 0) {
        $failures.Add("[$scenario] Sandbox apply failed (exit $($result.ExitCode)): $($result.Output)")
        return $false
    }
    return $true
}

function Get-SandboxTarget([string]$scenario, [string]$target) {
    $result = Invoke-ConfigV2TestInstance ("f='$linuxSandboxRoot/$scenario/home/$target'" + "`n" + '[ -f "$f" ] || exit 3' + "`n" + 'cat "$f"')
    if ($result.ExitCode -ne 0) {
        return $null
    }
    return $result.Output
}

function Get-FirstLineIndex([string[]]$lines, [string]$pattern) {
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $pattern) {
            return $i
        }
    }
    return -1
}

# --- Static structure checks (AC 1) ---
if (-not (Test-Path -LiteralPath $dotfilesDir -PathType Container)) {
    $failures.Add('dotfiles/ directory is missing at repository root.')
}

$rootChezmoiTemplates = @(Get-ChildItem -LiteralPath $repoRoot -Force -File -Filter '.chezmoi.*' -ErrorAction SilentlyContinue)
foreach ($file in $rootChezmoiTemplates) {
    $failures.Add("chezmoi root special file $($file.Name) must live inside dotfiles/, not at repository root.")
}

$sourceFiles = @()
if (Test-Path -LiteralPath $dotfilesDir -PathType Container) {
    foreach ($relativePath in $requiredSourceFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $dotfilesDir $relativePath) -PathType Leaf)) {
            $failures.Add("Missing managed source file: dotfiles/$relativePath.")
        }
    }
    $sourceFiles = @(Get-ChildItem -LiteralPath $dotfilesDir -Recurse -Force -File)
}

# --- Test-fixture safety checks (AC 3) ---
$secretContentChecks = @(
    @{ Label = 'private key block'; Pattern = '-----BEGIN [A-Z ]*PRIVATE KEY-----' },
    @{ Label = 'secret-like assignment'; Pattern = '(?i)\b(password|passwd|secret|token|api[_-]?key)\b\s*[:=]\s*\S+' }
)

$personalValues = @{}
if (-not (Test-Path -LiteralPath $setupPath -PathType Leaf)) {
    $failures.Add("setup.sh is missing at $setupPath; cannot check for personal-value leaks.")
}
else {
    foreach ($line in Get-Content -LiteralPath $setupPath) {
        if ($line -match '^\s*([A-Z_]+)=["'']?(.+?)["'']?\s*$') {
            $key = $matches[1]
            $value = $matches[2].Trim()
            if ($identityKeys -contains $key -and -not [string]::IsNullOrWhiteSpace($value)) {
                $personalValues[$key] = $value
            }
        }
    }
}

foreach ($file in $sourceFiles) {
    $relativePath = Get-RelativeSourcePath $file.FullName
    $segments = $relativePath.Split('/')
    $content = Get-Content -LiteralPath $file.FullName -Raw
    if ($null -eq $content) { $content = '' }

    foreach ($segment in $segments) {
        if ($segment -match '^(encrypted_|private_)') {
            $failures.Add("dotfiles/$relativePath uses a secret-bearing chezmoi prefix ($($matches[1])).")
        }
        if ($segment -match '^run_once_') {
            $failures.Add("dotfiles/$relativePath is a run_once_ script; dotfiles/ must not orchestrate setup (AD-9).")
        }
    }

    if ($file.Name -match '(^|_)id_(rsa|ed25519|ecdsa|dsa)$') {
        $failures.Add("dotfiles/$relativePath looks like a private SSH key file.")
    }

    if ($file.Name -match '^run_' -and $content -match '(?i)\b(pacman|apt-get|apt|curl|wget)\b|setup\.sh|\|\s*(ba)?sh\b') {
        $failures.Add("dotfiles/$relativePath is a run_ script that installs packages or orchestrates setup (AD-9).")
    }

    foreach ($check in $secretContentChecks) {
        if ($content -match $check.Pattern) {
            $failures.Add("dotfiles/$relativePath contains a $($check.Label).")
        }
    }

    foreach ($entry in $personalValues.GetEnumerator()) {
        if ($content.IndexOf($entry.Value, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $failures.Add("dotfiles/$relativePath contains the personal setup.sh value of $($entry.Key); inject it at chezmoi init instead.")
        }
    }
}

# --- Render / apply / idempotence checks in a disposable Arch WSL instance (AC 1, 2, 3, 5) ---
if (Test-Path -LiteralPath $configTemplatePath -PathType Leaf) {
    try {
        $instanceReady = $false
        try {
            New-ConfigV2TestInstance @('chezmoi', 'zsh')
            $instanceReady = $true
        }
        catch {
            $failures.Add("Linux test instance could not be prepared: $($_.Exception.Message)")
        }

        if ($instanceReady) {
            # Scenario A: no injected values -> public-safe fixture defaults, no GPG signing.
            $scenario = 'fixture-defaults'
            if (Invoke-SandboxApply $scenario @{}) {
                foreach ($target in $managedTargets) {
                    if ($null -eq (Get-SandboxTarget $scenario $target)) {
                        $failures.Add("[$scenario] Managed target ~/$target was not created by chezmoi apply.")
                    }
                }

                $gitconfig = Get-SandboxTarget $scenario '.gitconfig'
                if ($null -ne $gitconfig) {
                    if ($gitconfig -notmatch '(?m)^\s*name\s*=\s*Bootstrap Test User\s*$') {
                        $failures.Add("[$scenario] ~/.gitconfig does not use the placeholder user name.")
                    }
                    if ($gitconfig -notmatch '(?m)^\s*email\s*=\s*bootstrap-test@example\.invalid\s*$') {
                        $failures.Add("[$scenario] ~/.gitconfig does not use the placeholder user email.")
                    }
                    if ($gitconfig -match '(?im)^\s*(signingkey|gpgsign)\b') {
                        $failures.Add("[$scenario] ~/.gitconfig enables GPG signing without a fingerprint.")
                    }
                }

                $zshrc = Get-SandboxTarget $scenario '.zshrc'
                if ($null -ne $zshrc) {
                    $zshrcChecks = @(
                        @{ Label = 'zinit bootstrap'; Pattern = 'zinit\.zsh' },
                        @{ Label = 'fzf-tab plugin'; Pattern = 'zinit light Aloxaf/fzf-tab' },
                        @{ Label = 'zsh-autosuggestions plugin'; Pattern = 'zinit light zsh-users/zsh-autosuggestions' },
                        @{ Label = 'fast-syntax-highlighting plugin'; Pattern = 'zinit light zdharma-continuum/fast-syntax-highlighting' },
                        @{ Label = 'zoxide integration'; Pattern = 'zoxide init zsh' },
                        @{ Label = 'starship integration'; Pattern = 'starship init zsh' },
                        @{ Label = 'fnm integration'; Pattern = 'fnm env' }
                    )
                    foreach ($check in $zshrcChecks) {
                        if ($zshrc -notmatch $check.Pattern) {
                            $failures.Add("[$scenario] ~/.zshrc is missing the $($check.Label).")
                        }
                    }

                    $lines = $zshrc -split "`r?`n"
                    $compinitIndex = Get-FirstLineIndex $lines '^\s*autoload\b.*\bcompinit\b'
                    $fzfTabIndex = Get-FirstLineIndex $lines '^\s*zinit light Aloxaf/fzf-tab'
                    $autosuggestIndex = Get-FirstLineIndex $lines '^\s*zinit light zsh-users/zsh-autosuggestions'
                    $highlightIndex = Get-FirstLineIndex $lines '^\s*zinit light zdharma-continuum/fast-syntax-highlighting'
                    if ($compinitIndex -lt 0 -or $fzfTabIndex -lt 0 -or $compinitIndex -gt $fzfTabIndex) {
                        $failures.Add("[$scenario] ~/.zshrc must run compinit before loading fzf-tab.")
                    }
                    if ($fzfTabIndex -ge 0 -and (($autosuggestIndex -ge 0 -and $fzfTabIndex -gt $autosuggestIndex) -or ($highlightIndex -ge 0 -and $fzfTabIndex -gt $highlightIndex))) {
                        $failures.Add("[$scenario] ~/.zshrc must load fzf-tab before widget-wrapping plugins.")
                    }

                    $syntax = Invoke-ConfigV2TestInstance "zsh -n '$linuxSandboxRoot/$scenario/home/.zshrc'"
                    if ($syntax.ExitCode -ne 0) {
                        $failures.Add("[$scenario] ~/.zshrc failed zsh -n syntax check: $($syntax.Output)")
                    }
                }

                $verify = Invoke-ConfigV2TestInstance ((Get-SandboxPrelude $scenario) + "`ncz verify --exclude scripts")
                if ($verify.ExitCode -ne 0) {
                    $failures.Add("[$scenario] chezmoi verify reports drift after apply (exit $($verify.ExitCode)); apply is not idempotent. $($verify.Output)")
                }
            }

            # Scenario B: injected canonical keys (fake values) -> identity and GPG signing rendered.
            $scenario = 'injected-values'
            $fakeIdentity = @{
                GIT_USER_NAME = 'Fixture Person'
                GIT_USER_EMAIL = 'fixture@example.invalid'
                GPG_FINGERPRINT = '0000000000000000000000000000000000000000'
            }
            if (Invoke-SandboxApply $scenario $fakeIdentity) {
                $gitconfig = Get-SandboxTarget $scenario '.gitconfig'
                if ($null -eq $gitconfig) {
                    $failures.Add("[$scenario] ~/.gitconfig was not created by chezmoi apply.")
                }
                else {
                    $injectedChecks = @(
                        @{ Label = 'injected user name'; Pattern = '(?m)^\s*name\s*=\s*Fixture Person\s*$' },
                        @{ Label = 'injected user email'; Pattern = '(?m)^\s*email\s*=\s*fixture@example\.invalid\s*$' },
                        @{ Label = 'injected signing key'; Pattern = '(?m)^\s*signingkey\s*=\s*0{40}\s*$' },
                        @{ Label = 'commit signing'; Pattern = '(?m)^\s*gpgsign\s*=\s*true\s*$' }
                    )
                    foreach ($check in $injectedChecks) {
                        if ($gitconfig -notmatch $check.Pattern) {
                            $failures.Add("[$scenario] ~/.gitconfig is missing the $($check.Label).")
                        }
                    }
                }
            }
        }
    }
    finally {
        if ($KeepInstance) {
            Write-Host 'INFO: -KeepInstance set; WSL instance config-v2-test left in place for inspection.'
        }
        else {
            Remove-ConfigV2TestInstance
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host 'Dotfiles validation failed:'
    foreach ($failure in $failures) {
        Write-Host "- $failure"
    }
    exit 1
}

Write-Host 'Dotfiles validation passed.'
