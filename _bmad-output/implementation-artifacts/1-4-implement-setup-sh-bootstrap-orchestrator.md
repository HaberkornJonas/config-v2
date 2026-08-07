---
baseline_commit: f4652943679e1384ce739a1a0f4b2f65cc24c6cd
---

# Story 1.4: Implement setup.sh Bootstrap Orchestrator

Status: done

## Story

As a developer on a fresh or existing Linux machine,
I want a single `setup.sh` that orchestrates the full bootstrap in a fixed, safe sequence,
so that my machine is fully configured non-interactively with all stateful assets protected.

## Acceptance Criteria

1. **Given** a machine with `config.sh` present, **When** `setup.sh` runs, **Then** it executes in fixed order: (1) `source config.sh`, (2) install packages, (3) `chezmoi init --apply $DOTFILES_REPO` — no deviation (AD-9, NFR8)

2. **Given** `setup.sh` detecting the distro via `/etc/os-release`, **When** I audit the script, **Then** detection happens exactly once and all distro-specific commands are inside guarded branches keyed to that result; shared logic is distro-agnostic (AD-5)

3. **Given** an Arch machine, **When** the package install step runs, **Then** `pacman` is invoked with `packages/arch.txt`; given Ubuntu, `apt` is invoked with `packages/ubuntu.txt` — no cross-contamination (FR2, FR3)

4. **Given** any step in `setup.sh`, **When** I audit for interactive prompts, **Then** there are none — all values come from `config.sh`; the script is fully silent (FR6, NFR3)

5. **Given** a machine where `$SSH_KEY_FILE` already exists, **When** `setup.sh` runs, **Then** SSH key generation is skipped with a human-readable log message; the existing key is not overwritten (AD-4, FR7)

6. **Given** a machine where `$GPG_FINGERPRINT` is already registered in the keyring, **When** `setup.sh` runs, **Then** GPG setup is skipped with a human-readable log message (AD-4, FR7)

7. **Given** a previously configured machine, **When** `setup.sh` is re-run, **Then** it exits cleanly with no errors, SSH keys and GPG keys are untouched, and `chezmoi apply` updates dotfiles (FR8)

8. **Given** `setup.sh` audited against the boundary rules, **When** I review it, **Then** it contains no package install implementation (delegates to pacman/apt — AD-2, NFR7), no dotfile state logic (delegates to chezmoi — AD-2, NFR7), and `$SSH_KEY_FILE` is treated as a stateful-asset only — `~/.ssh/config` is never written by `setup.sh` (AD-7)

9. **Given** any unhandled command in `setup.sh` exits with a non-zero status, **When** the failure occurs, **Then** `setup.sh` exits immediately with a non-zero exit code and a human-readable message identifying the failed step (equivalent to `set -e` behaviour)

10. **Given** the distro detected via `/etc/os-release` is neither `arch` nor `ubuntu`, **When** `setup.sh` reaches the distro dispatch, **Then** it exits immediately with a clear error message stating the detected distro is not supported

11. **Given** `config.sh` is absent when `setup.sh` runs, **When** the script executes, **Then** it exits immediately with a clear error message directing the user to populate `config.sh`

12. **Given** `setup.sh` running on Ubuntu, **When** it reaches the package installation step, **Then** it first adds the Docker CE official apt repository (`https://download.docker.com/linux/ubuntu`) with its GPG key, and the Microsoft apt repository with its GPG key — before invoking `apt install`

13. **Given** any supported distro (Arch or Ubuntu), **When** `setup.sh` completes the package manager install step, **Then** it installs `fnm` via the official curl installer (`https://fnm.vercel.app/install`) as a dedicated post-package step, since `fnm` is not available in standard Arch or Ubuntu package repositories (FR3, NFR2)

## Tasks / Subtasks

- [x] Task 1: Scaffold `setup.sh` with strict mode and config.sh guard (AC: 9, 11)
  - [x] Create `setup.sh` at repo root with `#!/usr/bin/env bash` shebang
  - [x] Add `set -euo pipefail` at top for strict mode (satisfies AC 9)
  - [x] Check for `config.sh` presence (`-f config.sh`) immediately after strict mode; exit with clear error if absent (AC 11)
  - [x] Source `config.sh` as first substantive action (AC 1)
