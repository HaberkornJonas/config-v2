---
baseline_commit: 3ce7987
---

# Story 1.3: Create Ubuntu Package Manifest

Status: done

## Story

As a developer setting up an Ubuntu machine,
I want a curated Ubuntu package manifest that covers the full tool catalog,
so that running `setup.sh` on an Ubuntu machine installs the correct, complete tool set.

## Acceptance Criteria

1. **Given** `packages/ubuntu.txt`, **When** I inspect its format, **Then** it lists exactly one package name per line, plaintext, no version pins (FR11)

2. **Given** the tool catalog in `stack.md`, **When** I cross-reference `ubuntu.txt`, **Then** all apt-installable tools are present using correct Ubuntu package names: `zsh`, `git`, `chezmoi`, `docker-ce`, `docker-compose-plugin`, the .NET SDK package (from Microsoft apt feed, current LTS version at implementation time), `neovim`, `tmux`, `zoxide`, `starship`, `fzf` — **and** `fnm` is **not** in this manifest (not available in apt; installed via curl in Story 1.4) — **and** zsh plugin tools remain excluded (dotfiles-repo concern, AD-1)

3. **Given** `ubuntu.txt` vs `arch.txt`, **When** I compare package names for tools that differ across distros (Docker, .NET, Neovim), **Then** Ubuntu-correct identifiers are used — no Arch-specific names appear in `ubuntu.txt`

