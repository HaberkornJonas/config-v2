# Story 3.1: Align setup.ps1 with the Shared Repository Contract

Status: ready-for-dev

> **Sequencing (correct-course 2026-10-07):** implement after Epic 2 Stories 2.1–2.2 land, because this story needs `dotfiles/` and the repo-root contract to exist. This story was originally created as Story 2.1; the epics were renumbered when the delivered Linux bootstrap was closed as Epic 1. Also honor the new spine rule AD-8 (bootstrap configuration is the canonical key schema; no `DOTFILES_REPO`).

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer using the Windows companion bootstrap,
I want `setup.ps1` to follow the same repository-root contract as Linux,
so that both entry points share one coherent repository model.

## Acceptance Criteria

1. **Given** the Windows companion bootstrap entry point, **When** I inspect its expected inputs and path assumptions, **Then** it is defined relative to the shared `config-v2` checkout **And** it does not assume a separate remote dotfiles repository as the supported model (FR4, AD-1, AD-3)

2. **Given** the Windows bootstrap design, **When** I review ownership boundaries, **Then** package installation remains delegated to Scoop and winget **And** any managed-config integration stays consistent with the orchestrator-delegates rule (NFR4, AD-2)

## Tasks / Subtasks

- [ ] Task 1: Create the Windows entry point at the repo root (AC: 1, 2)
  - [ ] Add `setup.ps1` beside `setup.sh` and derive all repo-local paths from `$PSScriptRoot`, not from the caller's current directory.
  - [ ] Fail clearly if required repo assets for the supported Windows flow are missing from the local checkout.
  - [ ] Keep bootstrap configuration with `setup.ps1` itself; do not reintroduce `config.sh` parsing or any other cross-shell config dependency.
- [ ] Task 2: Preserve the orchestrator-only ownership model (AC: 2)
  - [ ] Sequence delegate calls only: Windows package-manager preparation, package installation, and any explicitly supported managed-config handoff.
  - [ ] Do not embed dotfile content, merge logic, or repo-specific package-install implementations in `setup.ps1`.
  - [ ] Keep package definitions outside orchestration logic where practical so future Windows package updates are data changes, not script rewrites.
- [ ] Task 3: Implement Windows package-manager delegation through Scoop and winget (AC: 2)
  - [ ] Use Scoop and winget as the only software-install delegates.
  - [ ] Use non-interactive/silent flags appropriate for scripted execution.
  - [ ] Prefer exact package identifiers and explicit agreement flags for winget installs so repeated runs are deterministic and unattended.
- [ ] Task 4: Enforce the shared repository-root contract (AC: 1)
  - [ ] Resolve Windows bootstrap inputs relative to the `config-v2` checkout root.
  - [ ] Do not clone or reference a second dotfiles repository as the supported path.
  - [ ] If managed-config work is touched, point only at repo-local `dotfiles/` content and keep deep Windows dotfiles integration limited to what the current architecture explicitly supports.
- [ ] Task 5: Add targeted validation for the new entry point (AC: 1, 2)
  - [ ] Add a PowerShell validation script under `tests/` that asserts `setup.ps1` exists and follows the required repo-root and delegation patterns.
  - [ ] If README text must change to stay truthful after implementation, update `tests/validate-readme.ps1` in the same change.
  - [ ] Validate from Windows-friendly commands only (for example `powershell -File tests\\...`).
- [ ] Task 6: Verify rerun-safe behavior and story scope boundaries (AC: 1, 2)
  - [ ] Confirm the implementation does not invent unsupported WSL2/Linux-user bootstrap automation.
  - [ ] Confirm the implementation does not restore the old two-repo assumption anywhere in code, docs, or tests.
  - [ ] Confirm all behavior added in this story is explicit enough for Story 3.2 documentation work to describe accurately.

## Dev Notes

### Story-Specific Implementation Guidance

- This story creates the first real Windows entry point: `setup.ps1` does **not** exist in the repo yet.
- Follow the newest architecture spine from 2026-08-07, not the older two-repo architecture or earlier story artifacts that still mention `config.sh` or `DOTFILES_REPO`.
- Mirror proven script patterns from `setup.sh` only where they still match the current contract: fail-fast behavior, repo-root-safe path handling, clear INFO/ERROR output, and orchestration sequencing.
- Do **not** copy the current Linux script's remote-dotfiles assumption. `setup.sh` still calls `chezmoi init --apply "$DOTFILES_REPO"` today, but that is precisely the drift the new architecture is correcting.
- Deep Windows dotfiles integration remains deferred by architecture. If this story touches managed-config behavior, keep it minimal, explicit, and aligned with repo-local `dotfiles/` ownership instead of inventing half-supported remote flows.
- Host-only concerns such as Nerd Font installation remain outside repo automation unless the architecture explicitly adds them later.

