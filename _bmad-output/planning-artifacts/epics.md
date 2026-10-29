---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
  - step-04-final-validation
inputDocuments:
  - _bmad-output/specs/spec-dev-env-config-repo/SPEC.md
  - _bmad-output/planning-artifacts/architecture/architecture-config-v2-dotfiles-integration-2026-08-07/ARCHITECTURE-SPINE.md
---

# config-v2 - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for config-v2, decomposing the requirements from the SPEC and Architecture Spine into implementable stories.

## Requirements Inventory

### Functional Requirements

FR1: A developer can bootstrap a fresh Arch Linux (WSL or VM) development environment from a local checkout of `config-v2` by running `./setup.sh`, with packages installed and integrated dotfiles applied from the same repository.

FR2: A developer can apply and sync tracked dotfiles across machines via `chezmoi` using the in-repo `dotfiles/` source tree as the authoritative managed configuration source.

FR3: A developer can rerun setup on an existing environment without destroying stateful assets such as SSH keys or other explicitly protected local state.

FR4: (Removed by correct-course 2026-10-29 — Windows companion bootstrap deferred.)

### NonFunctional Requirements

NFR1: The repository remains public-safe: no secrets, private keys, passwords, or machine-unique credentials are committed.

NFR2: Arch Linux (WSL or VM) is the only supported target; packages come from `packages/arch.txt`, and `setup.sh` refuses other distros before any mutation.

NFR3: Once the local checkout is ready, the bootstrap flow is silent and non-interactive.

NFR4: Package managers own software installation, chezmoi owns managed configuration state, and setup scripts act only as orchestrators.

NFR5: Managed configuration is always reapplied as tracked content; stateful assets are detect-before-mutate and never overwritten if already present.

NFR6: The supported setup flow runs from a local repository checkout and resolves managed content and manifests via repo-relative paths.

NFR7: The setup flow includes a repo-local smoke verification stage so setup success is measurable rather than inferred from exit code alone.

### Additional Requirements

- Integrate all chezmoi-managed source files under `config-v2/dotfiles/`; `setup.sh` must stop depending on a separate remote dotfiles repository.
- Preserve strict ownership boundaries: setup entry points sequence package install, stateful-asset preparation, local chezmoi apply, and verification only.
- Classify every bootstrap-touched path as either `stateful-asset` or `chezmoi-managed`; no path may belong to both categories.
- Keep tracked dotfiles content usable as a clean bootstrap test fixture by templating or excluding personal and machine-unique state.
- Add repo-local smoke verification that checks expected tools, key managed files/symlinks, and primary shell/editor entrypoints after apply.
- Refresh the README and its validation test, which still describe the previous two-repo model (upstream SPEC and architecture were refreshed by correct-course 2026-10-07).

### UX Design Requirements

No UX design contract exists for this planning run.

### FR Coverage Map

| FR | Epic | Brief description |
| --- | --- | --- |
| FR1 | Epic 2 | local-checkout Arch Linux bootstrap with integrated in-repo dotfiles |
| FR2 | Epic 2 | dotfiles sync through the in-repo `dotfiles/` source tree |
| FR3 | Epic 2 | idempotent rerun with protected stateful assets |
| FR4 | — | removed (deferred) by correct-course 2026-10-29 |

## Epic List

### Epic 1: Linux Bootstrap (delivered, closed 2026-10-07)
Delivered `packages/arch.txt`, `packages/ubuntu.txt`, `setup.sh` (distro dispatch, package install, SSH/GPG detect-before-mutate guards, remote chezmoi init) and the README. Closed by correct-course 2026-10-07 as the base the in-repo dotfiles work extends; story files `1-1` to `1-5` are kept as history. Superseded parts: remote `DOTFILES_REPO` apply and two-repo README wording, both reworked in Epic 2. `packages/ubuntu.txt` and the Ubuntu branch are removed by Story 2.6 (Arch-only scope, correct-course 2026-10-29).
**Status:** done (see `sprint-change-proposal-2026-10-07.md`)

### Epic 2: Integrated Arch Linux Bootstrap and Dotfiles Sync
The developer can clone `config-v2`, run `./setup.sh`, and reach a reproducible Arch Linux environment where packages, managed dotfiles, rerun safety, and smoke verification all work from the same repository.
**FRs covered:** FR1, FR2, FR3

### Epic 3: Windows Companion Alignment (removed 2026-10-29)
Dropped by correct-course 2026-10-29 (Arch Linux only); Story 3.1 cancelled, Story 3.2 dropped. See `sprint-change-proposal-2026-10-29.md`.

## Epic 2: Integrated Arch Linux Bootstrap and Dotfiles Sync

The developer can clone `config-v2`, run `./setup.sh`, and reach a reproducible Arch Linux environment where packages, managed dotfiles, rerun safety, and smoke verification all work from the same repository.

**Sequencing:** Story 2.6 is implemented next, before Story 2.3 (correct-course 2026-10-29).

### Story 2.1: Create an In-Repo Dotfiles Source Tree

As a developer testing the bootstrap flow,
I want the managed dotfiles source to live under `config-v2/dotfiles/`,
So that the repository itself contains the exact configuration state the setup flow applies.

**Acceptance Criteria:**

**Given** the repository root,
**When** I inspect the source tree,
**Then** a `dotfiles/` directory exists as the authoritative chezmoi-managed source location
**And** its placement matches the architecture contract in the in-repo dotfiles spine (AD-1, AD-3)

