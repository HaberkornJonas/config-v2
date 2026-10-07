param(
    # Leave the config-v2-test WSL instance in place after the run for debugging.
    [switch]$KeepInstance
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$setupPath = Join-Path $repoRoot 'setup.sh'

. (Join-Path $PSScriptRoot 'lib/WslTestInstance.ps1')

$failures = New-Object System.Collections.Generic.List[string]

$identityKeys = @('GIT_USER_NAME', 'GIT_USER_EMAIL', 'GPG_FINGERPRINT')
$managedTargets = @('.zshrc', '.gitconfig', '.config/starship.toml', '.config/nvim/init.lua', '.config/tmux/tmux.conf')

$testUser = 'tester'
$testHome = "/home/$testUser"
$fixtureRoot = "$testHome/config-v2"
$shimDir = '/opt/config-v2-shims'
$shimLog = '/var/tmp/config-v2-shims.log'
$pacmanStdin = '/var/tmp/config-v2-pacman-stdin.txt'
$basePath = '/usr/local/bin:/usr/bin'
$shimPath = "${shimDir}:$basePath"
# setpriv (not runuser/su) so no PAM/systemd user session keeps the test user alive between scenarios.
$asTester = "setpriv --reuid=$testUser --regid=$testUser --init-groups --"

# --- Static checks on setup.sh (AC 1, 2, 4) ---
if (-not (Test-Path -LiteralPath $setupPath -PathType Leaf)) {
    $failures.Add('setup.sh is missing at repository root.')
    $setupContent = ''
}
else {
    $setupContent = Get-Content -LiteralPath $setupPath -Raw
}

$identity = @{}
foreach ($line in ($setupContent -split "`r?`n")) {
    if ($line -match '^\s*([A-Z_]+)=["'']?(.+?)["'']?\s*$' -and $identityKeys -contains $matches[1]) {
        if ($identity.ContainsKey($matches[1])) {
            # validate-readme.ps1 and validate-dotfiles.ps1 parse setup.sh the same way; a second
            # KEY= line would silently replace the real value and disable their leak checks.
            $failures.Add("setup.sh assigns $($matches[1]) more than once at line start; only the configuration block may.")
            continue
        }
        $identity[$matches[1]] = $matches[2].Trim()
    }
}
foreach ($key in $identityKeys) {
    if (-not $identity.ContainsKey($key)) {
        $failures.Add("setup.sh configuration block is missing $key.")
    }
}

$forbiddenSetupPatterns = @(
    @{ Label = 'DOTFILES_REPO reference (AD-8)'; Pattern = 'DOTFILES_REPO' },
    @{ Label = 'remote dotfiles repository URL (AD-1)'; Pattern = '(?i)git@[^\s"'']+|https?://github\.com/[^\s"'']*dotfiles' },
    @{ Label = 'caller-cwd-relative manifest path (AD-3)'; Pattern = '\./packages/' },
    @{ Label = 'chezmoi init with a repository argument (AD-1)'; Pattern = '(?m)^[^#\n]*chezmoi init\b(?![^\n]*--source)' }
)
foreach ($check in $forbiddenSetupPatterns) {
    if ($setupContent -match $check.Pattern) {
        $failures.Add("setup.sh contains a $($check.Label).")
    }
}

$requiredSetupPatterns = @(
    @{ Label = 'require_repo_asset_path helper'; Pattern = '(?m)^\s*require_repo_asset_path\(\)' },
    @{ Label = 'repository root derived from the script location'; Pattern = 'REPO_ROOT="\$\(cd "\$\(dirname "\$\{BASH_SOURCE\[0\]\}"\)" && pwd\)"' },
    @{ Label = 'local chezmoi init --apply --source <repo>/dotfiles'; Pattern = '(?m)^[^#\n]*chezmoi init --apply\b[^\n]*--source "\$\(require_repo_asset_path "dotfiles"\)"' },
    @{ Label = 'Arch manifest install via sudo from repo root'; Pattern = 'sudo pacman -S --needed --noconfirm - < "\$\(require_repo_asset_path "packages/arch\.txt"\)"' },
    @{ Label = 'Ubuntu manifest install via sudo from repo root'; Pattern = 'sudo xargs -a "\$\(require_repo_asset_path "packages/ubuntu\.txt"\)" apt-get install -y' }
)
foreach ($check in $requiredSetupPatterns) {
    if ($setupContent -notmatch $check.Pattern) {
        $failures.Add("setup.sh is missing the $($check.Label).")
    }
}

# The Ubuntu branch cannot run in the Arch test instance: every system command in it must use sudo.
$ubuntuBranch = [regex]::Match($setupContent, '(?s)elif \[\[ "\$DISTRO" == "ubuntu" \]\]; then(.*?)\n\s*else\b').Groups[1].Value
if ([string]::IsNullOrEmpty($ubuntuBranch)) {
    $failures.Add('setup.sh Ubuntu branch not found.')
}
else {
    foreach ($line in ($ubuntuBranch -split "`r?`n")) {
        if ($line -match '^\s*#' -or $line -match '^\s*echo\s+"INFO:') { continue }
        foreach ($command in @('apt-get', 'install -m', 'gpg --dearmor', 'chmod', 'tee')) {
            $index = $line.IndexOf($command)
            if ($index -ge 0 -and $line.Substring(0, $index) -notmatch '\bsudo\s+(xargs\s.*)?$') {
                $failures.Add("setup.sh Ubuntu branch runs '$command' without sudo: $($line.Trim())")
            }
        }
    }
}

# --- Linux checks: run the real setup.sh in a disposable Arch WSL instance (AC 1-5) ---

function Invoke-Instance([string]$bash, [hashtable]$environment = @{}) {
    return Invoke-ConfigV2TestInstance $bash $environment
}

function Test-Instance([string]$bash) {
    return (Invoke-Instance $bash).ExitCode -eq 0
}

# Recreates the test user, the repo fixture (a git checkout of the working-tree setup.sh, packages/,
# dotfiles/), and empty shim logs. $mutation runs as root inside the fixture afterwards.
function Reset-Fixture([string]$mutation = ':') {
    $lines = @(
        "pkill -KILL -u $testUser >/dev/null 2>&1 || true",
        "userdel -rf $testUser >/dev/null 2>&1 || true",
        "rm -rf $testHome /root/.gitconfig /root/.config/chezmoi /root/.local/share/chezmoi",
        "useradd -m -s /bin/bash $testUser",
        'src="$(wslpath -a "$REPO_WINDOWS_PATH")"',
        "mkdir -p $fixtureRoot",
        "cp -r `"`$src/setup.sh`" `"`$src/packages`" `"`$src/dotfiles`" $fixtureRoot/",
        "chown -R ${testUser}: $testHome",
        "$asTester git -C $fixtureRoot init -q",
        "rm -f $shimLog $pacmanStdin",
        "install -m 0666 /dev/null $shimLog",
        "cd $fixtureRoot",
        $mutation
    )
    $result = Invoke-Instance ($lines -join "`n") @{ REPO_WINDOWS_PATH = $repoRoot }
    if ($result.ExitCode -ne 0) {
        throw "Fixture reset failed: $($result.Output)"
    }
}

# Runs setup.sh from /tmp (a foreign working directory) with a minimal environment and no stdin.
function Invoke-Setup([string]$runAs = $testUser, [string]$path = $shimPath) {
    if ($runAs -eq 'root') {
        $command = "cd /tmp && env -i HOME=/root USER=root LOGNAME=root PATH=$path $fixtureRoot/setup.sh </dev/null"
    }
    else {
        $command = "cd /tmp && $asTester env -i HOME=$testHome USER=$runAs LOGNAME=$runAs PATH=$path $fixtureRoot/setup.sh </dev/null"
    }
    return Invoke-Instance $command
}

function Invoke-AsTester([string]$command) {
    return Invoke-Instance "cd $testHome && $asTester env -i HOME=$testHome USER=$testUser LOGNAME=$testUser PATH=$basePath $command"
}

function Get-ShimLog {
    return (Invoke-Instance "cat $shimLog").Output
}

function Assert-FailedBeforeMutation([string]$scenario, $result, [string]$expectedMessage) {
    if ($result.ExitCode -eq 0) {
        $failures.Add("[$scenario] setup.sh exited 0; expected a failure.")
    }
    if ($result.Output -notmatch [regex]::Escape($expectedMessage)) {
        $failures.Add("[$scenario] setup.sh output does not contain '$expectedMessage'. Output: $($result.Output)")
    }
    $log = Get-ShimLog
    if (-not [string]::IsNullOrWhiteSpace($log)) {
        $failures.Add("[$scenario] setup.sh ran system commands before failing: $log")
    }
    if (Test-Instance "test -e $testHome/.config/chezmoi") {
        $failures.Add("[$scenario] setup.sh created ~/.config/chezmoi before failing.")
    }
}

$shimSetup = @"
mkdir -p $shimDir
cat > $shimDir/sudo <<'SHIM'
#!/bin/bash
echo "sudo `$*" >> $shimLog
exec "`$@"
SHIM
cat > $shimDir/pacman <<'SHIM'
#!/bin/bash
echo "pacman `$*" >> $shimLog
if [ "`${@: -1}" = "-" ]; then cat > $pacmanStdin; fi
SHIM
cat > $shimDir/curl <<'SHIM'
#!/bin/bash
echo "curl `$*" >> $shimLog
echo true
SHIM
chmod 0755 $shimDir/sudo $shimDir/pacman $shimDir/curl
"@

if ($setupContent) {
    try {
        $instanceReady = $false
        try {
            New-ConfigV2TestInstance @('chezmoi', 'git', 'openssh')
            $setup = Invoke-Instance $shimSetup
            if ($setup.ExitCode -ne 0) { throw "Shim setup failed: $($setup.Output)" }
            $instanceReady = $true
        }
        catch {
            $failures.Add("Linux test instance could not be prepared: $($_.Exception.Message)")
        }

        if ($instanceReady) {
            Reset-Fixture
            $syntax = Invoke-Instance "bash -n $fixtureRoot/setup.sh"
            if ($syntax.ExitCode -ne 0) {
                $failures.Add("setup.sh failed bash -n: $($syntax.Output)")
            }

            # Scenario A: happy path as a non-root user from a foreign cwd, with legacy chezmoi state present.
            $scenario = 'A happy path'
            Reset-Fixture "$asTester mkdir -p $testHome/.local/share/chezmoi && $asTester touch $testHome/.local/share/chezmoi/legacy-marker"
            $run = Invoke-Setup
            if ($run.ExitCode -ne 0) {
                $failures.Add("[$scenario] setup.sh exited $($run.ExitCode). Output: $($run.Output)")
            }
            else {
                $log = Get-ShimLog
                if ($log -notmatch '(?m)^sudo pacman -S --needed --noconfirm -\s*$') {
                    $failures.Add("[$scenario] setup.sh did not install the Arch manifest via 'sudo pacman -S --needed --noconfirm -'. Shim log: $log")
                }
                foreach ($sudoLine in ($log -split "`r?`n" | Where-Object { $_ -match '^sudo ' })) {
                    if ($sudoLine -notmatch '^sudo pacman ') {
                        $failures.Add("[$scenario] setup.sh used sudo for a non-system command: $sudoLine")
                    }
                }
                if (-not (Test-Instance "[ `"`$(sha256sum < $pacmanStdin)`" = `"`$(sha256sum < $fixtureRoot/packages/arch.txt)`" ]")) {
                    $failures.Add("[$scenario] pacman did not receive packages/arch.txt from the repository root.")
                }
                if ($run.Output -notmatch 'Leaving legacy chezmoi source') {
                    $failures.Add("[$scenario] setup.sh did not report the legacy ~/.local/share/chezmoi source.")
                }
                if (-not (Test-Instance "test -f $testHome/.local/share/chezmoi/legacy-marker")) {
                    $failures.Add("[$scenario] legacy ~/.local/share/chezmoi content was modified or deleted.")
                }

                if (-not (Test-Instance "grep -qx 'sourceDir = `"$fixtureRoot/dotfiles`"' $testHome/.config/chezmoi/chezmoi.toml")) {
                    $failures.Add("[$scenario] generated chezmoi config does not persist sourceDir = $fixtureRoot/dotfiles.")
                }
                $sourcePath = Invoke-AsTester 'chezmoi source-path'
                if ($sourcePath.ExitCode -ne 0 -or $sourcePath.Output.Trim() -ne "$fixtureRoot/dotfiles") {
                    $failures.Add("[$scenario] plain 'chezmoi source-path' does not resolve to the checkout's dotfiles/: $($sourcePath.Output)")
                }
                $verify = Invoke-AsTester 'chezmoi verify'
                if ($verify.ExitCode -ne 0) {
                    $failures.Add("[$scenario] plain 'chezmoi verify' reports drift after setup.sh (exit $($verify.ExitCode)). $($verify.Output)")
                }

                foreach ($target in $managedTargets) {
                    if (-not (Test-Instance "test -f $testHome/$target && [ `"`$(stat -c %U $testHome/$target)`" = $testUser ]")) {
                        $failures.Add("[$scenario] managed target ~/$target is missing or not owned by $testUser.")
                    }
                }
                $gitconfig = (Invoke-Instance "cat $testHome/.gitconfig").Output
                $gitconfigChecks = @(
                    @{ Key = 'GIT_USER_NAME'; Field = 'name' },
                    @{ Key = 'GIT_USER_EMAIL'; Field = 'email' },
                    @{ Key = 'GPG_FINGERPRINT'; Field = 'signingkey' }
                )
                foreach ($check in $gitconfigChecks) {
                    if ($identity.ContainsKey($check.Key) -and $gitconfig -notmatch "(?m)^\s*$($check.Field)\s*=\s*$([regex]::Escape($identity[$check.Key]))\s*$") {
                        $failures.Add("[$scenario] ~/.gitconfig $($check.Field) does not carry the setup.sh $($check.Key) value.")
                    }
                }

                if (Test-Instance "test -e $fixtureRoot/dotfiles/.git") {
                    $failures.Add("[$scenario] chezmoi created a nested git repository in dotfiles/.")
                }
                if (Test-Instance "test -e /root/.gitconfig || test -e /root/.config/chezmoi") {
                    $failures.Add("[$scenario] user state leaked into /root.")
                }
                if (-not (Test-Instance "test -f $testHome/.ssh/id_rsa && [ `"`$(stat -c %U $testHome/.ssh/id_rsa)`" = $testUser ]")) {
                    $failures.Add("[$scenario] SSH key was not created for $testUser.")
                }

                # Scenario B: rerun on the same machine stays green and keeps the SSH key.
                $scenario = 'B rerun'
                $keyHash = (Invoke-Instance "sha256sum $testHome/.ssh/id_rsa").Output
                $rerun = Invoke-Setup
                if ($rerun.ExitCode -ne 0) {
                    $failures.Add("[$scenario] setup.sh rerun exited $($rerun.ExitCode). Output: $($rerun.Output)")
                }
                if ((Invoke-AsTester 'chezmoi verify').ExitCode -ne 0) {
                    $failures.Add("[$scenario] plain 'chezmoi verify' reports drift after rerun.")
                }
                if ((Invoke-Instance "sha256sum $testHome/.ssh/id_rsa").Output -ne $keyHash) {
                    $failures.Add("[$scenario] SSH key changed on rerun.")
                }
            }

            # Scenario C: running as root is refused before any mutation.
            Reset-Fixture
            Assert-FailedBeforeMutation 'C root refused' (Invoke-Setup -runAs 'root') 'Do not run setup.sh as root'

            # Scenario D: missing distro manifest fails before package installation.
            Reset-Fixture 'rm -f packages/arch.txt'
            Assert-FailedBeforeMutation 'D missing manifest' (Invoke-Setup) 'Missing packages/arch.txt relative to setup.sh'

            # Scenario E: missing dotfiles/ fails before package installation.
            Reset-Fixture 'rm -rf dotfiles'
            Assert-FailedBeforeMutation 'E missing dotfiles' (Invoke-Setup) 'Missing dotfiles/.chezmoi.toml.tmpl relative to setup.sh'

            # Scenario F: not a git checkout fails before chezmoi could git-init dotfiles/.
            Reset-Fixture 'rm -rf .git'
            Assert-FailedBeforeMutation 'F not a git checkout' (Invoke-Setup) 'Missing .git relative to setup.sh'
            if (Test-Instance "test -e $fixtureRoot/dotfiles/.git") {
                $failures.Add('[F not a git checkout] dotfiles/.git was created.')
            }

            # Scenario G: sudo unavailable fails clearly before mutation.
            Reset-Fixture
            Assert-FailedBeforeMutation 'G no sudo' (Invoke-Setup -path $basePath) 'sudo is required'
        }
    }
    catch {
        $failures.Add("Unexpected test error: $($_.Exception.Message)")
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
    Write-Host 'Setup validation failed:'
    foreach ($failure in $failures) {
        Write-Host "- $failure"
    }
    exit 1
}

Write-Host 'Setup validation passed.'
