---
baseline_commit: 91ec6cf365ca12d28cd01ff959176b7ef5e0b60e
---

# Story 2.3: Preserve Stateful-Asset Safety in the Integrated Flow

Status: done
> **Sequencing:** implemented after Story 2.6 (Arch-only, commit `91ec6cf`). `setup.sh` is Arch-only; test against the single pacman flow. This story also owns three items assigned to it by the 2026-10-07 readiness report: fnm `--skip-shell` (Major #5), zsh as login shell (Major #2), and naming the classification artifact (Minor #2).

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer rerunning setup on an existing machine,
I want stateful local assets to stay protected while managed config is reapplied,
so that I can update my environment without losing SSH keys or other protected state.

## Acceptance Criteria

1. **Given** the integrated setup flow, **When** I classify bootstrap-touched paths, **Then** every path is assigned to exactly one category: `stateful-asset` or `chezmoi-managed` **And** no path is written by both setup scripts and chezmoi (AD-5).
2. **Given** a machine where protected assets already exist, **When** `setup.sh` is rerun, **Then** stateful assets are detected and preserved **And** managed dotfiles are still reapplied from `dotfiles/` to reach the latest tracked state (FR2, FR3, NFR5).

Concrete interpretation (binding for this story, derived from the readiness report and the AD-5 rule):

- **AC1a — classification artifact:** `README.md` has a `## Path Ownership` section with a table that lists every bootstrap-touched path once, with exactly one category per row. `tests/validate-readme.ps1` enforces it.
- **AC1b — no dual writers:** the fnm installer runs with `--skip-shell`, so it never writes shell rc files. `setup.sh` never writes a chezmoi-managed target. `chezmoi managed --include=files` after setup equals exactly the five managed targets, so no stateful path is ever a chezmoi target.
- **AC2a — detect-before-mutate for every stateful asset:** SSH key (existing logic, plus `~/.ssh` created `0700`), fnm install dir (skip installer if `fnm` is already installed), login shell (`chsh` to zsh only when the current login shell is not zsh), GPG keyring (read-only check, unchanged), legacy `~/.local/share/chezmoi` (reported, untouched, unchanged).
- **AC2b — managed reapplied:** a local edit to a managed target is overwritten on rerun (`chezmoi verify` exits 0 after the rerun).

## Tasks / Subtasks

- [x] Task 1: Red phase — extend `tests/validate-setup.ps1` (AC: 1, 2)
  - [x] Instance packages: `New-ConfigV2TestInstance @('chezmoi', 'git', 'openssh', 'zsh')`.
  - [x] Shims: replace the `curl` shim with the fake fnm installer; add a `chsh` shim (see "Test harness changes").
  - [x] Static checks, scenario A/B extensions and new scenario K, exactly as in "validate-setup.ps1 changes".
  - [x] Run it against the current `setup.sh`. Record in the Debug Log which checks go red. Expected red: `--skip-shell`/`--install-dir` static checks, chsh log in A, fnm-installer count in B, all K assertions, `~/.ssh` mode in A.
- [x] Task 2: Red phase — extend `tests/validate-readme.ps1` (AC: 1)
  - [x] Path Ownership section, required paths, one-category-per-row rule (see "validate-readme.ps1 changes"). Confirm it goes red.
- [x] Task 3: Implement stateful-asset handling in `setup.sh` (AC: 1, 2)
  - [x] zsh-missing check after the package stage.
  - [x] Section (3) rewritten per "Target `setup.sh` section (3)": fnm detect + `--install-dir "$FNM_DIR" --skip-shell`, login-shell detect + `sudo chsh`, SSH dir `0700`, the corrected `~/.ssh/config` comment.
  - [x] Renumber the chezmoi section to (4) if needed. No other behavior changes.
- [x] Task 4: Add the README `## Path Ownership` section and one "What the Linux bootstrap does" step (AC: 1)
- [x] Task 5: Green phase + mutation checks (AC: 1, 2)
  - [x] All four validators pass under Windows PowerShell (commands in Testing Requirements).
  - [x] Mutation checks on temp copies (each must go red, then discard): (a) drop `--skip-shell` → static; (b) remove the fnm `-x` detect (always install) → B count + K; (c) unconditional `sudo chsh` → K; (d) add `echo '# x' >> "$HOME/.zshrc"` to `setup.sh` → static AD-5 forbid; (e) add `dotfiles/private_dot_ssh/config` → A `chezmoi managed` equality; (f) put both categories in one README row → readme validator; (g) `mkdir -p` without `-m 700` → A `~/.ssh` mode.
- [x] Task 6: Scope guard
  - [x] `git status` shows only the files in the File Structure table.

### Review Findings

- [x] [Review][Patch] Orphaned public key is silently overwritten — treat an existing `$SSH_KEY_FILE.pub` as "key present": skip generation and warn (decision 2026-11-02) [setup.sh:84]
- [x] [Review][Patch] Scenario B can pass vacuously: the `local-edit-marker` append result is discarded (`| Out-Null`); assert the marker is present in `~/.zshrc` before the rerun [tests/validate-setup.ps1:363]
- [x] [Review][Patch] `Get-ProtectedAssetFingerprint` ignores the exit code, so identical error output before/after passes scenario K; fail on non-zero exit, and assert `~/.ssh` mode is `700` explicitly (not only unchanged) [tests/validate-setup.ps1:247]
- [x] [Review][Patch] Path Ownership validator checks `Contains($path)` over the whole section (prose included), so a path only in prose, or listed in two rows with different categories, passes; require each path in exactly one table row [tests/validate-readme.ps1:88]
- [x] [Review][Patch] Task 5 mutation (d) is ticked but the Debug Log says the full WSL validator was not rerun on that copy (regex checked in isolation only); run it end-to-end or annotate the task [_bmad-output/implementation-artifacts/2-3-preserve-stateful-asset-safety-in-the-integrated-flow.md:44] — fixed in review: full validate-setup.ps1 run on mutation (d) went red on the static AD-5 forbid and `chezmoi verify` in A/B/K
- [x] [Review][Defer] fnm install is not verified afterwards (`$FNM_DIR/fnm` may be absent even when the installer exits 0, causing a reinstall on every rerun), and the remote installer is unpinned [setup.sh:71] — deferred, pre-existing curl installer
- [x] [Review][Defer] A failing `sudo chsh` (non-local NSS user, path not in `/etc/shells`) aborts the bootstrap before SSH key generation and the chezmoi apply [setup.sh:80] — deferred, fail-fast by design; reorder/soft-fail is a separate decision
- [x] [Review][Defer] Scenario K seeds no `~/.gnupg` to prove it is untouched, and the `curl` shim serves the fake fnm installer for any URL [tests/validate-setup.ps1:410] — deferred, coverage hardening

## Dev Notes

### Scope Boundaries (read first)

| In this story | NOT in this story (owner) |
| --- | --- |
| Path classification table in README + validator | Full README rewrite, two-repo wording, "deferred" scope text (Story 2.5; keep the Path Ownership section intact there) |
| fnm `--skip-shell` + pinned `--install-dir` + detect-before-mutate | Installing a Node version via fnm; Angular CLI (never global, NFR9) |
| zsh login shell via `sudo chsh`, only when not already zsh | Verifying the login shell / toolchain after setup (Story 2.4 smoke verification) |
| `~/.ssh` created `0700`; SSH/GPG detect-before-mutate kept | GPG key import automation (stays manual); `~/.ssh/config` management (stays user-owned, untouched) |
| Rerun proves managed targets are reapplied and stateful ones preserved | Deferred items: `sudo -v` rights check, legacy `chezmoi.yaml/json` detection, `require_repo_asset_path` `-e` vs `-f`, `arch.txt` comment filtering, one-fixture-failure-aborts-all (see `deferred-work.md`; do not fix, do not regress) |

### Path classification (the content of the README table)

| Path | Category | Rule |
| --- | --- | --- |
| `~/.zshrc` | chezmoi-managed | Rewritten from `dotfiles/dot_zshrc` on every apply (`--force`) |
| `~/.gitconfig` | chezmoi-managed | Rendered from `dotfiles/dot_gitconfig.tmpl` with the `setup.sh` identity values |
| `~/.config/starship.toml` | chezmoi-managed | From `dotfiles/dot_config/starship.toml` |
| `~/.config/nvim/init.lua` | chezmoi-managed | From `dotfiles/dot_config/nvim/init.lua` |
| `~/.config/tmux/tmux.conf` | chezmoi-managed | From `dotfiles/dot_config/tmux/tmux.conf` |
| `~/.config/chezmoi/chezmoi.toml` | chezmoi-managed | Regenerated by `chezmoi init` from `dotfiles/.chezmoi.toml.tmpl` on every run |
| `$SSH_KEY_FILE` (default `~/.ssh/id_rsa` and `.pub`), `~/.ssh/` | stateful-asset | Generated once if missing (`~/.ssh` created `0700`); never overwritten |
| `~/.gnupg` (GPG keyring) | stateful-asset | Only checked for `GPG_FINGERPRINT`; never written by `setup.sh`; import manually |
| `~/.local/share/fnm` (fnm binary and installed Node versions) | stateful-asset | fnm installed once if missing, with `--skip-shell`; never reinstalled over an existing install |
| Login shell (the user's `/etc/passwd` entry) | stateful-asset | Changed to zsh via `sudo chsh` only when it is not zsh already |
| `~/.local/share/chezmoi` (legacy chezmoi source) | stateful-asset | Reported, never modified or deleted |

Notes:
- **Not bootstrap-touched, so not listed:** `~/.ssh/config` (user-owned; neither `setup.sh` nor chezmoi writes it — fix the misleading `setup.sh` comment), `~/.zsh_history` and `~/.local/share/zinit` (created at zsh runtime, not by bootstrap), system packages (owned by pacman, not a home path).
- Write `$SSH_KEY_FILE` / `~/.ssh/id_rsa` in README, **never** the literal `${HOME}/.ssh/id_rsa`. `validate-readme.ps1` fails if README contains any `setup.sh` config value verbatim.
- `gpg --list-keys` may create an empty `~/.gnupg` on a fresh user. That is acceptable (gpg-owned initialization, not a key mutation); do not try to avoid it.

### Current `setup.sh` (UPDATE) — what changes, what stays

Current section (3) (after Story 2.6), lines ~57–80:

```bash
# --- (3) User-level installs and stateful assets, run as the target user (no sudo) ---
# fnm via the official curl installer
echo "INFO: Installing fnm via official curl installer."
curl -fsSL https://fnm.vercel.app/install | bash
# --- SSH key: detect-before-mutate (AC 4, 5, 8, AD-4, AD-7) ---
# NOTE: ~/.ssh/config is chezmoi-managed — never written here (AD-7)
if [[ -f "$SSH_KEY_FILE" ]]; then ... else mkdir -p "$(dirname "$SSH_KEY_FILE")"; ssh-keygen ... fi
# --- GPG key: detect-before-mutate ... ---
```

Defects this story fixes:
- **fnm installer writes shell rc files (AD-5 violation).** Without `--skip-shell` the installer (verified source, 2026-10-29) appends an fnm block to `~/.bashrc` when `$SHELL` is bash, or to `~/.zshrc` (chezmoi-managed!) when `$SHELL` is zsh. Under an empty `$SHELL` it prints "Could not infer shell type" and **exits 1**, which aborts `setup.sh` (`set -e` + `pipefail`). The tests never saw this because `curl` is shimmed.
- **fnm install dir not pinned.** The installer prefers `~/.fnm` if that dir exists, then `$XDG_DATA_HOME/fnm`, then `~/.local/share/fnm`. `dot_zshrc` only looks at `${XDG_DATA_HOME:-$HOME/.local/share}/fnm`. Pin `--install-dir` to the same expression.
- **fnm reinstalled on every rerun** (network round-trip, binary replaced). Detect and skip.
- **No login shell owner.** SPEC assumes zsh; nothing sets it.
- `~/.ssh` created with default `0755` when missing.
- The `~/.ssh/config` comment is wrong (nothing manages it) and cites the old AD-7.

**Preserve exactly:** everything before the chezmoi-missing check (preflight, Arch guard, pacman line); chezmoi-missing check; SSH `-f` detect, `ssh-keygen -t rsa -b 4096 -C "$GIT_USER_EMAIL" -f "$SSH_KEY_FILE" -N ""` and both SSH messages; GPG block and messages; legacy chezmoi notice; the `env GIT_USER_NAME=… chezmoi init --apply --force --no-tty --source "$(require_repo_asset_path "dotfiles")"` line; `INFO: Bootstrap complete.`; `INFO:`/`ERROR:` prefixes. No new config-block keys (AD-8): `FNM_DIR`, `ZSH_PATH`, `TARGET_USER`, `CURRENT_SHELL` are derived values, not configuration. Do not add a second line-start `GIT_USER_NAME=`/`GIT_USER_EMAIL=`/`GPG_FINGERPRINT=` assignment (validators would fail; see Story 2.2 Debug Log).

### Target `setup.sh` section (3)

```bash
if ! command -v chezmoi >/dev/null 2>&1; then ...unchanged... fi
if ! command -v zsh >/dev/null 2>&1; then
  echo "ERROR: zsh is not installed after the package stage. Check packages/arch.txt and the pacman output." >&2
  exit 1
fi

# --- (3) Stateful assets: detect before mutate, never chezmoi-managed (AD-5; README "Path Ownership") ---
TARGET_USER="$(id -un)"
# Must match the fnm path in dotfiles/dot_zshrc.
FNM_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fnm"

# fnm: installed once. --skip-shell keeps the installer out of shell rc files; zsh integration is chezmoi-managed.
if [[ -x "$FNM_DIR/fnm" ]]; then
  echo "INFO: fnm already installed at $FNM_DIR — skipping installer."
else
  echo "INFO: Installing fnm to $FNM_DIR via the official curl installer."
  curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$FNM_DIR" --skip-shell
fi

# Login shell: zsh, changed only when it is not zsh already.
ZSH_PATH="$(command -v zsh)"
CURRENT_SHELL="$(getent passwd "$TARGET_USER" | cut -d: -f7)"
if [[ "$(basename "${CURRENT_SHELL:-none}")" == "zsh" ]]; then
  echo "INFO: Login shell for $TARGET_USER is already zsh — skipping."
else
  echo "INFO: Changing login shell for $TARGET_USER to $ZSH_PATH (takes effect in the next login session)."
  sudo chsh -s "$ZSH_PATH" "$TARGET_USER"
fi

# SSH key: generated once, never overwritten. ~/.ssh/config is user-owned; neither setup.sh nor chezmoi writes it.
if [[ -f "$SSH_KEY_FILE" ]]; then
  echo "INFO: SSH key already exists at $SSH_KEY_FILE — skipping generation."
else
  echo "INFO: Generating SSH key at $SSH_KEY_FILE."
  mkdir -p -m 700 "$(dirname "$SSH_KEY_FILE")"
  ssh-keygen -t rsa -b 4096 -C "$GIT_USER_EMAIL" -f "$SSH_KEY_FILE" -N ""
fi

# GPG key: checked only, never written by setup.sh.
...GPG block unchanged...

# --- (4) Apply managed dotfiles ... unchanged ---
```

Rules:
- **No literal managed-target names in non-comment `setup.sh` lines** (`.zshrc`, `.gitconfig`, `.config/starship`, `.config/nvim`, `.config/tmux`). The validator forbids them on non-comment lines. Comments may say "zsh integration", not the filename.
- `mkdir -p -m 700` applies the mode only to the last directory and only if it creates it; existing `~/.ssh` permissions stay untouched (detect-before-mutate). `ssh-keygen` writes the key `0600` itself.
- `basename` comparison treats `/bin/zsh`, `/usr/bin/zsh` the same. On Arch, `/bin` is a symlink to `/usr/bin` and the zsh package adds both to `/etc/shells`.
- `chsh` must run through `sudo`. As a normal user it asks for the account password via PAM (an extra prompt, NFR3). Root `chsh` changes another user's shell without a password. sudo's own prompt is the one accepted interaction (Story 2.2 rule). Use `chsh` (the narrow tool for this change), not `usermod`.
- `getent` (glibc), `id`, `cut`, `basename` are in Arch base. `$HOME` is always set (the tests pass it via `env -i HOME=…`); `set -u` is safe.
- The fnm installer needs `curl` and `unzip`: `unzip` is in `arch.txt`, `curl` is in Arch base.
- WSL: the new login shell takes effect at the next `wsl` session; the INFO message says so.

### Architecture Compliance (MUST FOLLOW)

| Rule | Requirement for this story |
| --- | --- |
| AD-2 | `setup.sh` only sequences. No dotfile content written by `setup.sh`; fnm/zsh installs stay with their installer/pacman. |
| AD-4 | Fixtures and README stay public-safe. No real key material committed; test fixtures write fake key text inside the disposable instance only. |
| AD-5 | Every bootstrap-touched path is in exactly one category (README table). `setup.sh` never writes a managed target; chezmoi never targets a stateful path. |
| AD-7 | Arch-only flow unchanged; guard stays in preflight. |
| AD-8 | No new config keys. |
| AD-9 | Order unchanged: preflight → packages → stateful assets (fnm, login shell, SSH, GPG) → chezmoi apply. Login shell change belongs to step (4) "prepare stateful assets" of AD-9; it runs after packages so zsh exists. |
| NFR3 | No new prompts besides sudo's own. |
| NFR5 | Managed content always reapplied; stateful assets detect-before-mutate. |

### Test harness changes (`tests/validate-setup.ps1`)

Shims (inside `$shimSetup`):
- **curl** → prints a fake installer script, so `curl … | bash -s -- <args>` runs it with the real args:

```bash
cat > $shimDir/curl <<'SHIM'
#!/bin/bash
echo "curl $*" >> /var/tmp/config-v2-shims.log
cat <<'INSTALLER'
echo "fnm-installer $*" >> /var/tmp/config-v2-shims.log
dir=""
while [ $# -gt 0 ]; do case "$1" in --install-dir) dir="$2"; shift 2 ;; *) shift ;; esac; done
[ -n "$dir" ] || { echo "fake fnm installer: --install-dir missing" >&2; exit 1; }
mkdir -p "$dir" && printf '#!/bin/sh\n' > "$dir/fnm" && chmod +x "$dir/fnm"
INSTALLER
SHIM
```

  (Use the existing `$shimLog` variable through the here-string expansion, as today; the snippet shows the literal path for readability. Mind PowerShell backtick-escaping of `$` inside the `@"…"@` here-string, as the current shims do.)
- **chsh** → `echo "chsh $*" >> $shimLog`, exit 0. `sudo` shim `exec "$@"` resolves `chsh` via `PATH`, so the shim wins over `/usr/bin/chsh` (which as `tester` would prompt and fail).
- `chmod 0755` the new shim too.

### validate-setup.ps1 changes (UPDATE)

1. **Instance:** add `'zsh'` to `New-ConfigV2TestInstance`. Without it, `setup.sh` fails the new zsh check (pacman is shimmed).
2. **Static required patterns:**
   - `'fnm installer with pinned dir and --skip-shell (AD-5)'` → `curl -fsSL https://fnm\.vercel\.app/install \| bash -s -- --install-dir "\$FNM_DIR" --skip-shell`
   - `'fnm dir matching dot_zshrc'` → `FNM_DIR="\$\{XDG_DATA_HOME:-\$HOME/\.local/share\}/fnm"`
   - `'login shell change via sudo chsh'` → `sudo chsh -s "\$ZSH_PATH" "\$TARGET_USER"`
3. **Static forbidden patterns:**
   - `'fnm installer without --skip-shell (AD-5)'` → `(?m)^[^#\n]*fnm\.vercel\.app/install(?![^\n]*--skip-shell)`
   - `'write to a chezmoi-managed target (AD-5)'` → `(?m)^[^#\n]*(\.zshrc|\.gitconfig|\.config/(starship|nvim|tmux))`
4. **Scenario A additions** (fresh user, login shell `/bin/bash`):
   - Shim log has `fnm-installer --install-dir /home/tester/.local/share/fnm --skip-shell` (exact line, CRLF-tolerant) and `sudo chsh -s /usr/bin/zsh tester`.
   - Relax the sudo loop: allowed `^sudo (pacman|chsh) `; any other `sudo` line still fails.
   - `stat -c %a ~/.ssh` is `700`; `stat -c %a ~/.ssh/id_rsa` is `600`.
   - `Invoke-AsTester 'chezmoi managed --include=files'`: the trimmed, sorted lines equal the sorted `$managedTargets` exactly. Failure message: list the extra/missing paths. This is the AD-5 "no stateful path is managed" proof.
   - `~/.local/share/fnm/fnm` exists and is executable.
5. **Scenario B additions** (rerun on A's state):
   - Before the rerun: as tester, append `# local-edit-marker` to `~/.zshrc`.
   - After: `~/.zshrc` no longer contains `local-edit-marker` (managed reapplied; `chezmoi verify` already asserted).
   - Shim log contains exactly **one** `fnm-installer` line in total (A's), and the rerun output contains `fnm already installed`.
   - SSH key hash unchanged (existing assertion).
   - Do **not** assert chsh absence in B: the shim cannot really change the shell, so B still sees `/bin/bash`. Scenario K covers the skip.
6. **New scenario K — protected assets pre-exist on a first run.** Run after G and before H–J (H–J must stay last; they fake `/etc/os-release`). `Reset-Fixture` with a root mutation:
   - `usermod -s /usr/bin/zsh tester`
   - as tester: `mkdir -p -m 700 ~/.ssh`, write fake text `fake-private-key-fixture` to `~/.ssh/id_rsa` (`chmod 600`) and `fake-public-key-fixture` to `~/.ssh/id_rsa.pub`
   - as tester: `mkdir -p ~/.local/share/fnm/node-versions/v0-fixture`, create an executable `~/.local/share/fnm/fnm` (`#!/bin/sh`)
   - Record `sha256sum` of `id_rsa`, `id_rsa.pub`, `fnm`, and `find ~/.local/share/fnm | sort | sha256sum`.
   - Run `Invoke-Setup`. Expect exit 0. Shim log has **no** `fnm-installer` and **no** `chsh` line. Output contains `SSH key already exists`, `fnm already installed`, `Login shell for tester is already zsh`. All recorded hashes are unchanged. `~/.ssh` mode is still `700`. All managed targets exist and `chezmoi verify` exits 0.
   - Use the existing `$asTester` prefix for user-owned seeding so ownership is `tester`.

Keep scenarios C–J, the shims for sudo/pacman, `Assert-FailedBeforeMutation` (its "shim log empty" check still holds: failures happen before curl/chsh), `-KeepInstance`, and the `finally` cleanup.

### validate-readme.ps1 changes (UPDATE)

1. Required heading `(?im)^##\s+Path Ownership\s*$`.
2. Extract the section: `(?ims)^##\s+Path Ownership\s*$(?<body>.*?)(?=^##\s|\z)`.
3. Section must mention, each literally: `~/.zshrc`, `~/.gitconfig`, `~/.config/starship.toml`, `~/.config/nvim/init.lua`, `~/.config/tmux/tmux.conf`, `~/.config/chezmoi/chezmoi.toml`, `$SSH_KEY_FILE`, `~/.gnupg`, `~/.local/share/fnm`, `Login shell`, `~/.local/share/chezmoi`.
4. **One category per row:** every table row in the section (a line starting with `|` that is not the header or the `| --- |` separator) contains exactly one of `stateful-asset` / `chezmoi-managed`. Zero or two → failure naming the row.
5. Keep everything else (Story 2.6 forbids, the two-repo check, value-leak check).

### README.md (UPDATE)

- In "What the Linux bootstrap does", insert a step between package install and chezmoi: `prepares stateful assets (fnm, zsh as login shell, SSH key) without overwriting any that already exist`. Renumber the list.
- Add `## Path Ownership` after "What the Linux bootstrap does" and before "Architecture Overview". One intro sentence ("Every path the bootstrap touches has exactly one owner: chezmoi rewrites managed paths on every run; `setup.sh` creates stateful assets only when they are missing and never overwrites them."), then the table from "Path classification" above (one path per row, so the one-category rule is checkable), then the "not listed" note for `~/.ssh/config`.
- Do not touch other sections (Story 2.5).

### File Structure Requirements

| Path | Action |
| --- | --- |
| `setup.sh` | UPDATE (zsh check, section 3) |
| `tests/validate-setup.ps1` | UPDATE |
| `tests/validate-readme.ps1` | UPDATE |
| `README.md` | UPDATE (one list step + Path Ownership section) |
| `_bmad-output/implementation-artifacts/2-3-…md`, `sprint-status.yaml` | status/record updates only |
| `dotfiles/**`, `packages/arch.txt`, `tests/lib/WslTestInstance.ps1`, `tests/validate-dotfiles.ps1`, `tests/validate-wsl-test-ca.ps1`, `.gitattributes`, planning artifacts | DO NOT MODIFY |

`zsh` is already in `packages/arch.txt`; `dot_zshrc` already has the fnm integration at `${XDG_DATA_HOME:-$HOME/.local/share}/fnm`, so no dotfiles change is needed.

### Testing Requirements

Run under **Windows PowerShell**, sequentially (same `config-v2-test` instance name):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\validate-setup.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests\validate-dotfiles.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests\validate-readme.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests\validate-wsl-test-ca.ps1
```

- Never touch other WSL distros (currently `archlinux`). List `wsl -l -q` before/after. Do not use them even for read-only checks. Run `bash -n` on mutation copies inside `config-v2-test` (with `-KeepInstance`) or rely on the validator's own `bash -n`.
- Expect ~3–4 min for `validate-setup.ps1` (one more scenario, zsh in the instance).
- Mutation checks in Task 5 are required. When a mutation must avoid a static forbid to test behavior in isolation, make sure the mutated `setup.sh` is still valid bash (Story 2.6 lesson: `${ID_''LIKE}` was a bad substitution).

### Previous Story Intelligence

- **Story 2.6 (review, `91ec6cf`):** Arch-only guard in preflight; validators have scenarios A–J; H–J fake `/etc/os-release` via `Set-FakeOsRelease`/`Restore-OsRelease` and must stay last. `Assert-FailedBeforeMutation` also asserts no `~/.ssh`. The forbid list scans whole `setup.sh` content, so keep Ubuntu/apt/`ID_LIKE` words out of new comments too.
- **Story 2.2:** `setpriv` (not `runuser`) for tester; shim log is the mutation oracle; `sha256sum` instead of `cmp`; the Arch image lacks `sudo`; identity keys pass through one `env …` line.
- **Story 2.1:** `dot_zshrc` deliberately carries the fnm integration and looks only at the XDG path. It anticipated this story's `--skip-shell`.
- **Story 3.1 (cancelled):** the `WslTestInstance.ps1` stderr fix makes expected-failure output capturable under Windows PowerShell 5.1.

### Git Intelligence

- `91ec6cf feat: narrow bootstrap to Arch Linux only (Story 2.6)`: current `setup.sh` / validator baseline.
- `c9b569e`: harness stderr fix. `45598f9`: Story 2.2 baseline of the stateful section.
- Commit convention: `feat: protect stateful assets on rerun (Story 2.3)` with the `Co-authored-by` trailer.

### Latest Technical Information

- **fnm installer** (`https://fnm.vercel.app/install`, fetched 2026-10-29): flags `-d|--install-dir <dir>`, `-s|--skip-shell`, `-r|--release`, `--force-install`. Default dir: `~/.fnm` if it exists, else `$XDG_DATA_HOME/fnm`, else `~/.local/share/fnm`. Requires `curl` and `unzip`. It only replaces `$INSTALL_DIR/fnm`; it never deletes installed Node versions. Without `--skip-shell` it appends to `~/.zshrc`/`~/.bashrc`/fish config based on `basename $SHELL`, and exits 1 if the shell is unknown or empty. Pipe flags with `bash -s -- <flags>`.
- **chezmoi v2.73.0** (instance): `chezmoi managed --include=files` prints managed file targets relative to the destination dir (e.g. `.config/nvim/init.lua`), one per line. `--force` on apply overwrites locally modified targets.
- **util-linux `chsh`**: root may set any user's shell without a password; non-root requires PAM auth. The shell should be listed in `/etc/shells` (Arch's zsh package registers `/bin/zsh` and `/usr/bin/zsh`).

### Project Structure Notes

- No `project-context.md`. Authoritative context: `epics.md` (Story 2.3), the 2026-08-07 spine (AD-5, AD-9), readiness report 2026-10-07 (Major #2, #5; Minor #2), SPEC (CAP-3, NFR5), Stories 2.1/2.2/2.6, current code.
- Ignore stateful-asset rules in the superseded 2026-08-05 spine and its adversarial review (they treat `~/.ssh/config` as a setup.sh-written stateful asset; that model is superseded).

### References

- [epics.md: Story 2.3](../planning-artifacts/epics.md)
- [ARCHITECTURE-SPINE.md (2026-08-07): AD-2, AD-4, AD-5, AD-8, AD-9](../planning-artifacts/architecture/architecture-config-v2-dotfiles-integration-2026-08-07/ARCHITECTURE-SPINE.md)
- [implementation-readiness-report-2026-10-07.md: Major #2, #5; Minor #2](../planning-artifacts/implementation-readiness-report-2026-10-07.md)
- [SPEC.md: CAP-3](../specs/spec-dev-env-config-repo/SPEC.md), [stack.md](../specs/spec-dev-env-config-repo/stack.md)
- [2-6-narrow-the-bootstrap-to-arch-linux-only.md](./2-6-narrow-the-bootstrap-to-arch-linux-only.md), [2-2-apply-local-dotfiles-from-setup-sh.md](./2-2-apply-local-dotfiles-from-setup-sh.md), [2-1-create-an-in-repo-dotfiles-source-tree.md](./2-1-create-an-in-repo-dotfiles-source-tree.md), [deferred-work.md](./deferred-work.md)
- [setup.sh](../../setup.sh), [dotfiles/dot_zshrc](../../dotfiles/dot_zshrc), [tests/validate-setup.ps1](../../tests/validate-setup.ps1), [tests/validate-readme.ps1](../../tests/validate-readme.ps1), [README.md](../../README.md)

## Dev Agent Record

### Agent Model Used

Claude (AI assistant using Copilot SDK in VS Code)

### Debug Log References

- Workflow customization resolved manually (Python 3.11+ `tomllib` unavailable); no team/user overrides. No `project-context.md`. Baseline WSL distros: `archlinux` only. It was listed after every run and never touched, not even read-only. `config-v2-test` was removed after each run.
- Red phase:
  - `validate-readme.ps1` failed with "Path Ownership section" missing.
  - `validate-setup.ps1` failed the static checks (fnm without `--skip-shell`, missing pinned `FNM_DIR`, missing `sudo chsh`). Scenarios A and K aborted with `fake fnm installer: --install-dir missing`. That mirrors the real installer: it exits 1 when it cannot infer the shell, and it ignores the XDG path the managed zsh config expects. B, K, and the mode checks never got that far.
- Green phase (Windows PowerShell 5.1, sequential): `validate-readme`, `validate-wsl-test-ca`, `validate-setup` (A–K, H–J last), and `validate-dotfiles` all passed.
- Mutation checks (temp copies):
  - (a) `--skip-shell` dropped → static forbid + required + A shim-log check.
  - (b) fnm detect removed → B "installer ran 2 times" + K.
  - (c) unconditional chsh → K.
  - (e) `dotfiles/private_dot_ssh/config` added → A `chezmoi managed` reported extra `.ssh/config`.
  - (f) second category in one README row → readme validator.
  - (g) `mkdir -p` without `-m 700` → A modes `755,600`.
  - **(d) was missed at first.** The mutation line `echo '# x' >> "$HOME/.zshrc"` has a `#` before the target, and the forbid regex `^[^#\n]*` treated it as a comment. chezmoi `--force` then hid the write at runtime. I changed the regex to `^(?!\s*#)[^\n]*…`, which skips only full comment lines. It now matches mutation (d) and a plain `>> "$HOME/.gitconfig"` write, and does not match the real `setup.sh`. That was checked with the validator's exact regex. The full suite then passed again. I did not rerun the full WSL validator on the (d) copy.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- `setup.sh`:
  - After packages, a missing `zsh` fails with `ERROR:`.
  - Section (3) handles stateful assets, each checked before any change:
    - fnm is installed only if `$FNM_DIR/fnm` is missing. `FNM_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fnm"`, the same path `dot_zshrc` uses. The install runs `bash -s -- --install-dir "$FNM_DIR" --skip-shell`.
    - The login shell is changed to zsh via `sudo chsh -s "$ZSH_PATH" "$TARGET_USER"` only when `basename` of the `getent passwd` shell is not `zsh`.
    - `~/.ssh` is created with `mkdir -p -m 700` when missing.
    - The `~/.ssh/config` comment now says it is user-owned.
  - GPG and legacy-chezmoi behavior are unchanged. No new config keys.
- `tests/validate-setup.ps1`:
  - The test machine now includes `zsh`.
  - The `curl` shim serves a fake fnm installer that logs its args and creates `<install-dir>/fnm`. A new `chsh` shim was added.
  - New static checks: required pinned/`--skip-shell` installer, `FNM_DIR`, and `sudo chsh`. Forbidden: fnm without `--skip-shell`, and any non-comment line naming a chezmoi-managed target.
  - Scenario A now also checks the installer args, the fnm binary, `sudo chsh` (sudo is allowed only for pacman/chsh), `~/.ssh` 700 / key 600, and that `chezmoi managed --include=files` equals the five managed targets exactly.
  - Scenario B now also checks that a local `~/.zshrc` edit is overwritten, that the installer runs once in total, and the "fnm already installed" message.
  - New scenario K: a seeded fake SSH key pair, fnm with a Node-versions dir, and a zsh login shell are left unchanged (fingerprint of hashes, tree and modes), with no installer or chsh calls and managed targets applied.
- `tests/validate-readme.ps1`: requires `## Path Ownership`, all 11 path entries, and exactly one `stateful-asset`/`chezmoi-managed` category per table row.
- `README.md`: new step 3 "prepares stateful assets …", and the `## Path Ownership` table (6 chezmoi-managed, 5 stateful-asset rows) with the note on `~/.ssh/config` and runtime zsh files. Other sections are untouched (Story 2.5).

### File List

- `setup.sh` (modified)
- `tests/validate-setup.ps1` (modified)
- `tests/validate-readme.ps1` (modified)
- `README.md` (modified)
- `_bmad-output/implementation-artifacts/2-3-preserve-stateful-asset-safety-in-the-integrated-flow.md` (new)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)

### Change Log

- 2026-10-29: Story 2.3 implemented. Stateful assets (fnm, login shell, SSH key) are now checked before any change. fnm is installed with a pinned dir and `--skip-shell`. A README Path Ownership table records each path's category and is enforced by the validators. Rerun and pre-existing-asset scenarios were added. Status → review.
