---
baseline_commit: f0285b2c3f02ab00e51af81e19102621f1a60397
---

# Story 1.1: Create config.sh Parameter File

Status: done

## Story

As a developer,
I want a tracked `config.sh` committed directly to the repo with my actual values,
so that all scripts have a single, reliable source for runtime parameters without any manual setup step.

## Acceptance Criteria

1. **Given** the repository root, **When** I inspect `config.sh`, **Then** all 5 canonical keys are declared with real values in `KEY=value` bash-sourceable format: `DOTFILES_REPO`, `GIT_USER_NAME`, `GIT_USER_EMAIL`, `GPG_FINGERPRINT`, `SSH_KEY_FILE` — and no actual secrets, passwords, or private keys are present (only safe public references).

2. **Given** `config.sh` committed to the repo, **When** I run `git status`, **Then** `config.sh` is tracked — no `.gitignore` entry suppresses it.

3. **Given** `config.sh`, **When** any script reads a configurable value, **Then** it sources `config.sh` and reads from it — no hardcoded values in scripts, no interactive prompts.

## Tasks / Subtasks

- [x] Task 1: Create `config.sh` at the repository root (AC: 1, 2)
  - [x] Declare all 5 canonical keys in `KEY=value` bash-sourceable format (no spaces around `=`)
  - [x] Use real, safe public values: dotfiles repo URL, git identity, GPG fingerprint, SSH key path
  - [x] Confirm no secrets, passwords, or private keys are present
- [x] Task 2: Verify `config.sh` is tracked by git (AC: 2)
  - [x] Confirm no `.gitignore` rule suppresses `config.sh`
  - [x] Stage and commit `config.sh`
- [x] Task 3: Validate bash-sourceable format (AC: 1, 3)
  - [x] Source the file manually (`source config.sh`) and verify all 5 variables are set correctly
  - [x] Confirm the file produces no output when sourced (no `echo` or interactive commands)

## Dev Notes

### What to Build

Create a single file at the **repo root**: `config.sh`

It must contain exactly these 5 keys — **no more, no less at this stage** (AD-8: any new key a script reads must be added here first):

```bash
DOTFILES_REPO=git@github.com:YourUser/dotfiles.git
GIT_USER_NAME=Your Name
GIT_USER_EMAIL=you@example.com
GPG_FINGERPRINT=ABCDEF1234567890ABCDEF1234567890ABCDEF12
SSH_KEY_FILE=~/.ssh/id_ed25519
```

Replace placeholder values with **your actual values**. All values are safe to commit publicly:
- `DOTFILES_REPO` — public GitHub repo URL (SSH or HTTPS); contains no credentials
- `GIT_USER_NAME` / `GIT_USER_EMAIL` — your identity as it appears in git commits
- `GPG_FINGERPRINT` — the 40-character hex fingerprint of your GPG key (public identifier, not the private key)
- `SSH_KEY_FILE` — the **path** to your SSH key file (e.g. `~/.ssh/id_ed25519`); not the key content itself

### Format Rules (from Architecture Spine — Consistency Conventions)

- `KEY=value` pairs — bash-sourceable, **no spaces around `=`**
- No `export` keyword (scripts source the file; downstream scripts decide their own export scope)
- No blank lines between keys (keep it clean)
- No comments that contain actual secret hints
- File must be silent when sourced — no `echo`, `read`, or interactive constructs

### Security Constraint (AD-6 — No secrets in repository)

`config.sh` is tracked in git (public repo). The rule is absolute:
- ✅ GPG fingerprint — safe (public identifier)
- ✅ Username, email — safe (same as your GitHub profile)
- ✅ Dotfiles repo URL — safe (public repo)
- ✅ SSH key **file path** — safe (not the key content)
- ❌ SSH private key content — NEVER commit
- ❌ Passwords or passphrases — NEVER commit
- ❌ API tokens or secrets — NEVER commit

### Git Tracking (AD-3, FR5)

`config.sh` must be **tracked** in git — this is intentional and by design. Do NOT add it to `.gitignore`. The entire point is that the file travels with the repo so that scripts can reliably source it on any clone.

Verify before committing:
```bash
git status          # config.sh must appear as a tracked new file, not untracked or ignored
git check-ignore -v config.sh   # must produce no output (not ignored)
```

### Downstream Contract (What Future Scripts Depend On)

Stories 1.2–1.5 and 2.1 will `source config.sh` at the start of their scripts. The variables these stories consume are:

