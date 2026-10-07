- source_spec: `_bmad-output/implementation-artifacts/spec-zscaler-root-ca-wsl-tests.md`
  summary: Fix the WSL-backed setup validator so the expected root-refusal scenario records the setup.sh result instead of surfacing as an unexpected PowerShell error.
  evidence: After the Zscaler CA enabled package downloads, `tests/validate-setup.ps1` reached the root-refusal scenario and failed with `Unexpected test error: ERROR: Do not run setup.sh as root`; this predates the CA trust change.
- source_spec: `_bmad-output/implementation-artifacts/spec-zscaler-root-ca-wsl-tests.md`
  summary: Require regular files for setup.sh repo-local manifest and template preflight checks.
  evidence: `require_repo_asset_path` accepts a directory at a required file path because it checks `-e`; package changes can occur before later setup/chezmoi failure.
