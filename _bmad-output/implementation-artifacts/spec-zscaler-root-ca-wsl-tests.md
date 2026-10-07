---
title: 'Trust the Zscaler root CA in Linux test instances'
type: 'chore'
created: '2026-10-07'
status: 'done'
review_loop_iteration: 0
baseline_commit: '01fbd7aa9ca70298c62ade2402701adf75fcfd5d'
context:
  - '{project-root}/tests/lib/WslTestInstance.ps1'
  - '{project-root}/tests/validate-setup.ps1'
  - '{project-root}/tests/validate-dotfiles.ps1'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The disposable Arch WSL test instance cannot download packages behind Zscaler because its trust store does not contain the organization's root CA. This blocks the existing Linux setup and dotfiles integration validations.

**Approach:** Check in a local copy of the specifically requested Zscaler root certificate and have the shared WSL test-instance helper validate and trust it before the instance accesses package mirrors. Limit the change to the disposable `config-v2-test` distribution.

## Boundaries & Constraints

**Always:** Preserve normal TLS verification. Validate the local PEM as a currently valid CA certificate before removing or creating a WSL instance. Import it into Arch's local trust anchors and run `update-ca-trust` before `pacman`. Preserve the helper's existing Windows-derived trusted roots and its existing fail-fast behavior.

**Ask First:** Changing the certificate source, trusting additional root certificates, or applying this trust change to any persistent/user WSL distribution or Windows itself.

**Never:** Disable TLS verification, use insecure package-manager flags, modify the production bootstrap scripts or managed dotfiles, or target any WSL distribution other than the dedicated `config-v2-test` instance.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Valid certificate | Checked-in PEM encodes a valid CA certificate | Add it to Arch's trust-source anchors and refresh trust before package operations | Normal setup continues |
| Missing or malformed certificate | Local asset is absent or cannot be parsed as a CA | Do not remove/create the WSL instance or start package operations | Throw a clear error naming the required asset |
| Trust refresh fails | Certificate was staged but `update-ca-trust` exits nonzero | Do not run `pacman` | Preserve the command output and fail instance preparation |

</frozen-after-approval>

## Code Map

- `tests/certs/zscaler-root-ca.crt` -- repository-local copy of the requested CA used only by disposable Linux tests
- `tests/lib/WslTestInstance.ps1` -- creates the test distribution, assembles trusted roots, and installs test packages
- `tests/validate-setup.ps1` -- exercises Linux setup behavior through the shared test instance
- `tests/validate-dotfiles.ps1` -- exercises chezmoi behavior through the shared test instance
- `tests/validate-wsl-test-ca.ps1` -- validates the checked-in certificate and trust-install ordering without requiring WSL

## Tasks & Acceptance

**Execution:**
- [x] `tests/certs/zscaler-root-ca.crt` -- add the certificate bytes from the user-specified public source -- keep the test trust anchor local and reproducible.
- [x] `tests/lib/WslTestInstance.ps1` -- validate and stage the certificate before destructive WSL setup, then trust it before `pacman` -- make both Linux integration validators work behind Zscaler without weakening TLS.
- [x] `tests/validate-wsl-test-ca.ps1` -- add offline checks for certificate validity and helper integration -- detect missing, malformed, non-CA, or incorrectly ordered trust setup.
- [x] `tests/validate-setup.ps1` and `tests/validate-dotfiles.ps1` -- run both existing integration validations -- confirm the shared disposable instance works with the new trust anchor.

**Acceptance Criteria:**
- Given a valid checked-in Zscaler root CA, when either Linux integration validator creates `config-v2-test`, then the certificate is trusted before package downloads begin.
- Given a missing, malformed, expired, or non-CA PEM, when the helper prepares a test instance, then it fails clearly before unregistering or creating a WSL distribution.
- Given the test instance is prepared, when package-manager TLS validation runs, then certificate verification remains enabled and succeeds through the trusted Zscaler root.
- Given other WSL distributions or Windows trust stores exist, when this feature runs, then only `config-v2-test` receives the imported certificate.

## Spec Change Log

## Verification

**Commands:**
- `powershell -NoProfile -File tests\validate-wsl-test-ca.ps1` -- expected: offline CA and ordering checks pass.
- `powershell -NoProfile -File tests\validate-setup.ps1` -- expected: Linux bootstrap integration checks pass. The new certificate removed the mirror TLS failure; this run later exited at the existing expected-root-refusal scenario with `Unexpected test error: ERROR: Do not run setup.sh as root`.
- `powershell -NoProfile -File tests\validate-dotfiles.ps1` -- expected: dotfiles integration checks pass.

Manual checks:
- The checked-in PEM exactly matches the requested GitHub source; its parsed subject is `CN=Zscaler Root CA`, CA basic constraints are present, and the pinned certificate SHA-256 is `04F61F1D13AAE1D16573DC2C37F796FDF4AC97713A6959EBB11D2473958B1A53`.
- `validate-dotfiles.ps1` completed successfully, including package downloads through the disposable WSL instance after trust refresh.

## Suggested Review Order

**Trust setup flow**

- Validate the pinned CA before the helper removes or creates the test distribution.
  [`WslTestInstance.ps1:32`](../../tests/lib/WslTestInstance.ps1#L32)
- Stage the certificate and refresh Arch's trust store before package downloads.
  [`WslTestInstance.ps1:222`](../../tests/lib/WslTestInstance.ps1#L222)

**Certificate and guardrails**

- Inspect the checked-in certificate and its source identity.
  [`zscaler-root-ca.crt:1`](../../tests/certs/zscaler-root-ca.crt#L1)
- Review the offline validation for fingerprint, CA constraints, and ordering.
  [`validate-wsl-test-ca.ps1:1`](../../tests/validate-wsl-test-ca.ps1#L1)

**Deferred pre-existing findings**

- Track the setup validator's expected-root-refusal handling separately.
  [`validate-setup.ps1:290`](../../tests/validate-setup.ps1#L290)
- Track regular-file validation in Linux bootstrap preflight separately.
  [`setup.sh:10`](../../setup.sh#L10)
  [`deferred-work.md:1`](./deferred-work.md#L1)