### Relevant Existing Files (Read Before Editing)

#### `setup.sh`

- **Current state:** Existing Linux bootstrap entry point with inline configuration, distro dispatch, stateful-asset guards, and a final chezmoi handoff.
- **What this story changes:** No direct Linux change is required, but `setup.sh` is the closest implementation reference for sequencing, logging tone, and bootstrap-script structure.
- **What must be preserved:** Do not blindly port the remote `DOTFILES_REPO` model or Linux-specific assumptions into Windows.

#### `README.md`

- **Current state:** Already documents the expected Windows command as `powershell -ExecutionPolicy Bypass -File .\\setup.ps1`, but the wording is still partially future-facing because `setup.ps1` does not exist yet.
- **What this story changes:** Only update README if the implemented Windows flow would otherwise make the current text inaccurate. Broad Windows documentation belongs to Story 3.2.
- **What must be preserved:** Keep the Windows section honest about current support and avoid promising deferred deep integration.

#### `tests/validate-readme.ps1`

- **Current state:** Existing PowerShell validation script that already checks the Windows companion heading and exact invocation command in `README.md`.
- **What this story changes:** Update only if README wording must change to remain truthful after `setup.ps1` lands.
- **What must be preserved:** Keep the existing fail-fast PowerShell style, repo-root-safe path construction, and focused validation scope.

#### `packages/arch.txt` and `packages/ubuntu.txt`

- **Current state:** Linux package manifests are one-package-per-line plaintext lists under `packages/`.
- **What this story changes:** If Windows package definitions are needed, keep them in the same repo-owned manifest area rather than burying identifiers deep inside orchestration code.
- **What must be preserved:** Package ownership stays with the package-manager layer, not with bespoke install logic inside `setup.ps1`.

### Architecture Compliance (MUST FOLLOW)

| Rule | Requirement for this story |
| --- | --- |
| AD-1 | Treat `dotfiles/` in this repo as the supported managed-config source; do not assume a second remote dotfiles repository. |
| AD-2 | `setup.ps1` is an orchestrator only: delegate package installation to Scoop/winget and any managed config to chezmoi rather than implementing those concerns directly. |
| AD-3 | The supported execution path is a local `config-v2` checkout from repository root; all paths must resolve relative to that checkout, not the caller's working directory. |
| AD-4 | Any tracked managed-config content must stay public-safe and usable as a clean bootstrap test fixture. |
| AD-5 | If the story touches file ownership boundaries, keep each path in exactly one category: `stateful-asset` or `chezmoi-managed`, never both. |
| AD-6 | Validation belongs in the repo and should give a clear signal that the Windows entry point follows the expected contract. |
| AD-8 | Every value `setup.ps1` reads is declared in a configuration block at the top of `setup.ps1`, using the canonical key names shared with `setup.sh` where the concept overlaps (`GIT_USER_NAME`, `GIT_USER_EMAIL`, `GPG_FINGERPRINT`, `SSH_KEY_FILE`). No `DOTFILES_REPO`. |
| Deferred Windows integration | Do not invent full Windows-deep-integration behavior that the architecture explicitly defers. |

### Technical Requirements

- Use PowerShell-native fail-fast behavior (`$ErrorActionPreference = 'Stop'`, `Set-StrictMode -Version Latest`) consistent with the existing test script style.
- Resolve repo-local paths from `$PSScriptRoot` and `Join-Path`; do not depend on `Set-Location` or the shell's current directory.
- Keep all tracked configuration values public-safe. Do not commit secrets, tokens, passwords, or machine-unique credentials.
- Avoid broad catch-and-continue behavior. Let command failures surface clearly unless the repo already uses a more precise pattern.
- Keep Windows-specific package identifiers deterministic and explicit; prefer exact package IDs over ambiguous display-name searches.
- If `chezmoi` is invoked from Windows in this story, it must target repo-local content and remain a delegated handoff rather than custom file-copy logic.

### Library / Framework Requirements

- **PowerShell:** Use native PowerShell script patterns already present in `tests/validate-readme.ps1`; do not add external PowerShell modules unless validation proves they are already required.
- **Scoop:** Treat Scoop as a supported Windows package manager. Current official guidance still documents the default non-admin install path via `irm get.scoop.sh | iex`; if bootstrapping Scoop itself is needed, use the official installer flow rather than custom download logic.
- **winget:** Use the Windows Package Manager `install` command with exact IDs and non-interactive flags where applicable. Current Microsoft documentation supports flags such as `--id`, `--exact`, `--silent`, `--accept-package-agreements`, `--accept-source-agreements`, and `--disable-interactivity` for unattended installs.
- **chezmoi:** Keep it in the delegate role only. Do not move managed-config state logic into `setup.ps1`.