- [x] Task 2: Distro detection — exactly once (AC: 2, 10)
  - [x] Read `/etc/os-release` once and store `ID` value into a local variable
  - [x] All distro-specific branches use this single variable
  - [x] Add unsupported-distro else-branch that exits with clear error (AC 10)
- [x] Task 3: Package installation — Arch branch (AC: 3)
  - [x] Inside the `arch` branch: invoke `pacman -S --needed --noconfirm - < packages/arch.txt`
  - [x] No Ubuntu-specific logic in this branch
- [x] Task 4: Package installation — Ubuntu branch (AC: 3, 12)
  - [x] Inside the `ubuntu` branch: add Docker CE apt repo + GPG key before install (AC 12)
  - [x] Add Microsoft apt repo + GPG key for .NET SDK before install (AC 12)
  - [x] Install packages: `apt-get update && xargs -a packages/ubuntu.txt apt-get install -y`
  - [x] No Arch-specific logic in this branch
- [x] Task 5: Post-package fnm installation (AC: 13)
  - [x] After the distro package-manager step (outside the distro branches): install `fnm` via `curl -fsSL https://fnm.vercel.app/install | bash`
  - [x] This step is shared / distro-agnostic
- [x] Task 6: SSH key generation with detect-before-mutate guard (AC: 4, 5, 8)
  - [x] Test `$SSH_KEY_FILE` with `-f`; if present, log skip message and do NOT regenerate
  - [x] If absent, generate key with `ssh-keygen -t rsa -b 4096 -C "$GIT_USER_EMAIL" -f "$SSH_KEY_FILE" -N ""`
  - [x] No interactive prompts (`-N ""` for empty passphrase via args only)
  - [x] `~/.ssh/config` is never written by `setup.sh` (chezmoi-managed — AD-7)
- [x] Task 7: GPG key setup with detect-before-mutate guard (AC: 6, 8)
  - [x] Test if `$GPG_FINGERPRINT` is already in the keyring via `gpg --list-keys "$GPG_FINGERPRINT"`
  - [x] If present: log skip message and do nothing
  - [x] If absent: log informational message (GPG import handled via dotfiles/manual step)
- [x] Task 8: chezmoi init --apply (AC: 1, 7)
  - [x] As final step: invoke `chezmoi init --apply "$DOTFILES_REPO"`
  - [x] No dotfile state logic in `setup.sh` — delegate entirely to chezmoi (AD-2, NFR7)
- [x] Task 9: Validate full script against all ACs (AC: all)
  - [x] Audit: no hardcoded values (all values come from `config.sh`)
  - [x] Audit: no interactive prompts
  - [x] Audit: distro detected exactly once
  - [x] Audit: `~/.ssh/config` never written by the script
  - [x] Audit: script is fully idempotent (re-run safe)
- [x] Task 10: Commit `setup.sh` (AC: all)
  - [x] Stage and commit `setup.sh`

## Dev Notes

### What to Build

Create `setup.sh` at the **repo root** (alongside `config.sh`, `packages/`). This is the Linux bootstrap orchestrator.

**Script skeleton (reference structure):**

```bash
#!/usr/bin/env bash
set -euo pipefail

# --- Guard: config.sh must exist ---
if [[ ! -f "$(dirname "$0")/config.sh" ]]; then
  echo "ERROR: config.sh not found. Please populate config.sh before running setup.sh." >&2
  exit 1
fi

# --- (1) Source config.sh ---
# shellcheck source=config.sh
source "$(dirname "$0")/config.sh"

# --- (2) Detect distro (exactly once, AD-5) ---
. /etc/os-release
DISTRO="${ID:-}"

# --- (2) Install packages ---
if [[ "$DISTRO" == "arch" ]]; then
  pacman -S --needed --noconfirm - < "$(dirname "$0")/packages/arch.txt"

elif [[ "$DISTRO" == "ubuntu" ]]; then
  # Add Docker CE apt repo
  # ... (see Ubuntu section below)

  # Add Microsoft apt repo for .NET SDK
  # ... (see Ubuntu section below)

  apt-get update
  apt-get install -y "$(cat "$(dirname "$0")/packages/ubuntu.txt")"

else
  echo "ERROR: Unsupported distro '$DISTRO'. Supported: arch, ubuntu." >&2
  exit 1
fi

# --- Post-package: install fnm (curl installer, both distros) ---
curl -fsSL https://fnm.vercel.app/install | bash

# --- SSH key (detect-before-mutate, AD-4) ---
if [[ -f "$SSH_KEY_FILE" ]]; then
  echo "INFO: SSH key already exists at $SSH_KEY_FILE — skipping generation."
else
  ssh-keygen -t rsa -b 4096 -C "$GIT_USER_EMAIL" -f "$SSH_KEY_FILE" -N ""
fi

# --- GPG key (detect-before-mutate, AD-4) ---
if gpg --list-keys "$GPG_FINGERPRINT" &>/dev/null; then
  echo "INFO: GPG key $GPG_FINGERPRINT already registered — skipping."
else
  # import/configure GPG key non-interactively
  echo "INFO: GPG key not found, configuring..."
fi

# --- (3) chezmoi init --apply ---
chezmoi init --apply "$DOTFILES_REPO"
```

