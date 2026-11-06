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
    @{ Label = 'chezmoi init with a repository argument (AD-1)'; Pattern = '(?m)^[^#\n]*chezmoi init\b(?![^\n]*--source)' },
    @{ Label = 'Ubuntu reference (AD-7)'; Pattern = '(?i)ubuntu' },
    @{ Label = 'apt package logic (AD-7)'; Pattern = '\bapt(-get|-key)?\b' },
    @{ Label = 'dpkg reference (AD-7)'; Pattern = '\bdpkg\b' },
    @{ Label = 'lsb_release reference (AD-7)'; Pattern = '\blsb_release\b' },
    @{ Label = 'third-party apt repository (AD-7)'; Pattern = 'download\.docker\.com|packages\.microsoft\.com' },
    @{ Label = 'ID_LIKE match that would accept Arch derivatives (AD-7)'; Pattern = '\bID_LIKE\b' },
    @{ Label = 'fnm installer without --skip-shell (AD-5)'; Pattern = '(?m)^[^#\n]*fnm\.vercel\.app/install(?![^\n]*--skip-shell)' },
    @{ Label = 'write to a chezmoi-managed target (AD-5)'; Pattern = '(?m)^(?!\s*#)[^\n]*(\.zshrc|\.gitconfig|\.config/(starship|nvim|tmux))' }
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
    @{ Label = 'Arch-only guard message (AD-7)'; Pattern = 'only Arch Linux is supported' },
    @{ Label = 'fnm installer with pinned dir and --skip-shell (AD-5)'; Pattern = 'curl -fsSL https://fnm\.vercel\.app/install \| bash -s -- --install-dir "\$FNM_DIR" --skip-shell' },
    @{ Label = 'fnm dir matching dot_zshrc'; Pattern = 'FNM_DIR="\$\{XDG_DATA_HOME:-\$HOME/\.local/share\}/fnm"' },
    @{ Label = 'login shell change via sudo chsh'; Pattern = 'sudo chsh -s "\$ZSH_PATH" "\$TARGET_USER"' }
)
foreach ($check in $requiredSetupPatterns) {
    if ($setupContent -notmatch $check.Pattern) {
        $failures.Add("setup.sh is missing the $($check.Label).")
    }
}

# The Arch-only guard belongs to preflight: before the checkout checks and before any package step.
$guardIndex = $setupContent.IndexOf('only Arch Linux is supported')
foreach ($marker in @('require_repo_asset_path ".git"', 'sudo pacman')) {
    $markerIndex = $setupContent.IndexOf($marker)
    if ($guardIndex -ge 0 -and $markerIndex -ge 0 -and $guardIndex -gt $markerIndex) {
        $failures.Add("setup.sh Arch-only guard must run in preflight before any package step (found after '$marker').")
    }
}

# --- Arch-only repository scope (AD-7, correct-course 2026-10-29) ---
foreach ($removedPath in @('setup.ps1', 'packages/scoop.txt', 'packages/winget.txt', 'packages/ubuntu.txt', 'tests/validate-setup-ps1.ps1')) {
    if (Test-Path -LiteralPath (Join-Path $repoRoot $removedPath)) {
        $failures.Add("$removedPath must not exist (Arch-only scope, AD-7).")
    }
}
foreach ($keptPath in @('packages/arch.txt', 'tests/lib/WslTestInstance.ps1')) {
    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $keptPath) -PathType Leaf)) {
        $failures.Add("$keptPath is missing.")
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
    if (Test-Instance "test -e $testHome/.ssh") {
        $failures.Add("[$scenario] setup.sh created ~/.ssh before failing.")
    }
}

# Swaps /etc/os-release (a relative symlink to ../usr/lib/os-release on Arch) for a fake; an empty
# $content only moves it away. Restore-OsRelease undoes either.
function Set-FakeOsRelease([string]$content) {
    # A leftover backup means an earlier run was interrupted mid-swap; never overwrite the real file with a fake.
    $bash = '! { [ -e /etc/os-release.config-v2-orig ] || [ -L /etc/os-release.config-v2-orig ]; } && mv /etc/os-release /etc/os-release.config-v2-orig'
    if (-not [string]::IsNullOrEmpty($content)) {
        $bash += ' && printf ''%s'' "$FAKE_OS_RELEASE" > /etc/os-release && chmod 0644 /etc/os-release'
    }
    $result = Invoke-Instance $bash @{ FAKE_OS_RELEASE = $content }
    if ($result.ExitCode -ne 0) { throw "Faking /etc/os-release failed: $($result.Output)" }
}

function Restore-OsRelease {
    $result = Invoke-Instance 'if [ -e /etc/os-release.config-v2-orig ] || [ -L /etc/os-release.config-v2-orig ]; then rm -f /etc/os-release && mv /etc/os-release.config-v2-orig /etc/os-release; fi'
    if ($result.ExitCode -ne 0) { throw "Restoring /etc/os-release failed: $($result.Output)" }
}