### File Structure Requirements

- **Create:** `setup.ps1` at the repo root beside `setup.sh`.
- **Create (if needed for clean ownership):** Windows-specific package manifests under `packages/` rather than hardcoding long install lists inside `setup.ps1`.
- **Create:** a targeted validation script in `tests/` for the Windows bootstrap contract.
- **Update only if needed:** `README.md` and `tests/validate-readme.ps1`.
- **Do not create:** remote-dotfiles bootstrap helpers, cross-shell config parsers, or WSL2 provisioning automation.

### Testing Requirements

- Add the smallest targeted PowerShell validation that proves the Windows entry point follows the repository-root and orchestrator-delegates contract.
- Keep validation Windows-friendly and runnable from the repo root, for example:
  - `powershell -File tests\\validate-setup-ps1.ps1`
  - `powershell -File tests\\validate-readme.ps1` (only if README changes)
- Validate that:
  - `setup.ps1` exists at the repo root
  - repo-root path helpers are used instead of caller-CWD assumptions
  - the script delegates installs to Scoop and winget
  - the script does not reference a remote dotfiles repository or resurrect `config.sh`

### Cross-Story / Recent-Work Intelligence

- Story 1.4 established the basic bootstrap orchestration shape: strict mode, clear stage ordering, and direct delegation to domain tools. Reuse that shape, not its now-stale remote-dotfiles details.
- Story 1.5 already documented the intended Windows invocation in `README.md`. Any code added here should keep that command valid.
- Recent commits use short conventional subjects with explicit story references, for example `feat: add setup.sh Linux bootstrap orchestrator (Story 1.4)`.
- The architecture memlog explicitly records that Windows companion bootstrap remains secondary and that deep Windows-dotfiles integration is deferred. Scope discipline matters here.

### Latest Technical Information

- Microsoft Learn (updated July 2026) documents `winget install` as supporting exact-ID installs and silent/unattended flags. Use exact IDs plus agreement flags to reduce interactive prompts and ambiguity.
- Scoop's official installer README still documents the default installation path as a non-admin PowerShell command (`irm get.scoop.sh | iex`) and notes execution-policy prerequisites. If the script installs Scoop when missing, use that supported path instead of a custom bootstrap implementation.
- Treat both package managers as delegates; do not inline app installers or bespoke download/extract logic in this repo unless architecture changes explicitly require it.

### Project Structure Notes

- Current repo root contains `setup.sh`, `README.md`, `packages/`, and `tests/`, but no `setup.ps1` yet.
- There is no `project-context.md` persistent-fact file in the repo today, so the story must lean on the epics, spec, architecture spine, and existing code instead.
- No dedicated UX artifact was found for this planning run; keep user-facing console behavior simple, explicit, and truthful.

### References

- [epics.md - Story 3.1](../planning-artifacts/epics.md)
- [sprint-change-proposal-2026-10-07.md](../planning-artifacts/sprint-change-proposal-2026-10-07.md)
- [ARCHITECTURE-SPINE.md - 2026-08-07 spine](../planning-artifacts/architecture/architecture-config-v2-dotfiles-integration-2026-08-07/ARCHITECTURE-SPINE.md)
- [architecture memlog](../planning-artifacts/architecture/architecture-config-v2-dotfiles-integration-2026-08-07/.memlog.md)
- [SPEC.md - CAP-4 and constraints](../specs/spec-dev-env-config-repo/SPEC.md)
- [stack.md - Windows companion and scripting convention](../specs/spec-dev-env-config-repo/stack.md)
- [implementation-readiness-report-2026-08-05.md](../planning-artifacts/implementation-readiness-report-2026-08-05.md)
- [setup.sh](../../setup.sh)
- [README.md](../../README.md)
- [tests/validate-readme.ps1](../../tests/validate-readme.ps1)
- [packages/arch.txt](../../packages/arch.txt)
- [packages/ubuntu.txt](../../packages/ubuntu.txt)

## Dev Agent Record

### Agent Model Used

GPT-5.4 (Copilot CLI runtime)

### Debug Log References

- Create-story workflow activation completed with manual workflow resolution because the resolver requires Python 3.11+ in this environment.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- No dedicated PRD, UX artifact, or `project-context.md` file was available; the story uses epics, spec, architecture, repo code, and recent git history as the authoritative context set.
- Story scope intentionally guards against copying the stale two-repo / `config.sh` assumptions still present in older artifacts.

### File List

- `setup.ps1` (new, expected implementation target)
- `tests/validate-setup-ps1.ps1` (recommended targeted validation)
- `README.md` (update only if required for truthfulness)
- `tests/validate-readme.ps1` (update only if README changes)
