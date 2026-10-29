- source_spec: `_bmad-output/implementation-artifacts/spec-zscaler-root-ca-wsl-tests.md`
  summary: Require regular files for setup.sh repo-local manifest and template preflight checks.
  evidence: `require_repo_asset_path` accepts a directory at a required file path because it checks `-e`; package changes can occur before later setup/chezmoi failure.

## Deferred from: code review of 3-1-align-setup-ps1-with-shared-repository-contract (2026-10-29)

- (moot: Arch-only scope, correct-course 2026-10-29) `tests/validate-setup-ps1.ps1` is regex-only: it never runs setup.ps1 (no mocked scoop/winget exit-code paths) and does not verify manifests are loaded before installs.
- Manifest parsing does not strip inline `#` comments in setup.ps1 (moot: Arch-only scope, correct-course 2026-10-29); the Arch Linux manifest is not comment/blank-filtered at all (still open).
- setup.sh (Story 2.2): preflight lacks a `sudo -v` rights check; legacy `chezmoi.yaml`/`chezmoi.json` configs are not detected. (`gpg --dearmor` without `--batch --yes` failing on Ubuntu reruns is moot: Arch-only scope, correct-course 2026-10-29.)
- tests/validate-setup.ps1 (Story 2.2): AC5 never seeds a stale chezmoi.toml; scenario G assumes the image lacks sudo; "chezmoi missing after packages" path untested; root scenario does not assert /root unchanged; a single fixture failure aborts all later scenarios. (The Ubuntu sudo substring heuristic is moot: Arch-only scope, correct-course 2026-10-29.)
- Story 2.2 marked `done` in sprint-status without a recorded code review; its "suite passed" claim conflicts with Story 3.1's Debug Log (scenario C abort before the WslTestInstance fix).
