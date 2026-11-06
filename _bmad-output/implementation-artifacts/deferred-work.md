- source_spec: `_bmad-output/implementation-artifacts/spec-zscaler-root-ca-wsl-tests.md`
  summary: Require regular files for setup.sh repo-local manifest and template preflight checks.
  evidence: `require_repo_asset_path` accepts a directory at a required file path because it checks `-e`; package changes can occur before later setup/chezmoi failure.

## Deferred from: code review of 3-1-align-setup-ps1-with-shared-repository-contract (2026-10-29)

- (moot: Arch-only scope, correct-course 2026-10-29) `tests/validate-setup-ps1.ps1` is regex-only: it never runs setup.ps1 (no mocked scoop/winget exit-code paths) and does not verify manifests are loaded before installs.
- Manifest parsing does not strip inline `#` comments in setup.ps1 (moot: Arch-only scope, correct-course 2026-10-29); the Arch Linux manifest is not comment/blank-filtered at all (still open).
- setup.sh (Story 2.2): preflight lacks a `sudo -v` rights check; legacy `chezmoi.yaml`/`chezmoi.json` configs are not detected. (`gpg --dearmor` without `--batch --yes` failing on Ubuntu reruns is moot: Arch-only scope, correct-course 2026-10-29.)
- tests/validate-setup.ps1 (Story 2.2): AC5 never seeds a stale chezmoi.toml; scenario G assumes the image lacks sudo; "chezmoi missing after packages" path untested; root scenario does not assert /root unchanged; a single fixture failure aborts all later scenarios. (The Ubuntu sudo substring heuristic is moot: Arch-only scope, correct-course 2026-10-29.)
- Story 2.2 marked `done` in sprint-status without a recorded code review; its "suite passed" claim conflicts with Story 3.1's Debug Log (scenario C abort before the WslTestInstance fix).

## Deferred from: code review of 2-6-narrow-the-bootstrap-to-arch-linux-only (2026-11-02)

- tests/validate-setup.ps1: guard-order static check keys on the first occurrence of the message text `only Arch Linux is supported`, not the `if [[ "$DISTRO" != "arch" ]]` guard; a comment containing that text above `sudo pacman` would mask a moved guard.
- tests/validate-setup.ps1: no scenario covers a quoted `ID="arch"` (accepted) or an os-release without an `ID` line (refused as `unknown`).

## Deferred from: code review of 2-3-preserve-stateful-asset-safety-in-the-integrated-flow (2026-11-02)

- setup.sh: fnm install is not verified afterwards (`$FNM_DIR/fnm` may be absent even when the installer exits 0, causing a reinstall on every rerun); the remote installer is unpinned.
- setup.sh: a failing `sudo chsh` (non-local NSS user, path not in `/etc/shells`) aborts the bootstrap before SSH key generation and the chezmoi apply.
- tests/validate-setup.ps1: scenario K seeds no `~/.gnupg` to prove it is untouched; the `curl` shim serves the fake fnm installer for any URL.
