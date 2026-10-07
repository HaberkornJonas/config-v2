$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$certificatePath = Join-Path $PSScriptRoot 'certs\zscaler-root-ca.crt'
$helperPath = Join-Path $PSScriptRoot 'lib\WslTestInstance.ps1'
$expectedCertificateSha256 = '04F61F1D13AAE1D16573DC2C37F796FDF4AC97713A6959EBB11D2473958B1A53'
$failures = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path -LiteralPath $certificatePath -PathType Leaf)) {
    $failures.Add("Required Zscaler root CA is missing: $certificatePath")
}

if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) {
    $failures.Add("Required WSL test helper is missing: $helperPath")
}

if ($failures.Count -eq 0) {
    $pem = Get-Content -LiteralPath $certificatePath -Raw
    $certificate = $null
    try {
        if ($pem -notmatch '(?s)\A\s*-----BEGIN CERTIFICATE-----(?<der>.*?)-----END CERTIFICATE-----\s*\z') {
            throw 'Expected exactly one PEM certificate block.'
        }

        $der = [Convert]::FromBase64String(($matches['der'] -replace '\s', ''))
        $certificate = [Security.Cryptography.X509Certificates.X509Certificate2]::new($der)
        $sha256 = [Security.Cryptography.SHA256]::Create()
        try {
            $certificateSha256 = [BitConverter]::ToString($sha256.ComputeHash($certificate.RawData)).Replace('-', '')
        }
        finally {
            $sha256.Dispose()
        }
        if ($certificateSha256 -ne $expectedCertificateSha256) {
            throw "Certificate fingerprint mismatch (expected $expectedCertificateSha256, got $certificateSha256)."
        }

        $now = [DateTime]::UtcNow
        if ($now -lt $certificate.NotBefore.ToUniversalTime() -or $now -gt $certificate.NotAfter.ToUniversalTime()) {
            throw "Certificate is not currently valid (valid from $($certificate.NotBefore.ToUniversalTime().ToString('u')) through $($certificate.NotAfter.ToUniversalTime().ToString('u')))."
        }

        $basicConstraints = @(
            $certificate.Extensions |
                Where-Object { $_.Oid.Value -eq '2.5.29.19' } |
                ForEach-Object { [Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]::new($_, $_.Critical) }
        )
        if ($basicConstraints.Count -ne 1 -or -not $basicConstraints[0].CertificateAuthority) {
            throw 'The certificate must contain a CA basic-constraints extension.'
        }
    }
    catch {
        $failures.Add("The checked-in Zscaler root CA is invalid: $($_.Exception.Message)")
    }
    finally {
        if ($null -ne $certificate) {
            $certificate.Dispose()
        }
    }

    $helperContent = Get-Content -LiteralPath $helperPath -Raw
    $checks = @(
        @{
            Label = 'certificate path derived from the helper location'
            Pattern = '(?m)Join-Path\s+\$PSScriptRoot\s+[''"]\.\.\\certs\\zscaler-root-ca\.crt[''"]'
        },
        @{
            Label = 'pinned certificate fingerprint'
            Pattern = [regex]::Escape($expectedCertificateSha256)
        },
        @{
            Label = 'certificate validation before removal of an existing WSL instance'
            Pattern = '(?s)function New-ConfigV2TestInstance.*?Get-ConfigV2ZscalerRootCertificate.*?if\s*\(Test-ConfigV2TestInstance\).*?Remove-ConfigV2TestInstance'
        },
        @{
            Label = 'certificate trust anchor staged in Arch before trust refresh'
            Pattern = '(?s)cat > /etc/ca-certificates/trust-source/anchors/config-v2-zscaler-root-ca\.crt.*?update-ca-trust'
        },
        @{
            Label = 'trust refresh before pacman operations'
            Pattern = '(?s)update-ca-trust.*?retry pacman -Syu'
        }
    )
    foreach ($check in $checks) {
        if ($helperContent -notmatch $check.Pattern) {
            $failures.Add("WSL test helper is missing required behavior: $($check.Label).")
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host 'WSL test CA validation failed:'
    foreach ($failure in $failures) {
        Write-Host "- $failure"
    }
    exit 1
}

Write-Host 'WSL test CA validation passed.'
