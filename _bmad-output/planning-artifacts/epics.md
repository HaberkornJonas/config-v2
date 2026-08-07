---
stepsCompleted: [step-01-validate-prerequisites, step-02-design-epics, step-03-create-stories, step-04-final-validation]
inputDocuments:
  - _bmad-output/specs/spec-dev-env-config-repo/SPEC.md
  - _bmad-output/specs/spec-dev-env-config-repo/stack.md
  - _bmad-output/planning-artifacts/architecture/architecture-config-v2-2026-08-05/ARCHITECTURE-SPINE.md
---

# config-v2 - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for config-v2, decomposing the requirements from the SPEC, stack catalog, and Architecture Spine into implementable stories.

## Requirements Inventory

### Functional Requirements

FR1: The system shall require the user to install Git manually, clone `config-v2`, and run `setup.sh` from that local checkout to bootstrap a fresh Linux dev environment.
FR2: `setup.sh` shall detect the Linux distro exactly once via `/etc/os-release` and select the correct package manifest (`packages/arch.txt` for Arch, `packages/ubuntu.txt` for Ubuntu) and the appropriate package manager (`pacman` or `apt`).
FR3: `setup.sh` shall install all packages from the selected distro manifest using the distro's package manager.
FR4: `setup.sh` shall invoke `chezmoi init --apply $DOTFILES_REPO` after package installation, applying all user dotfiles from the separate dotfiles repo.
FR5: `setup.sh` shall define the exhaustive canonical Linux bootstrap key schema with keys: `DOTFILES_REPO`, `GIT_USER_NAME`, `GIT_USER_EMAIL`, `GPG_FINGERPRINT`, `SSH_KEY_FILE`; every Linux bootstrap key `setup.sh` reads must be declared in that inline configuration block.
FR6: The inline bootstrap configuration at the top of `setup.sh` shall be the sole source of Linux bootstrap runtime values; the script may not prompt interactively for those values.
FR7: Before writing to any stateful user asset (SSH keys at path declared in `SSH_KEY_FILE`, GPG keys), `setup.sh` shall test for presence; if present, skip with a human-readable log message and do not overwrite.
FR8: Re-running `setup.sh` on an already-configured machine shall update the environment cleanly, exit without errors, and leave existing SSH keys and GPG keys untouched (idempotent).
FR9: User can apply and sync dotfiles across registered machines via `chezmoi apply`; the operation shall be idempotent across repeated runs (chezmoi-side; config-v2 enables this by ensuring chezmoi is installed and seeded).
FR10: `setup.ps1` shall bootstrap a Windows companion environment by delegating package installs to Scoop and winget, installing the defined Windows tool set without requiring manual steps beyond the initial script invocation.
FR11: Package manifests (`packages/arch.txt`, `packages/ubuntu.txt`) shall list one package name per line in plaintext; no version pins unless a specific version is required.
FR12: The repository source tree shall match the defined structure: `setup.sh`, `setup.ps1`, `packages/arch.txt`, `packages/ubuntu.txt`, with Linux bootstrap configuration stored inside `setup.sh`.

### NonFunctional Requirements

NFR1: **Security / Public repo** — No secrets, credentials, passwords, or private keys may be committed; only safe references (GPG fingerprint, username, public repo URLs) are permitted in tracked files.
NFR2: **Platform coverage** — Bootstrap must support both Arch Linux and Ubuntu (WSL and VM targets) as first-class environments.
NFR3: **Non-interactive** — Once the repo is cloned locally, the Linux bootstrap is fully silent and non-interactive; no prompts during execution.
NFR4: **Non-destructive** — Stateful user assets (SSH keys, GPG keys) are never overwritten on any re-run; detect-before-mutate is mandatory.
NFR5: **Two-repo boundary** — `config-v2` and the dotfiles repo are independently deployable; `config-v2` contains no files managed by chezmoi; no chezmoi-managed file may reside in this repo.
NFR6: **Deterministic managed config** — chezmoi-managed files are always overwritten on `chezmoi apply`; no soft-merge for managed config.
NFR7: **Delegation principle** — `setup.sh` and `setup.ps1` are orchestrators only; they must not implement package install/remove or dotfile state logic — those belong to package managers and chezmoi respectively.
NFR8: **Fixed execution order** — Bootstrap execution order is immutable: (1) load the bootstrap configuration declared at the top of `setup.sh`, (2) install packages, (3) `chezmoi init --apply`.

### Additional Requirements

From Architecture Spine (AD-1 through AD-9):

