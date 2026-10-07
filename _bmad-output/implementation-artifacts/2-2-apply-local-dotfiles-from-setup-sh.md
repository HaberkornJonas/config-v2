---
baseline_commit: 01fbd7a
---

# Story 2.2: Apply Local Dotfiles from setup.sh

Status: done

> **AC refinement (approved by Jonas, 2026-10-07):** `epics.md` Story 2.2 has two AC groups (local apply; repo-root paths, `DOTFILES_REPO` removal). The implementation readiness report 2026-10-07 assigns three more items to this story: Major #3 (persisted `sourceDir` so plain `chezmoi apply` uses the checkout), Major #4 (privilege model: run as the target user, `sudo` only for system commands, refuse root), and Minor #5 (pre-existing chezmoi state from the old remote flow). They are ACs 3, 4, and 5 below. Jonas also approved removing only the `DOTFILES_REPO` assertion from `tests/validate-readme.ps1` here; all README assertions stay with Story 2.5. Without AC 4 the local apply lands in `/root` when the script runs as root, so AC 1 cannot hold for the real user.

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer bootstrapping a Linux machine,
I want `setup.sh` to apply dotfiles from the local checkout,
so that the full setup flow works from one cloned repository without a second dotfiles remote.

## Acceptance Criteria

1. **Given** a local git checkout of `config-v2`, **When** `setup.sh` reaches the managed-config stage, **Then** it runs `chezmoi init --apply` with `--source "<repo-root>/dotfiles"` (non-interactive, `--force`) **And** it passes the canonical keys `GIT_USER_NAME`, `GIT_USER_EMAIL`, `GPG_FINGERPRINT` from the configuration block to chezmoi as environment variables, so the generated `~/.gitconfig` carries them **And** `setup.sh` contains no `DOTFILES_REPO`, no git remote URL, and no `chezmoi init <repo>` argument (FR1, FR2, AD-1, AD-8)

2. **Given** `setup.sh`, **When** I audit its path handling, **Then** it resolves `packages/` and `dotfiles/` relative to the directory containing `setup.sh` (repo root), never the caller's working directory **And** running it from another directory (`cd /tmp && /path/to/config-v2/setup.sh`) behaves the same **And** a missing `dotfiles/.chezmoi.toml.tmpl` or distro manifest fails **before any package install or other mutation** with `ERROR: Missing <relative_path> relative to setup.sh. Install Git manually, clone config-v2 locally, and run ./setup.sh from that checkout.` **And** a repo root that is not a git checkout fails the same way before mutation (chezmoi would otherwise `git init` inside `dotfiles/`) **And** `DOTFILES_REPO` is removed from the configuration block (AD-3, AD-8, NFR6)

3. **Given** a machine bootstrapped by `setup.sh`, **When** I later run plain `chezmoi apply` or `chezmoi verify` (no flags), **Then** chezmoi uses the checkout's `dotfiles/` as its source, because `dotfiles/.chezmoi.toml.tmpl` persists `sourceDir` into the generated config (`chezmoi source-path` prints `<repo-root>/dotfiles`) (CAP-2, FR2, readiness Major #3)

4. **Given** the privilege model, **When** `setup.sh` runs, **Then** it refuses to run as root (`EUID 0`) with an actionable `ERROR:` and exit 1, before any mutation **And** it runs as the target user and elevates only system commands with `sudo` (package-manager calls, apt keyring/repo writes) **And** fnm, SSH key, GPG check, and chezmoi run as the target user, so all user state lands in that user's `$HOME` (readiness Major #4, NFR3)