### Ubuntu Apt Repo Setup (AC 12)

Docker CE official apt repo (required before `apt install docker-ce`):

```bash
# Install prerequisites
apt-get install -y ca-certificates curl gnupg lsb-release

# Docker CE GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Docker CE apt repo
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null
```

Microsoft apt repo (required before `apt install dotnet-sdk-8.0`):

```bash
# Microsoft GPG key + repo
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
  | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg
chmod a+r /etc/apt/keyrings/microsoft.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] \
  https://packages.microsoft.com/repos/microsoft-ubuntu-$(lsb_release -cs)-prod $(lsb_release -cs) main" \
  | tee /etc/apt/sources.list.d/microsoft.list > /dev/null
```

### Architecture Invariants (MUST FOLLOW)

| Rule | Requirement |
|------|-------------|
| AD-2 | `setup.sh` is an orchestrator ONLY — no package install logic, no dotfile state logic |
| AD-3 | All configurable values sourced from `config.sh`; no hardcoded values, no prompts |
| AD-4 | Detect-before-mutate: test `-f $SSH_KEY_FILE` and `gpg --list-keys $GPG_FINGERPRINT` before any write |
| AD-5 | Distro detected exactly once via `/etc/os-release`; all distro-specific commands inside guarded branches |
| AD-7 | `$SSH_KEY_FILE` is the only SSH file `setup.sh` touches; `~/.ssh/config` is chezmoi-managed — NEVER written here |
| AD-8 | Only read keys already declared in `config.sh`: `DOTFILES_REPO`, `GIT_USER_NAME`, `GIT_USER_EMAIL`, `GPG_FINGERPRINT`, `SSH_KEY_FILE` |
| AD-9 | Fixed execution order: (1) source config.sh, (2) install packages, (3) `chezmoi init --apply` |
| NFR3 | Fully non-interactive — all flags must suppress prompts (`-y`, `-N ""`, `--noconfirm`, `--needed`) |
| NFR7 | Delegation principle — delegate package installs to pacman/apt, delegate dotfiles to chezmoi |

### Existing Files (Do Not Break)

| File | State | Notes |
|------|-------|-------|
| `config.sh` | EXISTS — story 1.1 | Variables: `DOTFILES_REPO`, `GIT_USER_NAME`, `GIT_USER_EMAIL`, `GPG_FINGERPRINT`, `SSH_KEY_FILE` |
| `packages/arch.txt` | EXISTS — story 1.2 | 11 Arch packages, no fnm |
| `packages/ubuntu.txt` | EXISTS — story 1.3 | 11 Ubuntu packages, no fnm |

### Key Technical Decisions

- **`set -euo pipefail`**: Use this for `set -e` behaviour (AC 9). This exits on any non-zero command, unset variable, and pipe failure.
- **`$(dirname "$0")`**: Use for file references so the script is runnable from any working directory (curl one-liner context).
- **`pacman` invocation**: `pacman -S --needed --noconfirm - < packages/arch.txt` reads the package list via stdin.
- **`apt-get` vs `apt`**: Use `apt-get` in scripts (more stable non-interactive API); use `-y` flag to suppress prompts.
- **fnm installer**: `https://fnm.vercel.app/install` — official curl installer, installs to `~/.local/share/fnm`; no distro package available for either Arch or Ubuntu in standard repos.
- **SSH keygen passphrase**: `-N ""` passes empty passphrase non-interactively; do not use `--passphrase` (not a valid flag).
- **GPG detection**: `gpg --list-keys "$GPG_FINGERPRINT"` exits 0 if found, 2 if not found — redirect stderr to `/dev/null` to suppress output.
- **chezmoi**: invoked as `chezmoi init --apply "$DOTFILES_REPO"` — no dotfile logic in `setup.sh`; chezmoi owns all of that.