- **Boundary enforcement (AD-1):** `config-v2` contains only bootstrap scripts, package manifests, and Windows tooling. No file managed by chezmoi may reside here.
- **Distro dispatch isolation (AD-5):** Distro is detected exactly once; all distro-specific commands live inside guarded branches keyed to that result. Shared logic is distro-agnostic.
- **Stateful-asset vs. chezmoi-managed declaration (AD-7):** Every writable file path must be declared in exactly one category — `stateful-asset` (detect-before-mutate, never chezmoi-managed) or `chezmoi-managed` (always overwritten on apply, never touched by `setup.sh`). `SSH_KEY_FILE` is a stateful-asset; `~/.ssh/config` is chezmoi-managed only.
- **Bootstrap config as exhaustive schema (AD-8):** Any new Linux bootstrap key `setup.sh` reads must be added to the inline configuration block in `setup.sh` before use. No key may be invented at runtime inside the script.
- **Stack decision:** `fast-syntax-highlighting` has been superseded by `zsh-users/zsh-syntax-highlighting` as the syntax highlighting plugin. Use `zsh-users/zsh-syntax-highlighting` when authoring the zinit plugin list in the dotfiles repo.
- **Deferred / out of scope for config-v2:** Error handling patterns, CI pipeline beyond Ubuntu, chezmoi template design (dotfiles repo concern), per-distro install ordering/retry logic, YubiKey SSH bridge, Mac support, Windows WSL2 user bootstrap.
- **No starter/greenfield template** — all files are authored from scratch.

### UX Design Requirements

N/A — This is a CLI/shell scripting project with no user interface.

### FR Coverage Map

| FR | Epic | Brief description |
|---|---|---|
| FR1 | Epic 1 | manual Git install + clone + local setup.sh entry point |
| FR2 | Epic 1 | Distro detection once via /etc/os-release → selects manifest + package manager |
| FR3 | Epic 1 | Installs packages from distro manifest via pacman/apt |
| FR4 | Epic 1 | Invokes chezmoi init --apply after package install |
| FR5 | Epic 1 | inline setup.sh bootstrap configuration with 5 canonical keys |
| FR6 | Epic 1 | inline setup.sh bootstrap configuration as sole Linux param source |
| FR7 | Epic 1 | Detect-before-mutate for SSH/GPG stateful assets |
| FR8 | Epic 1 | Idempotent re-run — updates cleanly, SSH keys intact |
| FR9 | Epic 1 | chezmoi apply syncs dotfiles idempotently (config-v2 enables via install + seed) |
| FR10 | Epic 2 | setup.ps1 bootstraps Windows via Scoop + winget |
| FR11 | Epic 1 | Package manifest format: one package per line, plaintext |
| FR12 | Epic 1+2 | Repo source tree — Linux side in Epic 1, setup.ps1 added in Epic 2 |

## Epic List

### Epic 1: Linux Bootstrap
The developer can bootstrap or re-bootstrap a fully configured Linux dev environment from a local checkout — safely, non-interactively, and idempotently.
**FRs covered:** FR1, FR2, FR3, FR4, FR5, FR6, FR7, FR8, FR9, FR11, FR12 (partial)

### Epic 2: Windows Companion Bootstrap
The developer can bootstrap a Windows companion environment by running `setup.ps1`, which installs the defined tool set via Scoop and winget without any manual steps.
**FRs covered:** FR10, FR12 (partial)

---

## Epic 1: Linux Bootstrap

The developer can bootstrap or re-bootstrap a fully configured Linux dev environment from a local checkout — safely, non-interactively, and idempotently.

### Story 1.1: Define setup.sh Bootstrap Configuration

As a developer,
I want `setup.sh` to declare its Linux bootstrap configuration inline at the top of the script,
So that the local Linux bootstrap has a single, reliable source for runtime parameters without an extra config file.

**Acceptance Criteria:**

**Given** `setup.sh`,
**When** I inspect the bootstrap configuration declared at the top of the script,
**Then** all 5 canonical keys are assigned with real values in bash syntax: `DOTFILES_REPO`, `GIT_USER_NAME`, `GIT_USER_EMAIL`, `GPG_FINGERPRINT`, `SSH_KEY_FILE` (AD-3, AD-8)
**And** no actual secrets, passwords, or private keys are present — only safe public references (AD-6, NFR1)

**Given** `setup.sh`,
**When** any script reads a configurable value,
**Then** the Linux bootstrap reads the inline assignments from `setup.sh` — no separate Linux config file, no interactive prompts (FR6, AD-3)

---

### Story 1.2: Create Arch Linux Package Manifest