function Assert-NonArchRefused([string]$scenario, [string]$osRelease, [string]$expectedId) {
    Reset-Fixture
    try {
        Set-FakeOsRelease $osRelease
        $result = Invoke-Setup
        Assert-FailedBeforeMutation $scenario $result 'only Arch Linux is supported'
        if ($result.Output -notmatch [regex]::Escape("Unsupported distro '$expectedId'")) {
            $failures.Add("[$scenario] setup.sh did not report the detected distro '$expectedId'. Output: $($result.Output)")
        }
    }
    finally {
        Restore-OsRelease
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
cat <<'INSTALLER'
echo "fnm-installer `$*" >> $shimLog
dir=""
while [ `$# -gt 0 ]; do case "`$1" in --install-dir) dir="`$2"; shift 2 ;; *) shift ;; esac; done
[ -n "`$dir" ] || { echo "fake fnm installer: --install-dir missing" >&2; exit 1; }
mkdir -p "`$dir" && printf '#!/bin/sh\n' > "`$dir/fnm" && chmod +x "`$dir/fnm"
INSTALLER
SHIM
cat > $shimDir/chsh <<'SHIM'
#!/bin/bash
echo "chsh `$*" >> $shimLog
SHIM
chmod 0755 $shimDir/sudo $shimDir/pacman $shimDir/curl $shimDir/chsh
"@

# Fingerprint of the protected assets seeded by scenario K; throws when any asset cannot be read.
function Get-ProtectedAssetFingerprint {
    $result = Invoke-Instance "cd $testHome && sha256sum .ssh/id_rsa .ssh/id_rsa.pub .local/share/fnm/fnm && find .local/share/fnm | sort | sha256sum && stat -c '%a %n' .ssh .ssh/id_rsa"
    if ($result.ExitCode -ne 0) { throw "Protected asset fingerprint failed: $($result.Output)" }
    return $result.Output
}

if ($setupContent) {
    try {
        $instanceReady = $false
        try {
            New-ConfigV2TestInstance @('chezmoi', 'git', 'openssh', 'zsh')
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
                    if ($sudoLine -notmatch '^sudo (pacman|chsh) ') {
                        $failures.Add("[$scenario] setup.sh used sudo for a non-system command: $sudoLine")
                    }
                }
                if ($log -notmatch "(?m)^fnm-installer --install-dir $([regex]::Escape("$testHome/.local/share/fnm")) --skip-shell\s*$") {
                    $failures.Add("[$scenario] fnm installer did not run with --install-dir $testHome/.local/share/fnm --skip-shell. Shim log: $log")
                }
                if (-not (Test-Instance "test -x $testHome/.local/share/fnm/fnm")) {
                    $failures.Add("[$scenario] fnm was not installed to ~/.local/share/fnm.")
                }
                if ($log -notmatch "(?m)^sudo chsh -s /usr/bin/zsh $testUser\s*$") {
                    $failures.Add("[$scenario] setup.sh did not change the bash login shell to zsh via 'sudo chsh -s /usr/bin/zsh $testUser'. Shim log: $log")
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
                $sshModes = (Invoke-Instance "stat -c %a $testHome/.ssh $testHome/.ssh/id_rsa").Output -split "`r?`n" | ForEach-Object { $_.Trim() }
                if (($sshModes -join ',') -ne '700,600') {
                    $failures.Add("[$scenario] ~/.ssh and ~/.ssh/id_rsa modes are '$($sshModes -join ',')'; expected '700,600'.")
                }

                # AD-5: chezmoi manages exactly the managed targets, so no stateful path is ever a chezmoi target.
                $managed = Invoke-AsTester 'chezmoi managed --include=files'
                $managedList = @($managed.Output -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object)
                $expectedList = @($managedTargets | Sort-Object)
                if ($managed.ExitCode -ne 0 -or ($managedList -join '|') -ne ($expectedList -join '|')) {
                    $extra = @($managedList | Where-Object { $expectedList -notcontains $_ }) -join ', '
                    $missing = @($expectedList | Where-Object { $managedList -notcontains $_ }) -join ', '
                    $failures.Add("[$scenario] 'chezmoi managed --include=files' differs from the managed targets (extra: $extra; missing: $missing). $($managed.Output)")
                }

                # Scenario B: rerun on the same machine stays green, reapplies managed content, keeps stateful assets.
                $scenario = 'B rerun'
                $keyHash = (Invoke-Instance "sha256sum $testHome/.ssh/id_rsa").Output
                Invoke-AsTester "sh -c 'echo \# local-edit-marker >> $testHome/.zshrc'" | Out-Null
                if (-not (Test-Instance "grep -q local-edit-marker $testHome/.zshrc")) {
                    throw "[$scenario] could not seed the local edit marker in ~/.zshrc."
                }
                $rerun = Invoke-Setup
                if ($rerun.ExitCode -ne 0) {
                    $failures.Add("[$scenario] setup.sh rerun exited $($rerun.ExitCode). Output: $($rerun.Output)")
                }
                if ((Invoke-AsTester 'chezmoi verify').ExitCode -ne 0) {
                    $failures.Add("[$scenario] plain 'chezmoi verify' reports drift after rerun.")
                }
                if (Test-Instance "grep -q local-edit-marker $testHome/.zshrc") {
                    $failures.Add("[$scenario] local edit to the managed ~/.zshrc survived the rerun.")
                }
                if ((Invoke-Instance "sha256sum $testHome/.ssh/id_rsa").Output -ne $keyHash) {
                    $failures.Add("[$scenario] SSH key changed on rerun.")
                }
                $installerRuns = @((Get-ShimLog) -split "`r?`n" | Where-Object { $_ -match '^fnm-installer ' }).Count
                if ($installerRuns -ne 1) {
                    $failures.Add("[$scenario] fnm installer ran $installerRuns times across first run and rerun; expected 1.")
                }
                if ($rerun.Output -notmatch 'fnm already installed') {
                    $failures.Add("[$scenario] rerun did not report the existing fnm install.")
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

            # Scenario K: protected assets already exist on a first run; none is regenerated or changed (AD-5, FR3).
            $scenario = 'K protected assets pre-exist'
            $seed = @(
                "usermod -s /usr/bin/zsh $testUser",
                "$asTester mkdir -p -m 700 $testHome/.ssh $testHome/.local/share/fnm/node-versions/v0-fixture",
                "$asTester sh -c `"printf fake-private-key-fixture > $testHome/.ssh/id_rsa && chmod 600 $testHome/.ssh/id_rsa && printf fake-public-key-fixture > $testHome/.ssh/id_rsa.pub`"",
                "$asTester sh -c `"printf '#!/bin/sh\n' > $testHome/.local/share/fnm/fnm && chmod 755 $testHome/.local/share/fnm/fnm`""
            ) -join "`n"
            Reset-Fixture $seed
            $before = Get-ProtectedAssetFingerprint
            $run = Invoke-Setup
            if ($run.ExitCode -ne 0) {
                $failures.Add("[$scenario] setup.sh exited $($run.ExitCode). Output: $($run.Output)")
            }
            else {
                $log = Get-ShimLog
                if ($log -match '(?m)^(fnm-installer|chsh) ') {
                    $failures.Add("[$scenario] setup.sh reinstalled fnm or changed the login shell although both were present. Shim log: $log")
                }
                foreach ($message in @('SSH key already exists', 'fnm already installed', "Login shell for $testUser is already zsh")) {
                    if ($run.Output -notmatch [regex]::Escape($message)) {
                        $failures.Add("[$scenario] setup.sh output does not contain '$message'.")
                    }
                }
                $after = Get-ProtectedAssetFingerprint
                if ([string]::IsNullOrWhiteSpace($before) -or $after -ne $before) {
                    $failures.Add("[$scenario] protected assets changed. Before: $before After: $after")
                }
                if ((Invoke-Instance "stat -c %a $testHome/.ssh").Output.Trim() -ne '700') {
                    $failures.Add("[$scenario] ~/.ssh mode is not 700 after the run.")
                }
                foreach ($target in $managedTargets) {
                    if (-not (Test-Instance "test -f $testHome/$target")) {
                        $failures.Add("[$scenario] managed target ~/$target is missing.")
                    }
                }
                if ((Invoke-AsTester 'chezmoi verify').ExitCode -ne 0) {
                    $failures.Add("[$scenario] plain 'chezmoi verify' reports drift.")
                }
            }

            # Scenario L: an orphaned public key (private key missing) is never overwritten.
            $scenario = 'L orphaned public key kept'
            Reset-Fixture "$asTester mkdir -p -m 700 $testHome/.ssh && $asTester sh -c `"printf orphan-public-key-fixture > $testHome/.ssh/id_rsa.pub`""
            $run = Invoke-Setup
            if ($run.ExitCode -ne 0) {
                $failures.Add("[$scenario] setup.sh exited $($run.ExitCode). Output: $($run.Output)")
            }
            if ((Invoke-Instance "cat $testHome/.ssh/id_rsa.pub").Output.Trim() -ne 'orphan-public-key-fixture') {
                $failures.Add("[$scenario] the existing ~/.ssh/id_rsa.pub was overwritten.")
            }
            if (Test-Instance "test -e $testHome/.ssh/id_rsa") {
                $failures.Add("[$scenario] setup.sh generated a private key next to the orphaned public key.")
            }
            if ($run.Output -notmatch [regex]::Escape('without its private key')) {
                $failures.Add("[$scenario] setup.sh did not report the orphaned public key.")
            }

            # Scenarios H-J fake /etc/os-release, so they run last and always restore it (AD-7, NFR2).
            Assert-NonArchRefused 'H Ubuntu refused' "NAME=`"Ubuntu`"`nID=ubuntu`nID_LIKE=debian`n" 'ubuntu'
            Assert-NonArchRefused 'I Arch derivative refused' "NAME=`"EndeavourOS`"`nID=`"endeavouros`"`nID_LIKE=arch`n" 'endeavouros'
            Assert-NonArchRefused 'J os-release missing' '' 'unknown'
            if (-not (Test-Instance 'grep -qx "ID=arch" /etc/os-release')) {
                $failures.Add('[J os-release missing] /etc/os-release was not restored to ID=arch.')
            }
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