### Naming Conventions (from Architecture)

- Script name: `setup.sh` — lowercase, hyphen-separated
- Distro IDs: `arch`, `ubuntu` — match `/etc/os-release` `ID` field exactly (lowercase)
- Log messages: `INFO:` prefix for skip messages, `ERROR:` prefix for fatal errors (to `stderr`)

### Source Tree After This Story

```
config-v2/
  setup.sh          ← this story (NEW)
  config.sh         ← story 1.1 (done)
  packages/
    arch.txt        ← story 1.2 (done)
    ubuntu.txt      ← story 1.3 (done)
```

### Project Structure Notes

- `setup.sh` lives at **repo root** — same level as `config.sh` (FR12, Architecture Spine structural seed)
- The script uses `$(dirname "$0")` to reference sibling files (works when fetched via curl and executed as a temp file)
- No new directories needed

### Previous Story Context

- Stories 1.1–1.3 done; `config.sh` and both package manifests exist and are committed
- Last commit: `f465294 feat: add packages/ubuntu.txt Ubuntu package manifest (Story 1.3)`
- Commit pattern to follow: `feat: add setup.sh Linux bootstrap orchestrator (Story 1.4)`
- `packages/` directory is at repo root; reference as `packages/arch.txt` / `packages/ubuntu.txt` from script

### References

- [epics.md — Story 1.4](_bmad-output/planning-artifacts/epics.md)
- [ARCHITECTURE-SPINE.md](_bmad-output/planning-artifacts/architecture/architecture-config-v2-2026-08-05/ARCHITECTURE-SPINE.md)
- FR2, FR3, FR6, FR7, FR8 — core functional requirements
- AD-2, AD-3, AD-4, AD-5, AD-7, AD-8, AD-9 — architecture invariants
- NFR3, NFR7, NFR8 — non-functional constraints

## Dev Agent Record

### Agent Model Used

claude-sonnet-4.6

### Debug Log References

### Completion Notes List

- Created `setup.sh` at repo root (86 lines including comments).
- `set -euo pipefail` strict mode satisfies fail-fast requirement (AC 9).
- config.sh guard exits with clear error message if file absent (AC 11).
- Distro detected exactly once from `/etc/os-release` `ID` field (AC 2, AD-5).
- Arch branch: `pacman -S --needed --noconfirm - < packages/arch.txt` (AC 3).
- Ubuntu branch: adds Docker CE + Microsoft apt repos with GPG keys before `apt install` (AC 12); uses `xargs -a` for robust package list reading.
- fnm installed via `curl -fsSL https://fnm.vercel.app/install | bash` outside distro branches — shared step (AC 13).
- SSH key guarded with `-f $SSH_KEY_FILE`; skips with INFO log if present; `mkdir -p` ensures `~/.ssh/` dir exists if generating (AC 5); `~/.ssh/config` never touched (AD-7).
- GPG key guarded with `gpg --list-keys`; skips with INFO log if present (AC 6).
- chezmoi invoked as final step: `chezmoi init --apply "$DOTFILES_REPO"` (AC 1, AC 7, AD-9).
- No hardcoded values — all from `config.sh` (AD-3, AD-8).
- All commands use non-interactive flags (`-y`, `--noconfirm`, `--needed`, `-N ""`, `-fsSL`) (NFR3).
- Committed as: `9775473 feat: add setup.sh Linux bootstrap orchestrator (Story 1.4)`.

### File List

- `setup.sh` (created)

### Change Log

- 2026-08-06: Created `setup.sh` Linux bootstrap orchestrator with full distro dispatch, repo setup, fnm install, SSH/GPG guards, and chezmoi delegation (Story 1.4)