As a developer setting up an Arch Linux machine,
I want a curated Arch package manifest that covers the full tool catalog,
So that running `setup.sh` on an Arch machine installs the correct, complete tool set.

**Acceptance Criteria:**

**Given** `packages/arch.txt`,
**When** I inspect its format,
**Then** it lists exactly one package name per line, plaintext, no version pins, no blank lines, no comments (FR11)

**Given** the tool catalog in `stack.md`,
**When** I cross-reference `arch.txt`,
**Then** all pacman-installable tools are present: `zsh`, `git`, `chezmoi`, Docker + Docker Compose, `dotnet-sdk`, Neovim, `tmux`, `zoxide`, `starship`, `fzf`
**And** `fnm` is **not** in this manifest — it is not in standard Arch repos and is installed separately by `setup.sh` via the official curl installer (see Story 1.4)
**And** zsh plugin manager tools (`zinit`, `zsh-autosuggestions`, syntax-highlighting plugins, `fzf-tab`) are **not** in this manifest — they are dotfiles-repo concerns managed via `zinit` (AD-1, NFR5)

**Given** `arch.txt` package names,
**When** validated against official Arch repos/AUR,
**Then** all names are valid Arch package identifiers (no Ubuntu-style naming)

---

### Story 1.3: Create Ubuntu Package Manifest

As a developer setting up an Ubuntu machine,
I want a curated Ubuntu package manifest that covers the full tool catalog,
So that running `setup.sh` on an Ubuntu machine installs the correct, complete tool set.

**Acceptance Criteria:**

**Given** `packages/ubuntu.txt`,
**When** I inspect its format,
**Then** it lists exactly one package name per line, plaintext, no version pins (FR11)

**Given** the tool catalog in `stack.md`,
**When** I cross-reference `ubuntu.txt`,
**Then** all apt-installable tools are present using correct Ubuntu package names: `zsh`, `git`, `chezmoi`, `docker-ce`, `docker-compose-plugin`, the .NET SDK package (from Microsoft apt feed, current LTS version at implementation time), `neovim`, `tmux`, `zoxide`, `starship`, `fzf`
**And** `fnm` is **not** in this manifest — it is not available in apt and is installed separately by `setup.sh` via the official curl installer (see Story 1.4)
**And** zsh plugin tools remain excluded (dotfiles-repo concern, AD-1)

**Given** `ubuntu.txt` vs `arch.txt`,
**When** I compare package names for tools that differ across distros (Docker, .NET, Neovim),
**Then** Ubuntu-correct identifiers are used — no Arch-specific names appear in `ubuntu.txt`

**Given** `ubuntu.txt` lists `docker-ce` and the .NET SDK package,
**When** I review how `setup.sh` installs these on Ubuntu,
**Then** `setup.sh` adds the Docker CE official apt repository and GPG key, and the Microsoft apt feed and GPG key, before executing `apt install` — so these packages resolve correctly (FR3, see Story 1.4)

---

### Story 1.4: Implement setup.sh Bootstrap Orchestrator

As a developer on a fresh or existing Linux machine,
I want a single `setup.sh` that orchestrates the full bootstrap in a fixed, safe sequence,
So that my machine is fully configured non-interactively with all stateful assets protected.

**Acceptance Criteria:**

**Given** a local checkout of `config-v2`,
**When** `setup.sh` runs,
**Then** it executes in fixed order: (1) load the bootstrap configuration declared at the top of `setup.sh`, (2) install packages, (3) `chezmoi init --apply $DOTFILES_REPO` — no deviation (AD-9, NFR8)

**Given** `setup.sh` detecting the distro via `/etc/os-release`,
**When** I audit the script,
**Then** detection happens exactly once and all distro-specific commands are inside guarded branches keyed to that result; shared logic is distro-agnostic (AD-5)

**Given** an Arch machine,
**When** the package install step runs,
**Then** `pacman` is invoked with `packages/arch.txt`; given Ubuntu, `apt` is invoked with `packages/ubuntu.txt` — no cross-contamination (FR2, FR3)

**Given** any step in `setup.sh`,
**When** I audit for interactive prompts,
**Then** there are none — all Linux bootstrap values come from the inline configuration block in `setup.sh`; the script is fully silent (FR6, NFR3)

**Given** a machine where `$SSH_KEY_FILE` already exists,
**When** `setup.sh` runs,
**Then** SSH key generation is skipped with a human-readable log message; the existing key is not overwritten (AD-4, FR7)

**Given** a machine where `$GPG_FINGERPRINT` is already registered in the keyring,
**When** `setup.sh` runs,
**Then** GPG setup is skipped with a human-readable log message (AD-4, FR7)