5. **Given** a machine bootstrapped by the old remote flow (existing `~/.local/share/chezmoi` and/or `~/.config/chezmoi/chezmoi.toml`), **When** `setup.sh` runs, **Then** the config is regenerated with `sourceDir` pointing at the checkout **And** the old `~/.local/share/chezmoi` directory is left untouched (not deleted, not used) (readiness Minor #5, NFR5)

6. **Given** `tests/validate-setup.ps1`, **When** I run it from repo root, **Then** it checks ACs 1–5 by running the real `setup.sh` as a non-root user inside a fresh disposable `config-v2-test` Arch WSL instance with package-manager/network shims **And** it passes **And** `tests/validate-dotfiles.ps1` still passes **And** `tests/validate-readme.ps1` passes (its 3 baseline `setup.sh` failures are fixed by this story)

## Tasks / Subtasks

- [x] Task 1: Line endings for Linux-consumed files (AC: 6, prerequisite)
  - [x] Extend `.gitattributes` with `setup.sh text eol=lf` and `packages/** text eol=lf` (keep `dotfiles/** text eol=lf`).
  - [x] Re-checkout so the working tree is LF: `git rm --cached -r -q setup.sh packages; git reset -q; git checkout -- setup.sh packages` (or delete + `git checkout`). Confirm with `git ls-files --eol setup.sh packages/` → `w/lf`.
- [x] Task 2: Write the failing test first (AC: 6, red phase)
  - [x] Create `tests/validate-setup.ps1` in the style of `tests/validate-dotfiles.ps1` (same `param([switch]$KeepInstance)`, `$repoRoot`, failure list, `finally` cleanup, `Setup validation passed.`). Dot-source `tests/lib/WslTestInstance.ps1`; do not duplicate its logic.
  - [x] Static checks on `setup.sh` (Windows side): no `DOTFILES_REPO`; no `git@`/`https://github.com/.*dotfiles`; no `\./packages/`; contains `require_repo_asset_path`; `chezmoi init` line contains `--source` and `--apply`; `bash -n` runs in the instance (below).
  - [x] Linux scenarios per Testing Requirements. Run it and confirm it fails against the current `setup.sh`.
- [x] Task 3: Rework `setup.sh` header and preflight (AC: 2, 4)
  - [x] Replace `SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"` with `REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`.
  - [x] Remove the `DOTFILES_REPO=` line. Keep `GIT_USER_NAME`, `GIT_USER_EMAIL`, `GPG_FINGERPRINT`, `SSH_KEY_FILE` unchanged (values and order).
  - [x] Add `require_repo_asset_path()` (exact contract in Dev Notes) right after the config block.
  - [x] Preflight, in this order, before distro detection: refuse root; require `sudo` on PATH; require the repo root to be a git checkout (`-e "$REPO_ROOT/.git"`; `.git` may be a file in worktrees); `require_repo_asset_path "dotfiles/.chezmoi.toml.tmpl"`.
  - [x] After distro detection and before any install: resolve the distro manifest with `require_repo_asset_path` (Arch → `packages/arch.txt`, Ubuntu → `packages/ubuntu.txt`), so a missing manifest fails before the Ubuntu apt prerequisites run.
- [x] Task 4: `sudo` for system commands only (AC: 2, 4)
  - [x] Arch: `sudo pacman -S --needed --noconfirm - < "$(require_repo_asset_path "packages/arch.txt")"` (keep this exact substring; `validate-readme.ps1` matches it unanchored).
  - [x] Ubuntu: `sudo apt-get install -y ca-certificates curl gnupg lsb-release`, `sudo install -m 0755 -d /etc/apt/keyrings`, `curl … | sudo gpg --dearmor -o …`, `sudo chmod a+r …`, `| sudo tee … > /dev/null`, `sudo apt-get update`, `sudo xargs -a "$(require_repo_asset_path "packages/ubuntu.txt")" apt-get install -y` (keep this exact substring).
  - [x] Leave the fnm `curl … | bash`, SSH, and GPG blocks without `sudo` (user-level). Do not change their logic (Story 2.3 owns them).
- [x] Task 5: Local chezmoi apply (AC: 1, 3, 5)
  - [x] After packages: if `chezmoi` is not on PATH, `ERROR:` + exit 1 (`packages/ubuntu.txt` lists `chezmoi`, which is not in every Ubuntu release's default repos; fail clearly, don't fix here).
  - [x] Replace `chezmoi init --apply "$DOTFILES_REPO"` with the exact command in Dev Notes → chezmoi apply. Update the step comment and `INFO:` text (`Applying dotfiles from $REPO_ROOT/dotfiles via chezmoi.`).
  - [x] Add `sourceDir = {{ .chezmoi.sourceDir | quote }}` to `dotfiles/.chezmoi.toml.tmpl` as a top-level key **before** `[data]` (see Dev Notes → config template).
  - [x] If `~/.local/share/chezmoi` exists, print `INFO: Leaving legacy chezmoi source at ~/.local/share/chezmoi untouched; config now points at $REPO_ROOT/dotfiles.` Never delete it.
- [x] Task 6: Make validation green (AC: 1–6)
  - [x] `pwsh -NoProfile -File tests\validate-setup.ps1` → passes.
  - [x] `pwsh -NoProfile -File tests\validate-dotfiles.ps1` → still passes (the template now renders `sourceDir`; the sandbox passes `--source` explicitly, which wins).
  - [x] In `tests/validate-readme.ps1`, remove only `'DOTFILES_REPO'` from `$requiredSetupAssignments` (it now contradicts AD-8). Leave all README assertions to Story 2.5. Then `pwsh -NoProfile -File tests\validate-readme.ps1` → passes.
- [x] Task 7: Scope guard
  - [x] `git status` shows only the files in the File Structure table. `README.md`, `packages/*` content, and other `dotfiles/` files are unchanged (line-ending renormalization of `packages/*` is not a content change).

## Dev Notes

### Scope Boundaries (read first)

| In this story | NOT in this story (owner) |
| --- | --- |
| Local `chezmoi init --apply --source <repo>/dotfiles`, identity env injection, persisted `sourceDir` | fnm `--skip-shell`, zsh as login shell, stateful vs managed path classification, `~/.ssh/config`, rerun hardening of SSH/GPG/apt-key blocks (Story 2.3) |
| Repo-root path resolution, `require_repo_asset_path`, preflight failures | Smoke verification stage, step (6) of AD-9 (Story 2.4) |
| Privilege model: refuse root, `sudo` for system commands | README text, the rest of `validate-readme.ps1` (Story 2.5) |
| `DOTFILES_REPO` removal (+ its single `validate-readme.ps1` assertion) | Ubuntu package availability (`chezmoi`, `starship`), `apt-get update` ordering, `gpg --dearmor` overwrite on rerun (Story 2.3/2.4) |
| `.gitattributes` LF for `setup.sh`, `packages/**` | `setup.ps1` (Story 3.1) |

### Current `setup.sh` (UPDATE) — what changes, what stays

- **Today:** `SCRIPT_DIR` set from `$0` but never used; manifests read as `./packages/*.txt` (caller-cwd relative, AD-3 violation); `pacman`/`apt-get` without `sudo` (implies running as root, so user state lands in `/root`); final step `chezmoi init --apply "$DOTFILES_REPO"` clones the remote (AD-1 violation).
- **Changes:** header/preflight, `sudo` on system commands, manifest paths, final chezmoi step, `DOTFILES_REPO` removal.
- **Preserve exactly:** `set -euo pipefail`; config-block keys/values for `GIT_USER_NAME`, `GIT_USER_EMAIL`, `GPG_FINGERPRINT`, `SSH_KEY_FILE`; single `/etc/os-release` distro detection and the `arch`/`ubuntu`/unsupported branches (AD-7); Docker/Microsoft apt repo logic; fnm curl install; SSH and GPG detect-before-mutate blocks and their messages; `INFO:`/`ERROR:` prefixes (`ERROR:` to stderr); AD-9 order: config+root → distro → packages → stateful assets → chezmoi.

### Architecture Compliance (MUST FOLLOW)

| Rule | Requirement for this story |
| --- | --- |
| AD-1 | chezmoi source is `<repo>/dotfiles`; no remote clone, no second repo. |
| AD-2 | `setup.sh` only sequences. No dotfile content, no file writes into `$HOME` that chezmoi manages. |
| AD-3 | All repo paths derive from `REPO_ROOT` (directory of `setup.sh`). |
| AD-4 | Personal values stay only in the `setup.sh` config block; they reach chezmoi via env at runtime, never written into `dotfiles/`. |
| AD-5 | `setup.sh` never writes `~/.gitconfig`, `~/.zshrc`, `~/.config/{starship.toml,nvim,tmux}`. |
| AD-7 | Distro-specific commands stay inside the guarded branches. |
| AD-8 | Canonical keys only; `DOTFILES_REPO` removed. Env var names = key names. |
| AD-9 | Order unchanged; chezmoi apply stays after stateful-asset prep. |

### `require_repo_asset_path` contract

`tests/validate-readme.ps1` matches this regex (singleline): `require_repo_asset_path\(\).*?Missing \$relative_path relative to setup\.sh\..*?Install Git manually, clone config-v2 locally, and run \./setup\.sh from that checkout\.` Implement as:

```bash
require_repo_asset_path() {
  local relative_path="$1"
  local absolute_path="$REPO_ROOT/$relative_path"
  if [[ ! -e "$absolute_path" ]]; then
    echo "ERROR: Missing $relative_path relative to setup.sh. Install Git manually, clone config-v2 locally, and run ./setup.sh from that checkout." >&2
    exit 1
  fi
  printf '%s\n' "$absolute_path"
}
```

Inside `$( … )` the `exit 1` only leaves the subshell. That is why preflight calls it directly (top level) before any mutation; the inline `$(require_repo_asset_path …)` uses in the install lines are then guaranteed to succeed.

### Preflight messages

- Root: `ERROR: Do not run setup.sh as root. Run it as the user you are setting up; it calls sudo for system commands.`
- No sudo: `ERROR: sudo is required. Install sudo and grant your user sudo rights, then rerun ./setup.sh.`
- Not a git checkout: reuse `require_repo_asset_path ".git"` (same message; `.git` may be a file in worktrees, so test with `-e`).
- Do **not** add `sudo -v` or any other prompt beyond what `sudo` itself needs (NFR3). sudo's own password prompt is the one accepted interaction.

### chezmoi apply (verified on chezmoi v2.73.0 in `config-v2-test`, 2026-10-07)

```bash
GIT_USER_NAME="$GIT_USER_NAME" \
GIT_USER_EMAIL="$GIT_USER_EMAIL" \
GPG_FINGERPRINT="$GPG_FINGERPRINT" \
  chezmoi init --apply --force --no-tty --source "$(require_repo_asset_path "dotfiles")"
```

Verified behavior:
- Inside a git checkout, chezmoi walks up and finds the repo's `.git`. It does **not** create `dotfiles/.git`.
- Outside a git checkout (for example an extracted zip), chezmoi **does** `git init` inside `dotfiles/`. Hence the `.git` preflight.
- Reruns are non-interactive and regenerate the config. Changed env values flow into `~/.gitconfig`. `--force` overwrites locally modified managed targets (AD-5: managed = always overwritten).
- With `sourceDir` persisted, plain `chezmoi apply`, `chezmoi verify`, and `chezmoi source-path` use `<repo>/dotfiles`. A stale `~/.local/share/chezmoi` is ignored.
- Do not use `.chezmoiroot` at repo root: unnecessary with this approach, and it changes what `.chezmoi.sourceDir` resolves to.

### Config template: `dotfiles/.chezmoi.toml.tmpl` (UPDATE)

```toml
{{- $gitUserName := env "GIT_USER_NAME" | default "Bootstrap Test User" -}}
{{- $gitUserEmail := env "GIT_USER_EMAIL" | default "bootstrap-test@example.invalid" -}}
{{- $gpgFingerprint := env "GPG_FINGERPRINT" -}}
sourceDir = {{ .chezmoi.sourceDir | quote }}
[data]
    git_user_name = {{ $gitUserName | quote }}
    git_user_email = {{ $gitUserEmail | quote }}
    gpg_fingerprint = {{ $gpgFingerprint | quote }}
```

`sourceDir` must be a top-level key, before `[data]`. A TOML key after `[data]` would land inside the table. The trailing `-}}` of the third line trims the newline; the rendered output still starts `sourceDir = "…"` on its own line (verified). No new data keys (AD-8).

### File Structure Requirements

| Path | Action |
| --- | --- |
| `setup.sh` | UPDATE |
| `dotfiles/.chezmoi.toml.tmpl` | UPDATE (add `sourceDir` line only) |
| `.gitattributes` | UPDATE (add `setup.sh`, `packages/**` LF rules) |
| `tests/validate-setup.ps1` | NEW |
| `tests/validate-readme.ps1` | UPDATE (remove `'DOTFILES_REPO'` from `$requiredSetupAssignments` only) |
| `packages/arch.txt`, `packages/ubuntu.txt` | line endings only, no content change |
| `README.md`, other `dotfiles/` files, `tests/lib/WslTestInstance.ps1`, `tests/validate-dotfiles.ps1` | DO NOT MODIFY (extend `WslTestInstance.ps1` only if a genuinely reusable helper is missing; keep the instance name and safety rules) |

### Testing Requirements

`tests/validate-setup.ps1` runs the **real** `setup.sh` in a fresh `config-v2-test` instance, like Story 2.1. Never touch other WSL distros (`archlinux`, `MyArch`). Always `Remove-ConfigV2TestInstance` in `finally` unless `-KeepInstance`.

1. `New-ConfigV2TestInstance @('chezmoi','git','openssh')` (gnupg ships with Arch base; `ssh-keygen` comes from openssh).
2. Create user `tester` (`useradd -m -s /bin/bash tester`). Run every scenario as tester via `runuser -u tester -- env -i HOME=/home/tester USER=tester PATH=/opt/config-v2-shims:/usr/local/bin:/usr/bin bash -c '…' </dev/null`.
3. Shims in `/opt/config-v2-shims` (root-owned, 0755). Each appends one line to `$SHIM_LOG` (`/var/tmp/config-v2-shims.log`, writable by tester):
   - `sudo`: log `sudo $*`, then `exec "$@"` (no real elevation).
   - `pacman`: log `pacman $*` and the stdin (manifest) to `/var/tmp/config-v2-pacman-stdin.txt`; exit 0.
   - `curl`: log `curl $*`; print `true` (so `| bash` is a no-op). Real network is not used by `setup.sh` under test.
4. Repo fixture: copy the working-tree `setup.sh`, `packages/`, `dotfiles/` into `/home/tester/config-v2` (fresh per scenario), `git init -q` it, `chown -R tester:`.
5. Scenarios (each with fresh fixture/home state unless stated):
   - **A, happy path from foreign cwd:** pre-create `/home/tester/.local/share/chezmoi/legacy-marker`. Run `cd /tmp && /home/tester/config-v2/setup.sh`. Expect exit 0; shim log has `sudo pacman -S --needed --noconfirm -`; captured stdin equals `packages/arch.txt` content (LF); `/home/tester/.config/chezmoi/chezmoi.toml` has `sourceDir = "/home/tester/config-v2/dotfiles"`; as tester, plain `chezmoi source-path` prints that path and plain `chezmoi verify` exits 0; all 5 managed targets exist in `/home/tester`; `.gitconfig` name/email/signingkey equal the `setup.sh` config values (parse them like `validate-dotfiles.ps1` does); no `/home/tester/config-v2/dotfiles/.git`; `legacy-marker` still exists; `/root/.gitconfig` and `/root/.config/chezmoi` do not exist; `~/.ssh/id_rsa` created for tester.
   - **B, rerun:** run A's command again on the same state. Expect exit 0, `chezmoi verify` 0, SSH key unchanged (same hash).
   - **C, root refused:** run as root. Expect exit ≠ 0, output has `Do not run setup.sh as root`, shim log empty.
   - **D, missing manifest:** delete `packages/arch.txt` from the fixture. Expect exit ≠ 0, output has `Missing packages/arch.txt relative to setup.sh`, no `pacman` line in shim log, no `~/.config/chezmoi`.
   - **E, missing dotfiles:** delete `dotfiles/` from the fixture. Expect exit ≠ 0, `Missing dotfiles/.chezmoi.toml.tmpl relative to setup.sh`, shim log empty.
   - **F, not a git checkout:** remove the fixture's `.git`. Expect exit ≠ 0, `Missing .git relative to setup.sh`, shim log empty, no `dotfiles/.git` created.
   - Also run `bash -n setup.sh` in the instance.
6. Ubuntu branch cannot run in the Arch instance. Cover it statically: the `sudo xargs -a "$(require_repo_asset_path "packages/ubuntu.txt")" apt-get install -y` line and `sudo` on every `apt-get`, `install -m`, `gpg --dearmor`, `chmod`, `tee` in that branch.
7. Match output with CRLF-tolerant regexes. Expect about 1–2 min per run with the cached image.

Run: `pwsh -NoProfile -File tests\validate-setup.ps1` (`-KeepInstance` to debug).

### Previous Story Intelligence (2.1)

- `tests/lib/WslTestInstance.ps1` provides `New-ConfigV2TestInstance`, `Invoke-ConfigV2TestInstance <bash> [env hashtable]` (runs as root, base64-transported, `set -euo pipefail` prepended, returns `ExitCode`/`Output`), `Remove-ConfigV2TestInstance`. Use `set +e` inside scenario scripts where a non-zero exit is the expected result.
- Behind Zscaler, the helper already injects host TLS roots; pacman downloads use retries. Do not reimplement.
- Windows `core.autocrlf=true`: new files become CRLF unless `.gitattributes` pins them. 2.1 hit this with `dotfiles/`; `setup.sh`/`packages/*` are CRLF in the working tree today (verified `git ls-files --eol`), which breaks bash and pacman input in the instance.
- 2.1 mutation testing found real gaps (a stray script executing, CRLF masking order checks). Do a few mutations here too: reintroduce `./packages/arch.txt`, drop `sudo`, drop `--source`, remove the root check. Each must fail the test.
- Commit convention: `feat: <summary> (Story 2.2)`.

### Latest Technical Information

- chezmoi v2.73.0 (Arch, 2026-10). `init` without a repo argument: if no git repo is detected for the source dir, it runs `git init` there; detection walks up parent directories (verified). `--source` is a global flag; persist it with `sourceDir` in the config template, otherwise every later command needs `--source`.
- `chezmoi init` regenerates the config from `.chezmoi.toml.tmpl` on every run without prompting when no `prompt*` functions are used.

### Project Structure Notes

- No `project-context.md`. Authoritative context: `epics.md`, the 2026-08-07 spine, SPEC/stack.md, the readiness report 2026-10-07, Story 2.1, existing code.
- Ignore `config.sh`, `DOTFILES_REPO`, and two-repo wording in Epic 1 story files and the superseded 2026-08-05 spine.
- `README.md` still describes the two-repo model after this story; Story 2.5 rewrites it.

### References

- [epics.md: Story 2.2](../planning-artifacts/epics.md)
- [implementation-readiness-report-2026-10-07.md: Major #3, #4; Minor #1, #5](../planning-artifacts/implementation-readiness-report-2026-10-07.md)
- [ARCHITECTURE-SPINE.md (2026-08-07, AD-1..AD-9)](../planning-artifacts/architecture/architecture-config-v2-dotfiles-integration-2026-08-07/ARCHITECTURE-SPINE.md)
- [2-1-create-an-in-repo-dotfiles-source-tree.md](./2-1-create-an-in-repo-dotfiles-source-tree.md)
- [SPEC.md](../specs/spec-dev-env-config-repo/SPEC.md), [stack.md](../specs/spec-dev-env-config-repo/stack.md)
- [setup.sh](../../setup.sh), [tests/validate-readme.ps1](../../tests/validate-readme.ps1), [tests/validate-dotfiles.ps1](../../tests/validate-dotfiles.ps1), [tests/lib/WslTestInstance.ps1](../../tests/lib/WslTestInstance.ps1)
- chezmoi docs: `init`, `.chezmoiroot`, "Customize your source directory", template variables (`.chezmoi.sourceDir`)

## Dev Agent Record

### Agent Model Used

Claude (AI assistant using Copilot SDK in VS Code)

### Debug Log References

- Workflow customization resolved manually (`resolve_customization.py` needs Python 3.11+ `tomllib`); no team/user overrides for dev-story or create-story.
- Red phase: `tests/validate-setup.ps1` failed on all static checks and all 7 scenarios against the old `setup.sh`. Scenario A reproduced the AD-3 bug for real: `./packages/arch.txt: No such file or directory` when run from `/tmp`.
- First harness run: `userdel -r tester` failed with "currently used by process" because `runuser` opens a PAM/systemd user session. Switched to `setpriv --reuid/--regid --init-groups` (no PAM) and `pkill` + `userdel -rf` on reset.
- `cmp` is not in the Arch base image; replaced with a `sha256sum` comparison. `sudo` is not in the base image either, so scenario G (no sudo) is meaningful.
- Found and fixed a latent cross-test bug: env-prefix lines such as `GIT_USER_NAME="$GIT_USER_NAME" \` match the `KEY=value` parser that `validate-readme.ps1`, `validate-dotfiles.ps1`, and `validate-setup.ps1` all use for the `setup.sh` config block. The second match replaced the real value and silently disabled the personal-value leak checks. `setup.sh` now passes the keys through one `env KEY=… chezmoi init …` line, and `validate-setup.ps1` fails if a canonical key is assigned more than once at line start.
- Mutation checks (temp repo copies, each must go red): root check removed → scenario C; `./packages/arch.txt` reintroduced → static + scenario A; `sudo` dropped from pacman → static + scenario A shim log; `--source` dropped → static + scenario A (`source-path` = `~/.local/share/chezmoi`); duplicate key assignment → static. All 5 caught.
- `archlinux` and `MyArch` WSL distros were listed before and after every run and never touched; `config-v2-test` is removed after each run.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- `setup.sh`: `REPO_ROOT` from `${BASH_SOURCE[0]}`; `DOTFILES_REPO` removed; `require_repo_asset_path` helper with the exact `validate-readme.ps1` message; preflight (refuse root → require sudo → require `.git` → require `dotfiles/.chezmoi.toml.tmpl`), then the distro manifest is resolved right after detection, all before any mutation. pacman/apt-get, apt keyring/repo writes use `sudo`; fnm, SSH, GPG, and chezmoi run as the target user. After packages, a missing `chezmoi` fails with `ERROR:`. The final stage runs `env GIT_USER_NAME=… GIT_USER_EMAIL=… GPG_FINGERPRINT=… chezmoi init --apply --force --no-tty --source "<repo>/dotfiles"` and reports (never touches) a legacy `~/.local/share/chezmoi`. SSH/GPG/fnm logic unchanged (Story 2.3).
- `dotfiles/.chezmoi.toml.tmpl`: top-level `sourceDir = {{ .chezmoi.sourceDir | quote }}` before `[data]`, so plain `chezmoi apply`/`verify`/`source-path` use the checkout.
- `.gitattributes`: `setup.sh` and `packages/**` pinned to LF; working copy renormalized (content unchanged).
- `tests/validate-setup.ps1` (new): static checks (no `DOTFILES_REPO`/remote URL/`./packages/`/repo-arg `chezmoi init`; required helper, `REPO_ROOT`, local `--source` init, sudo manifest installs; every Ubuntu-branch system command uses `sudo`; single assignment per canonical key) plus 7 scenarios running the real `setup.sh` in a fresh `config-v2-test` Arch instance as non-root `tester` behind sudo/pacman/curl shims: A happy path from `/tmp` with legacy chezmoi state, B rerun, C root refused, D missing manifest, E missing dotfiles, F not a git checkout, G no sudo. Plus `bash -n`.
- `tests/validate-readme.ps1`: removed only `'DOTFILES_REPO'` from `$requiredSetupAssignments` (approved by Jonas); README assertions remain for Story 2.5.
- Results: `validate-setup.ps1` passed; `validate-dotfiles.ps1` passed; `validate-readme.ps1` passed (its 3 baseline failures are fixed).
- Known, out of scope: README still describes the two-repo model (Story 2.5); Ubuntu branch is covered statically only (no Ubuntu instance); `apt-get update` ordering, `gpg --dearmor` overwrite on rerun, fnm rc writing (Story 2.3/2.4).

### File List

- `setup.sh` (modified)
- `dotfiles/.chezmoi.toml.tmpl` (modified)
- `.gitattributes` (modified)
- `tests/validate-setup.ps1` (new)
- `tests/validate-readme.ps1` (modified)
- `packages/arch.txt`, `packages/ubuntu.txt` (working-copy line endings only; no content change)
- `_bmad-output/implementation-artifacts/2-2-apply-local-dotfiles-from-setup-sh.md` (new, story file)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified: 2-2 status)

### Change Log

- 2026-10-07: Story created. ACs 3–5 added from the readiness report 2026-10-07 (approved by Jonas). chezmoi local-source behavior verified in a disposable `config-v2-test` instance.
- 2026-10-07: Implemented local dotfiles apply from `setup.sh` (repo-root paths, preflight, sudo-only system commands, persisted `sourceDir`, `DOTFILES_REPO` removed) and the sandboxed `tests/validate-setup.ps1`. Fixed the env-prefix parser collision. Status → review.