| Key | Consumer |
|---|---|
| `DOTFILES_REPO` | `setup.sh` (Story 1.4) — passed to `chezmoi init --apply` |
| `GIT_USER_NAME` | `setup.sh` (Story 1.4) — git config |
| `GIT_USER_EMAIL` | `setup.sh` (Story 1.4) — git config |
| `GPG_FINGERPRINT` | `setup.sh` (Story 1.4) — GPG key presence check |
| `SSH_KEY_FILE` | `setup.sh` (Story 1.4) — SSH key presence check (detect-before-mutate, AD-4, AD-7) |
| `DOTFILES_REPO`, `SSH_KEY_FILE` | `setup.ps1` (Story 2.1) — parsed line-by-line from PowerShell |

**Do not rename or add keys without updating `config.sh` first (AD-8).**

### Project Structure Notes

- **File location:** `config-v2/config.sh` — at the **repo root**, not inside any subdirectory
- **Source tree per architecture:**
  ```
  config-v2/
    config.sh        ← this story creates this file
    setup.sh         ← future (Story 1.4)
    setup.ps1        ← future (Story 2.1)
    packages/
      arch.txt       ← future (Story 1.2)
      ubuntu.txt     ← future (Story 1.3)
  ```
- The `docs/`, `_bmad/`, `_bmad-output/`, and `.agents/` directories are tooling — do not place `config.sh` there.
- No `packages/` directory exists yet; do not create it in this story.

### References

- [ARCHITECTURE-SPINE.md — AD-3](/c:/Users/Jonas.HABERKORN/source/repos/config-v2/_bmad-output/planning-artifacts/architecture/architecture-config-v2-2026-08-05/ARCHITECTURE-SPINE.md) — `config.sh` as sole parameter source
- [ARCHITECTURE-SPINE.md — AD-6](/c:/Users/Jonas.HABERKORN/source/repos/config-v2/_bmad-output/planning-artifacts/architecture/architecture-config-v2-2026-08-05/ARCHITECTURE-SPINE.md) — No secrets in repository
- [ARCHITECTURE-SPINE.md — AD-8](/c:/Users/Jonas.HABERKORN/source/repos/config-v2/_bmad-output/planning-artifacts/architecture/architecture-config-v2-2026-08-05/ARCHITECTURE-SPINE.md) — Exhaustive canonical key schema
- [ARCHITECTURE-SPINE.md — Consistency Conventions](/c:/Users/Jonas.HABERKORN/source/repos/config-v2/_bmad-output/planning-artifacts/architecture/architecture-config-v2-2026-08-05/ARCHITECTURE-SPINE.md) — `KEY=value`, bash-sourceable format
- [epics.md — Story 1.1](/c:/Users/Jonas.HABERKORN/source/repos/config-v2/_bmad-output/planning-artifacts/epics.md) — Acceptance criteria source
- FR5, FR6 — Canonical key schema; `config.sh` as sole non-interactive param source

## Dev Agent Record

### Agent Model Used

claude-sonnet-4.6

### Debug Log References

- `GIT_USER_NAME=Jonas Haberkorn` required quoting (`"Jonas Haberkorn"`) because the space caused bash to treat `Haberkorn` as a command. Fixed before commit.

### Completion Notes List

- Created `config.sh` at repo root with all 5 canonical keys per AD-3, AD-8.
- Values sourced from developer's system: git config (name/email), gpg keyring (fingerprint), ~/.ssh/ directory (key file path).
- `DOTFILES_REPO` set to `git@github.com:JonasHaberkorn/dotfiles.git` — **verify this URL is correct** before using `setup.sh`.
- `SSH_KEY_FILE` set to `~/.ssh/id_rsa` based on the key found in `~/.ssh/`.
- `GIT_USER_NAME` value contains a space and is quoted (`"Jonas Haberkorn"`) per bash syntax; this is valid and bash-sourceable.
- Validated: file is silent when sourced (no output), all 5 variables resolve correctly, no gitignore rule suppresses the file.
- Committed as: `5771680 feat: add config.sh parameter file (Story 1.1)`

### File List

- `config.sh` (created)

## Change Log

- 2026-08-05: Created `config.sh` with 5 canonical keys (DOTFILES_REPO, GIT_USER_NAME, GIT_USER_EMAIL, GPG_FINGERPRINT, SSH_KEY_FILE) at repo root. Committed and verified tracked by git. Validated bash-sourceable and silent when sourced.