**Given** a previously configured machine,
**When** `setup.sh` is re-run,
**Then** it exits cleanly with no errors, SSH keys and GPG keys are untouched, and `chezmoi apply` updates dotfiles (FR8)

**Given** `setup.sh` audited against the boundary rules,
**When** I review it,
**Then** it contains no package install implementation (delegates to pacman/apt — AD-2, NFR7), no dotfile state logic (delegates to chezmoi — AD-2, NFR7), and `$SSH_KEY_FILE` is treated as a stateful-asset only — `~/.ssh/config` is never written by `setup.sh` (AD-7)

**Given** any unhandled command in `setup.sh` exits with a non-zero status,
**When** the failure occurs,
**Then** `setup.sh` exits immediately with a non-zero exit code and a human-readable message identifying the failed step (equivalent to `set -e` behaviour)

**Given** the distro detected via `/etc/os-release` is neither `arch` nor `ubuntu`,
**When** `setup.sh` reaches the distro dispatch,
**Then** it exits immediately with a clear error message stating the detected distro is not supported

**Given** `setup.sh` is run outside a proper local checkout or repository assets are missing,
**When** the script executes,
**Then** it exits immediately with a clear error message directing the user to install Git manually, clone the repo locally, and run `./setup.sh` from that checkout

**Given** `setup.sh` running on Ubuntu,
**When** it reaches the package installation step,
**Then** it first adds the Docker CE official apt repository (`https://download.docker.com/linux/ubuntu`) with its GPG key, and the Microsoft apt repository with its GPG key — before invoking `apt install`

**Given** any supported distro (Arch or Ubuntu),
**When** `setup.sh` completes the package manager install step,
**Then** it installs `fnm` via the official curl installer (`https://fnm.vercel.app/install`) as a dedicated post-package step, since `fnm` is not available in standard Arch or Ubuntu package repositories (FR3, NFR2)

---

### Story 1.5: Create README with Local Bootstrap Usage Guide

As a developer discovering or returning to this repo,
I want a clear README that tells me exactly how to use the bootstrap,
So that I can install Git, clone the repo, run `setup.sh` locally, and understand the two-repo model.

**Acceptance Criteria:**

**Given** `README.md`,
**When** I read the quick-start section,
**Then** it tells me to install Git manually, clone `config-v2`, `cd` into the checkout, and run `./setup.sh`
**And** it explains that the supported Linux bootstrap path is the local checkout flow

**Given** `README.md`,
**When** I read the Windows section,
**Then** it documents how to run `setup.ps1` on Windows as the companion bootstrap entry point

**Given** `README.md`,
**When** I review it for secrets or real values,
**Then** no credentials, private keys, or sensitive values are present in the documentation examples (NFR1, AD-6)

**Given** `README.md`,
**When** I read the architecture overview,
**Then** it explains the two-repo model: `config-v2` for bootstrap orchestration, the dotfiles repo for user config managed by chezmoi (AD-1)

---
---

## Epic 2: Windows Companion Bootstrap

The developer can bootstrap a Windows companion environment by running `setup.ps1`, which installs the defined tool set via Scoop and winget without any manual steps.

### Story 2.1: Implement setup.ps1 Windows Bootstrap Orchestrator

As a developer on a fresh Windows machine,
I want a `setup.ps1` that installs the defined Windows tool set via Scoop and winget,
So that my Windows environment is bootstrapped without any manual steps beyond running the script.

**Acceptance Criteria:**

**Given** a Windows 11 machine with PowerShell available,
**When** I run `setup.ps1`,
**Then** it installs all defined tools via Scoop and/or winget without prompting (FR10)

**Given** `setup.ps1` audited against AD-2,
**When** I review it,
**Then** it delegates all package installs to Scoop/winget — no install logic is reimplemented in the script itself (NFR7)

**Given** `setup.ps1`,
**When** it reads configurable values (e.g. `DOTFILES_REPO`),
**Then** it declares or loads its bootstrap configuration alongside the entry point using the same canonical key names, with no hardcoded per-machine prompts (AD-3, FR6)

**Given** Scoop is not yet installed on the machine,
**When** `setup.ps1` runs,
**Then** it installs Scoop first before attempting any Scoop-managed package installs

**Given** `setup.ps1` run a second time on an already-configured machine,
**When** it completes,
**Then** it exits without errors (Scoop and winget installs are idempotent)

**Given** `setup.ps1` reviewed for secrets,
**When** I inspect it,
**Then** no credentials, tokens, or private keys are present (AD-6, NFR1)
