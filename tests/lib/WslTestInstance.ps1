# Disposable Arch Linux WSL instance for config-v2 tests.
# Dot-source this file. Every function only ever targets the dedicated instance below,
# so other WSL distros on the machine are never touched.

$script:ConfigV2TestInstanceName = 'config-v2-test'
$script:ConfigV2DataRoot = Join-Path $env:LOCALAPPDATA 'config-v2'
$script:ConfigV2ImageCache = Join-Path $script:ConfigV2DataRoot 'wsl-cache'
$script:ConfigV2InstanceLocation = Join-Path (Join-Path $script:ConfigV2DataRoot 'wsl') $script:ConfigV2TestInstanceName
$script:ConfigV2ZscalerRootCertificatePath = Join-Path $PSScriptRoot '..\certs\zscaler-root-ca.crt'
# Pin the requested root certificate so a changed asset cannot silently alter the test trust store.
$script:ConfigV2ZscalerRootCertificateSha256 = '04F61F1D13AAE1D16573DC2C37F796FDF4AC97713A6959EBB11D2473958B1A53'
$script:WslManifestUrl = 'https://raw.githubusercontent.com/microsoft/WSL/master/distributions/DistributionInfo.json'
$script:ConfigV2TlsProbeHosts = @('geo.mirror.pkgbuild.com', 'fastly.mirror.pkgbuild.com', 'github.com')

function Invoke-WslExe([string[]]$arguments) {
    $previousUtf8 = $env:WSL_UTF8
    $env:WSL_UTF8 = '1'
    try {
        $output = & wsl.exe @arguments 2>&1 | ForEach-Object { "$_" }
        return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = (@($output) -join "`n").Trim() }
    }
    finally {
        $env:WSL_UTF8 = $previousUtf8
    }
}

function Test-ConfigV2TestInstance {
    $list = Invoke-WslExe @('--list', '--quiet')
    return @($list.Output -split "`r?`n" | ForEach-Object { $_.Trim() }) -contains $script:ConfigV2TestInstanceName
}

function Get-ConfigV2ZscalerRootCertificate {
    if (-not (Test-Path -LiteralPath $script:ConfigV2ZscalerRootCertificatePath -PathType Leaf)) {
        throw "Required Zscaler root CA is missing: $script:ConfigV2ZscalerRootCertificatePath"
    }

    $pem = [IO.File]::ReadAllText($script:ConfigV2ZscalerRootCertificatePath)
    if ($pem -notmatch '(?s)\A\s*-----BEGIN CERTIFICATE-----(?<der>.*?)-----END CERTIFICATE-----\s*\z') {
        throw "Required Zscaler root CA is not a single PEM certificate: $script:ConfigV2ZscalerRootCertificatePath"
    }

    $certificate = $null
    try {
        $der = [Convert]::FromBase64String(($matches['der'] -replace '\s', ''))
        $certificate = [Security.Cryptography.X509Certificates.X509Certificate2]::new($der)
        $sha256 = [Security.Cryptography.SHA256]::Create()
        try {
            $certificateSha256 = [BitConverter]::ToString($sha256.ComputeHash($certificate.RawData)).Replace('-', '')
        }
        finally {
            $sha256.Dispose()
        }
        if ($certificateSha256 -ne $script:ConfigV2ZscalerRootCertificateSha256) {
            throw "Certificate SHA-256 fingerprint mismatch (expected $script:ConfigV2ZscalerRootCertificateSha256, got $certificateSha256)."
        }

        $now = [DateTime]::UtcNow
        if ($now -lt $certificate.NotBefore.ToUniversalTime() -or $now -gt $certificate.NotAfter.ToUniversalTime()) {
            throw "Certificate is outside its validity period ($($certificate.NotBefore.ToUniversalTime().ToString('u')) through $($certificate.NotAfter.ToUniversalTime().ToString('u')))."
        }

        $isCertificateAuthority = $false
        foreach ($extension in $certificate.Extensions) {
            if ($extension.Oid.Value -eq '2.5.29.19') {
                $constraints = [Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]::new($extension, $extension.Critical)
                $isCertificateAuthority = $constraints.CertificateAuthority
                break
            }
        }
        if (-not $isCertificateAuthority) {
            throw 'Certificate does not assert CA basic constraints.'
        }
    }
    catch {
        throw "Invalid Zscaler root CA at '$script:ConfigV2ZscalerRootCertificatePath': $($_.Exception.Message)"
    }
    finally {
        if ($null -ne $certificate) {
            $certificate.Dispose()
        }
    }

    return [pscustomobject]@{
        Pem = $pem.Trim()
    }
}