4. **Given** `ubuntu.txt` lists `docker-ce` and the .NET SDK package, **When** I review how `setup.sh` installs these on Ubuntu, **Then** `setup.sh` adds the Docker CE official apt repository and GPG key, and the Microsoft apt feed and GPG key, before executing `apt install` — so these packages resolve correctly (FR3, see Story 1.4) *(note: this AC is informational for this story — setup.sh is Story 1.4's concern)*

## Tasks / Subtasks

- [x] Task 1: Create `packages/ubuntu.txt` (AC: 1, 2, 3)
  - [x] Create `packages/ubuntu.txt` in the existing `packages/` directory
  - [x] Populate with the correct Ubuntu/apt package names for all apt-installable tools
  - [x] Verify format: one package per line, no version pins, no blank lines, no comments
- [x] Task 2: Validate manifest completeness and Ubuntu correctness (AC: 2, 3)
  - [x] Confirm all required packages are present: `zsh`, `git`, `chezmoi`, `docker-ce`, `docker-compose-plugin`, dotnet SDK package, `neovim`, `tmux`, `zoxide`, `starship`, `fzf`
  - [x] Confirm `fnm` is NOT in the manifest
  - [x] Confirm no zsh plugin tools are present (`zinit`, `zsh-autosuggestions`, `fzf-tab`, `zsh-syntax-highlighting`, `fast-syntax-highlighting`)
  - [x] Confirm no Arch-specific package names appear (e.g. no `dotnet-sdk`, no `docker-compose`)
- [x] Task 3: Commit `packages/ubuntu.txt` (AC: 1)
  - [x] Stage and commit `packages/ubuntu.txt`

## Dev Notes

### What to Build

Create a single file at `packages/ubuntu.txt`. The `packages/` directory already exists (created in Story 1.2).

**Exact file content** (one package per line, no blank lines, no comments):

Ubuntu-specific package names:

| Tool | Ubuntu/apt package name | Notes |
|---|---|---|
| zsh | `zsh` | standard apt package |
| git | `git` | standard apt package |
| chezmoi | `chezmoi` | available in Ubuntu 23.04+ / snap; for older Ubuntu use the official binary install — however, as a package list item for apt, use `chezmoi` (available in universe repo on 22.04+) |
| Docker | `docker-ce` | from Docker CE official apt repo (not distro's `docker.io`) |
| Docker Compose | `docker-compose-plugin` | Docker v2 plugin, comes via Docker CE apt repo |
| .NET SDK | `dotnet-sdk-8.0` | from Microsoft apt feed (current LTS is .NET 8 at time of implementation) |
| Neovim | `neovim` | standard apt package |
| tmux | `tmux` | standard apt package |
| zoxide | `zoxide` | standard apt package (available in Ubuntu 22.04+) |
| starship | `starship` | available via Homebrew/snap/cargo — for apt-based install, use the official apt repo or note as a manual step; however the epic spec says `apt install` with the manifest, so use `starship` |
| fzf | `fzf` | standard apt package |

**Note on `starship`:** starship is not in the default Ubuntu apt repositories. However, it can be installed via `cargo` or the official installer script. For this manifest, since Story 1.4 handles the apt install, and the AC says "apt-installable tools", we should include packages that are available via apt after adding relevant repos, or that the story explicitly calls for. The epics spec explicitly lists `starship` in the Ubuntu manifest — include it. Story 1.4 will handle the mechanics (possibly via a dedicated install step similar to fnm).

**Re-checking epics.md AC 2 for 1.3:**
> all apt-installable tools are present using correct Ubuntu package names: `zsh`, `git`, `chezmoi`, `docker-ce`, `docker-compose-plugin`, the .NET SDK package (from Microsoft apt feed, current LTS version at implementation time), `neovim`, `tmux`, `zoxide`, `starship`, `fzf`

The .NET SDK current LTS is .NET 8 → package name: `dotnet-sdk-8.0`

**File content (alphabetical for readability):**
```
chezmoi
docker-ce
docker-compose-plugin
dotnet-sdk-8.0
fzf
git
neovim
starship
tmux
zoxide
zsh
```

### Explicit Exclusions

| Tool | Why excluded |
|---|---|
| `fnm` | Not available in apt; Story 1.4 installs via curl |
| `zinit` | Dotfiles-repo concern (AD-1, NFR5) |
| `zsh-autosuggestions` | Dotfiles-repo concern (AD-1, NFR5) |
| `zsh-syntax-highlighting` / `fast-syntax-highlighting` | Dotfiles-repo concern (AD-1, NFR5) |
| `fzf-tab` | Dotfiles-repo concern (AD-1, NFR5) |
| `docker.io` | Ubuntu's older Docker package — use `docker-ce` from official repo |
| `docker-compose` | v1 standalone (deprecated) — use `docker-compose-plugin` for v2 |
| `dotnet-sdk` | Arch-specific meta-package name — Ubuntu requires versioned name |

### Format Rules (FR11)

- One package name per line — no trailing whitespace or carriage returns
- Plaintext only — no version pins beyond what the package name itself encodes (e.g., `dotnet-sdk-8.0` is the package name, not a version pin)
- No blank lines
- No `#` comment lines
- No shell syntax

### Project Structure Notes

- **File location:** `packages/ubuntu.txt`
- `packages/` already exists from Story 1.2
- Source tree after this story:
  ```
  config-v2/
    config.sh          ← Story 1.1 (done)
    packages/
      arch.txt         ← Story 1.2 (done)
      ubuntu.txt       ← this story
  ```

### Previous Story Context

- Story 1.2 created `packages/arch.txt` with 11 Arch packages committed at `3ce7987`
- The `packages/` directory is at the repo root
- Commit pattern: `feat: add packages/ubuntu.txt Ubuntu package manifest (Story 1.3)`

### References

- [epics.md — Story 1.3](_bmad-output/planning-artifacts/epics.md)
- [stack.md](_bmad-output/specs/spec-dev-env-config-repo/stack.md)
- FR11 — manifest format
- AD-1 — two-repo boundary

## Dev Agent Record

### Agent Model Used

claude-sonnet-4.6

### Debug Log References

(none)

### Completion Notes List

- Created `packages/ubuntu.txt` in the existing `packages/` directory.
- 11 packages using correct Ubuntu/apt names: chezmoi, docker-ce, docker-compose-plugin, dotnet-sdk-8.0, fzf, git, neovim, starship, tmux, zoxide, zsh (alphabetical order).
- Validated: 11 lines, 0 blank lines, 0 comments, 0 version pins, all required packages present, all forbidden packages absent.
- Ubuntu-specific names used: `docker-ce` (not `docker`), `docker-compose-plugin` (not `docker-compose`), `dotnet-sdk-8.0` (not `dotnet-sdk`).
- Committed as: `f465294 feat: add packages/ubuntu.txt Ubuntu package manifest (Story 1.3)`.

### File List

- `packages/ubuntu.txt` (created)

### Change Log

- 2026-08-06: Created `packages/ubuntu.txt` with 11 Ubuntu apt package names (Story 1.3)
