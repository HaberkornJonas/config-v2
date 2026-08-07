---
baseline_commit: c7eb1a909e6a50cd928ef69846d0a8079770ee91
---

# Story 1.2: Create Arch Linux Package Manifest

Status: done

## Story

As a developer setting up an Arch Linux machine,
I want a curated Arch package manifest that covers the full tool catalog,
so that running `setup.sh` on an Arch machine installs the correct, complete tool set.

## Acceptance Criteria

1. **Given** `packages/arch.txt`, **When** I inspect its format, **Then** it lists exactly one package name per line, plaintext, no version pins, no blank lines, no comments (FR11)

2. **Given** the tool catalog in `stack.md`, **When** I cross-reference `arch.txt`, **Then** all pacman-installable tools are present: `zsh`, `git`, `chezmoi`, `docker`, `docker-compose`, `dotnet-sdk`, `neovim`, `tmux`, `zoxide`, `starship`, `fzf` — **and** `fnm` is **not** in this manifest (not in standard Arch repos; installed via curl in Story 1.4) — **and** zsh plugin tools (`zinit`, `zsh-autosuggestions`, syntax-highlighting plugins, `fzf-tab`) are **not** in this manifest (dotfiles-repo concerns, AD-1, NFR5)

3. **Given** `arch.txt` package names, **When** validated against official Arch repos, **Then** all names are valid Arch package identifiers (no Ubuntu-style naming)

## Tasks / Subtasks

- [x] Task 1: Create `packages/` directory and `packages/arch.txt` (AC: 1, 2, 3)
  - [x] Create the `packages/` directory at the repo root (does not yet exist)
  - [x] Create `packages/arch.txt` with the exact 11 pacman-installable tools in canonical Arch package names
  - [x] Verify format: one package per line, no version pins, no blank lines, no comments
- [x] Task 2: Validate manifest completeness and Arch correctness (AC: 2, 3)
  - [x] Confirm all 11 required packages are present: `zsh`, `git`, `chezmoi`, `docker`, `docker-compose`, `dotnet-sdk`, `neovim`, `tmux`, `zoxide`, `starship`, `fzf`
  - [x] Confirm `fnm` is NOT in the manifest
  - [x] Confirm no zsh plugin tools are present (`zinit`, `zsh-autosuggestions`, `fzf-tab`, `zsh-syntax-highlighting`, `fast-syntax-highlighting`)
  - [x] Confirm no Ubuntu-style package names appear (e.g. no `docker-ce`, `docker-compose-plugin`, `dotnet-sdk-8.0`)
- [x] Task 3: Commit `packages/arch.txt` (AC: 1)
  - [x] Stage and commit both the new `packages/` directory and `packages/arch.txt`

## Dev Notes

### What to Build

Create a single file at `packages/arch.txt`. The `packages/` directory must be created first — it does not exist yet.

**Exact file content** (11 lines, no blank lines, no comments):

```
chezmoi
docker
docker-compose
dotnet-sdk
fzf
git
neovim
starship
tmux
zoxide
zsh
```

Alphabetical ordering is used here for readability; no specific ordering is required by the AC.

### Arch Package Name Reference

All 11 packages are in the official Arch `extra` repository (no AUR required):

| Tool | Arch package name | Notes |
|---|---|---|
| zsh | `zsh` | |
| git | `git` | |
| chezmoi | `chezmoi` | |
| Docker | `docker` | |
| Docker Compose | `docker-compose` | provides the v2 CLI plugin (`docker compose`) |
| .NET SDK | `dotnet-sdk` | meta-package; pulls latest stable .NET SDK from `extra` |
| Neovim | `neovim` | |
| tmux | `tmux` | |
| zoxide | `zoxide` | |
| starship | `starship` | in `extra` repo (not AUR) |
| fzf | `fzf` | |

### Explicit Exclusions — Do NOT Add These

| Tool | Why excluded |
|---|---|
| `fnm` | Not in standard Arch repos; Story 1.4 installs it via `curl https://fnm.vercel.app/install` |
| `zinit` | Dotfiles-repo concern — managed via zsh plugin manager, not pacman (AD-1, NFR5) |
| `zsh-autosuggestions` | Dotfiles-repo concern (AD-1, NFR5) |
| `zsh-syntax-highlighting` / `fast-syntax-highlighting` | Dotfiles-repo concern (AD-1, NFR5) |
| `fzf-tab` | Dotfiles-repo concern (AD-1, NFR5) |
| `docker-ce` | Ubuntu-specific name (from Docker CE apt repo) — invalid on Arch |
| `docker-compose-plugin` | Ubuntu-specific name — on Arch, `docker-compose` is the correct package |
| `dotnet-sdk-8.0` | Version-pinned name — AC requires no version pins |

### Format Rules (FR11)

- One package name per line — no trailing whitespace or carriage returns
- Plaintext only — no version pins (e.g., not `neovim>=0.9`)
- No blank lines
- No `#` comment lines
- No shell syntax (`pacman -S`, `--noconfirm`, etc.)

Story 1.4 will consume this file directly as a package list, e.g.:
```bash
pacman -S --noconfirm - < packages/arch.txt
```
The file must be a clean list of package names with no preprocessing required.

### Project Structure Notes

- **File location:** `packages/arch.txt` — repo root subdirectory `packages/`
- `packages/` does not exist yet; this story creates it
- `packages/ubuntu.txt` is created in Story 1.3 — do not create it here
- Source tree after this story:
  ```
  config-v2/
    config.sh          ← Story 1.1 (done)
    packages/
      arch.txt         ← this story
  ```

### Previous Story Context (Story 1.1)

- Story 1.1 created `config.sh` at repo root; committed at `5771680`
- No `config.sh` values are needed in this story — `arch.txt` is a standalone text file
- Commit pattern established: `feat: add packages/arch.txt Arch Linux package manifest (Story 1.2)`

### Downstream Contract

Story 1.4 (`setup.sh`) reads `packages/arch.txt` in the Arch branch and passes each line to pacman. The file path `packages/arch.txt` is fixed — do not rename or relocate it. Story 1.4 depends on this exact path.

### References

- [epics.md — Story 1.2](_bmad-output/planning-artifacts/epics.md) — acceptance criteria source
- [ARCHITECTURE-SPINE.md — AD-1, AD-5, Source tree](_bmad-output/planning-artifacts/architecture/architecture-config-v2-2026-08-05/ARCHITECTURE-SPINE.md) — two-repo boundary, distro dispatch, repo structure
- [stack.md](_bmad-output/specs/spec-dev-env-config-repo/stack.md) — canonical tool catalog
- FR11 — manifest format: one package per line, plaintext, no version pins

## Dev Agent Record

### Agent Model Used

claude-sonnet-4.6

### Debug Log References

(none)

### Completion Notes List

- Created `packages/` directory at repo root (did not exist).
- Created `packages/arch.txt` with 11 packages: chezmoi, docker, docker-compose, dotnet-sdk, fzf, git, neovim, starship, tmux, zoxide, zsh (alphabetical order).
- Validated: 11 lines, 0 blank lines, 0 comments, 0 version pins, all required packages present, all forbidden packages absent.
- Committed as: `3ce7987 feat: add packages/arch.txt Arch Linux package manifest (Story 1.2)`.
- Re-validated the manifest against the story acceptance criteria and exact package list before moving the story to review.

### File List

- `packages/arch.txt` (created)

### Change Log

- 2026-08-06: Validated `packages/arch.txt` against Story 1.2 acceptance criteria and moved story status to `review`