# Returns PEM roots of the TLS chains Windows trusts for the probe hosts. Behind a TLS-inspecting
# proxy (e.g. Zscaler) this is the proxy root, which a fresh Linux instance does not trust yet.
function Get-ConfigV2HostTrustedRoots {
    $roots = @{}
    foreach ($probeHost in $script:ConfigV2TlsProbeHosts) {
        $client = $null
        $stream = $null
        try {
            $client = [Net.Sockets.TcpClient]::new($probeHost, 443)
            $stream = [Net.Security.SslStream]::new($client.GetStream(), $false, { $true })
            $stream.AuthenticateAsClient($probeHost)
            $chain = [Security.Cryptography.X509Certificates.X509Chain]::new()
            if ($chain.Build([Security.Cryptography.X509Certificates.X509Certificate2]$stream.RemoteCertificate)) {
                $root = $chain.ChainElements[$chain.ChainElements.Count - 1].Certificate
                $roots[$root.Thumbprint] = "-----BEGIN CERTIFICATE-----`n" +
                    [Convert]::ToBase64String($root.RawData, 'InsertLineBreaks').Replace("`r`n", "`n") +
                    "`n-----END CERTIFICATE-----"
            }
        }
        catch {
            Write-Host "INFO: TLS probe of $probeHost failed ($($_.Exception.Message)); skipping."
        }
        finally {
            if ($null -ne $stream) { $stream.Dispose() }
            if ($null -ne $client) { $client.Dispose() }
        }
    }
    return $roots
}

# Downloads the Arch WSL image listed in the official WSL manifest once and reuses it while the hash matches.
function Get-ConfigV2ArchImage {
    New-Item -ItemType Directory -Path $script:ConfigV2ImageCache -Force | Out-Null

    try {
        $manifest = Invoke-RestMethod -Uri $script:WslManifestUrl -UseBasicParsing
        $entry = $manifest.ModernDistributions.archlinux | Where-Object { $_.Name -eq 'archlinux' } | Select-Object -First 1
        if ($null -eq $entry) { throw 'archlinux entry not found in the WSL distribution manifest.' }
    }
    catch {
        $cached = Get-ChildItem -LiteralPath $script:ConfigV2ImageCache -Filter 'archlinux-*.wsl' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($null -ne $cached) {
            Write-Host "INFO: WSL manifest unavailable ($($_.Exception.Message)); using cached image $($cached.Name)."
            return $cached.FullName
        }
        throw "Cannot resolve the Arch Linux WSL image: $($_.Exception.Message)"
    }

    $url = $entry.Amd64Url.Url
    $expectedHash = $entry.Amd64Url.Sha256.ToLowerInvariant()
    $imagePath = Join-Path $script:ConfigV2ImageCache ([IO.Path]::GetFileName(([uri]$url).AbsolutePath))

    if ((Test-Path -LiteralPath $imagePath) -and (Get-FileHash -LiteralPath $imagePath -Algorithm SHA256).Hash.ToLowerInvariant() -eq $expectedHash) {
        return $imagePath
    }

    Write-Host "INFO: Downloading Arch Linux WSL image $url"
    $partialPath = "$imagePath.partial"
    $previousProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        Invoke-WebRequest -Uri $url -OutFile $partialPath -UseBasicParsing
    }
    finally {
        $ProgressPreference = $previousProgress
    }

    $actualHash = (Get-FileHash -LiteralPath $partialPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $expectedHash) {
        Remove-Item -LiteralPath $partialPath -Force
        throw "Arch Linux WSL image hash mismatch (expected $expectedHash, got $actualHash)."
    }
    Move-Item -LiteralPath $partialPath -Destination $imagePath -Force
    return $imagePath
}