**Given** content added under `dotfiles/`,
**When** I review it for test-fixture safety,
**Then** no secrets, private keys, passwords, or machine-unique credentials are committed
**And** any personal values are templated, safe by default, or explicitly left to local untracked inputs (AD-4, NFR1)
**And** `dotfiles/` contains no `run_once_` script that installs packages or orchestrates setup (AD-9)

### Story 2.2: Apply Local Dotfiles from setup.sh

As a developer bootstrapping a Linux machine,
I want `setup.sh` to apply dotfiles from the local checkout,
So that the full setup flow works from one cloned repository without a second dotfiles remote.

**Acceptance Criteria:**

**Given** a local checkout of `config-v2`,
**When** `setup.sh` reaches the managed-config stage,
**Then** it applies `dotfiles/` from the local repository via chezmoi
**And** it no longer requires or references a separate remote dotfiles repository as the supported path (FR1, FR2, AD-1)

**Given** `setup.sh`,
**When** I audit its path handling,
**Then** it resolves `packages/` and `dotfiles/` relative to repository root
**And** it fails clearly if required repo-local assets are missing (AD-3, NFR6)
**And** the existing `./packages/*.txt` reads are converted to repository-root-relative paths (current code reads relative to the caller's working directory)
**And** `DOTFILES_REPO` is removed from the configuration block (AD-8)

### Story 2.3: Preserve Stateful-Asset Safety in the Integrated Flow

As a developer rerunning setup on an existing machine,
I want stateful local assets to stay protected while managed config is reapplied,
So that I can update my environment without losing SSH keys or other protected state.

**Acceptance Criteria:**

**Given** the integrated setup flow,
**When** I classify bootstrap-touched paths,
**Then** every path is assigned to exactly one category: `stateful-asset` or `chezmoi-managed`
**And** no path is written by both setup scripts and chezmoi (AD-5)

**Given** a machine where protected assets already exist,
**When** `setup.sh` is rerun,
**Then** stateful assets are detected and preserved
**And** managed dotfiles are still reapplied from `dotfiles/` to reach the latest tracked state (FR2, FR3, NFR5)

### Story 2.4: Add Smoke Verification for Integrated Bootstrap

As a developer validating the setup flow,
I want a repo-local smoke verification stage,
So that successful bootstrap means the machine is actually usable, not just that the script exited zero.

**Acceptance Criteria:**

**Given** the supported Arch Linux setup flow,
**When** package installation and local dotfile apply complete,
**Then** a repo-local verification stage runs automatically or via a documented repo-local command
**And** it checks the expected package toolchain, key managed files or symlinks, and primary shell or editor entrypoints (AD-6, NFR7)

**Given** verification detects a missing expected outcome,
**When** the check fails,
**Then** the result is surfaced as an actionable failure signal
**And** the user can tell which part of the integrated setup flow is broken (FR1, FR3)

### Story 2.5: Refresh Arch Linux Documentation and README Validation

As a developer using or maintaining this repository,
I want the documentation and its validation test to describe the in-repo dotfiles model,
So that the supported workflow is clear and the README stays truthful as the setup flow evolves.

**Acceptance Criteria:**

**Given** the repository documentation,
**When** I read the bootstrap flow description,
**Then** it describes `dotfiles/` as part of `config-v2` rather than a separate dotfiles repository
**And** it explains the local-checkout execution contract and verification expectations (FR1, AD-1, AD-3, AD-6)
**And** it states Arch Linux (WSL or VM) as the only supported target and lists Windows and other distros as deferred (FR1, NFR2)

**Given** the updated docs,
**When** I review examples and configuration guidance,
**Then** no sensitive values are introduced
**And** the public-safe and test-fixture-safe rules remain explicit (NFR1, AD-4)

**Given** `tests/validate-readme.ps1`,
**When** the README is updated,
**Then** the two-repo and `DOTFILES_REPO` assertions are replaced by in-repo dotfiles, local-checkout, and verification assertions
**And** the test passes against the new README

### Story 2.6: Narrow the Bootstrap to Arch Linux Only

> Added by correct-course 2026-10-29. Implement next, before Story 2.3.

As the maintainer of config-v2,
I want the repository to contain only the Arch Linux bootstrap path,
So that every tracked script and validator matches the supported scope and nothing untested ships.

**Acceptance Criteria:**

**Given** the repository,
**When** I list tracked files,
**Then** `setup.ps1`, `packages/scoop.txt`, `packages/winget.txt`, `packages/ubuntu.txt`, and `tests/validate-setup-ps1.ps1` no longer exist
**And** `tests/lib/WslTestInstance.ps1` (the Windows-hosted WSL Arch test harness) is kept

**Given** `setup.sh`,
**When** I run it on a host whose `/etc/os-release` `ID` is not `arch`,
**Then** it exits non-zero during preflight with an actionable "only Arch Linux is supported" error
**And** no package, file, or key mutation happens before that exit (AD-7, AD-9, NFR2)
**And** `setup.sh` contains no apt, dpkg, or Ubuntu repository logic

**Given** `tests/validate-setup.ps1` and `tests/validate-readme.ps1`,
**When** the Ubuntu and Windows assertions are removed,
**Then** they assert the Arch-only guard and the absence of Ubuntu/Windows paths instead
**And** `README.md` no longer has a Windows Companion Bootstrap section or a `packages/ubuntu.txt` reference (the full in-repo dotfiles README rewrite stays in Story 2.5)

**Given** the Windows PowerShell validation commands,
**When** I run `validate-setup.ps1`, `validate-dotfiles.ps1`, `validate-readme.ps1`, and `validate-wsl-test-ca.ps1`,
**Then** all pass