function Remove-ConfigV2TestInstance {
    if (Test-ConfigV2TestInstance) {
        Invoke-WslExe @('--terminate', $script:ConfigV2TestInstanceName) | Out-Null
        $result = Invoke-WslExe @('--unregister', $script:ConfigV2TestInstanceName)
        if ($result.ExitCode -ne 0) {
            throw "Failed to unregister WSL instance $($script:ConfigV2TestInstanceName): $($result.Output)"
        }
    }
    if (Test-Path -LiteralPath $script:ConfigV2InstanceLocation) {
        Remove-Item -LiteralPath $script:ConfigV2InstanceLocation -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Runs a bash script as root inside the test instance. The script travels base64-encoded so
# quoting and Windows line endings never reach bash.
function Invoke-ConfigV2TestInstance([string]$bashScript, [hashtable]$environment = @{}) {
    $exports = foreach ($entry in $environment.GetEnumerator()) {
        if ($entry.Key -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') { throw "Invalid environment variable name: $($entry.Key)" }
        "export $($entry.Key)='" + ([string]$entry.Value).Replace("'", "'\''") + "'"
    }
    $fullScript = ((@('set -euo pipefail') + @($exports) + @($bashScript)) -join "`n").Replace("`r`n", "`n")
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($fullScript))

    $previousEncoding = [Console]::OutputEncoding
    [Console]::OutputEncoding = [Text.Encoding]::UTF8
    try {
        $output = & wsl.exe -d $script:ConfigV2TestInstanceName --user root --cd / --exec /bin/bash -c "echo $encoded | base64 -d | /bin/bash" 2>&1 |
            ForEach-Object { "$_" }
        return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = (@($output) -join "`n") }
    }
    finally {
        [Console]::OutputEncoding = $previousEncoding
    }
}

# Creates a fresh config-v2-test instance (replacing a leftover one) and installs the requested packages.
function New-ConfigV2TestInstance([string[]]$packages = @()) {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        throw 'wsl.exe not found. WSL 2 is required to run Linux-side config-v2 tests.'
    }

    $zscalerRootCertificate = Get-ConfigV2ZscalerRootCertificate

    if (Test-ConfigV2TestInstance) {
        Write-Host "INFO: Removing leftover WSL instance $($script:ConfigV2TestInstanceName)."
        Remove-ConfigV2TestInstance
    }

    $image = Get-ConfigV2ArchImage
    New-Item -ItemType Directory -Path $script:ConfigV2InstanceLocation -Force | Out-Null
    Write-Host "INFO: Creating WSL instance $($script:ConfigV2TestInstanceName) from $([IO.Path]::GetFileName($image))."
    $install = Invoke-WslExe @('--install', '--from-file', $image, '--name', $script:ConfigV2TestInstanceName, '--location', $script:ConfigV2InstanceLocation, '--no-launch', '--version', '2')
    if ($install.ExitCode -ne 0 -or -not (Test-ConfigV2TestInstance)) {
        throw "Failed to create WSL instance $($script:ConfigV2TestInstanceName): $($install.Output)"
    }

    $prepare = New-Object System.Collections.Generic.List[string]
    $prepare.Add("cat > /etc/ca-certificates/trust-source/anchors/config-v2-zscaler-root-ca.crt <<'PEM'`n$($zscalerRootCertificate.Pem)`nPEM")
    foreach ($entry in (Get-ConfigV2HostTrustedRoots).GetEnumerator()) {
        $prepare.Add("cat > /etc/ca-certificates/trust-source/anchors/config-v2-host-$($entry.Key.ToLowerInvariant()).crt <<'PEM'`n$($entry.Value)`nPEM")
    }
    $prepare.Add('update-ca-trust')
    $prepare.Add('pacman-key --init >/dev/null 2>&1')
    $prepare.Add('pacman-key --populate archlinux >/dev/null 2>&1')
    $prepare.Add('retry() { for attempt in 1 2 3; do "$@" && return 0; echo "retry $attempt failed: $*" >&2; sleep 5; done; return 1; }')
    $prepare.Add('retry pacman -Syu --noconfirm --needed --disable-download-timeout >/dev/null')
    if ($packages.Count -gt 0) {
        $prepare.Add('retry pacman -S --noconfirm --needed --disable-download-timeout ' + ($packages -join ' ') + ' >/dev/null')
    }
    $result = Invoke-ConfigV2TestInstance ($prepare -join "`n")
    if ($result.ExitCode -ne 0) {
        throw "Failed to prepare WSL instance $($script:ConfigV2TestInstanceName): $($result.Output)"
    }
}
