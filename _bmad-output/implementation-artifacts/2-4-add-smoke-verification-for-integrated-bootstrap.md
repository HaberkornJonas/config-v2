---
baseline_commit: fe2eccbf5bb398473942e8663666ba3e9c79d7e5
---

# Story 2.4: Add Smoke Verification for Integrated Bootstrap

Status: done

> **Sequencing:** builds on Story 2.3 (`setup.sh` sections 1–4, scenarios A–L in `tests/validate-setup.ps1`) and Story 2.6 (Arch-only). Story 2.5 (README rewrite) comes after; this story only adds the minimum README lines its AC needs. It also closes two readiness-report items: Major #7 (the verification trigger is automatic *and* runnable standalone) and "assert zsh login shell in Story 2.4" (FR1 sub-requirement).

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer validating the setup flow,
I want a repo-local smoke verification stage,
so that successful bootstrap means the machine is actually usable, not just that the script exited zero.

## Acceptance Criteria

1. **Given** the supported Arch Linux setup flow, **When** package installation and local dotfile apply complete, **Then** a repo-local verification stage runs automatically or via a documented repo-local command **And** it checks the expected package toolchain, key managed files or symlinks, and primary shell or editor entrypoints (AD-6, NFR7).
2. **Given** verification detects a missing expected outcome, **When** the check fails, **Then** the result is surfaced as an actionable failure signal **And** the user can tell which part of the integrated setup flow is broken (FR1, FR3).

Concrete interpretation (binding for this story; decisions confirmed by Jonas 2026-11-05):

- **AC1a — both triggers:** `setup.sh` runs `tests/verify-setup.sh` automatically as its last stage (AD-9 step 6), after `chezmoi init --apply`. `./setup.sh --verify` runs preflight and then only the verification: no package, stateful-asset or chezmoi mutation. `INFO: Bootstrap complete.` is printed only after verification passes.
- **AC1b — what is checked**, grouped by stage tag:
  - `[packages]` — every entry of `packages/arch.txt` is installed (`pacman -Q`, no sudo), and the key commands are on `PATH`: `chezmoi git zsh nvim tmux starship zoxide fzf docker dotnet`.
  - `[stateful]` — fnm is executable at `$FNM_DIR/fnm` (this also covers the 2.3 deferred "fnm install not verified" item at the detection level). The SSH private key `$SSH_KEY_FILE` exists. **An orphaned `.pub` without its private key is a FAIL** with a restore-or-remove hint. The login shell (`getent passwd`) is zsh. A GPG key missing from the keyring is a **WARN only** (import is manual by design) and never fails verification.
  - `[dotfiles]` — `chezmoi source-path` is `<checkout>/dotfiles`, `chezmoi verify` exits 0, and every target from `chezmoi managed --include=files` exists.
  - `[shell]` — `~/.zshrc` exists and passes `zsh -n`.
  - `[editor]` — `nvim --headless` loads `${XDG_CONFIG_HOME:-$HOME/.config}/nvim/init.lua` as `$MYVIMRC` with no error output.
- **AC2a — actionable and complete:** every failed check prints one `ERROR: [<stage>] <what is wrong>. <how to fix>` line. Verification runs **all** checks, so it never stops at the first failure. It ends with `INFO: Verification passed (<n> checks).` or `ERROR: Verification failed: <k> of <n> checks failed (stages: <list>).`, then `setup.sh` prints its own `ERROR: Smoke verification failed …` and exits non-zero.
- **AC2b — read-only:** `tests/verify-setup.sh` never installs, applies, generates or deletes anything. It contains no `sudo`, no package install or removal, no `chezmoi apply|init|update|add|re-add`, no `curl`/`wget`, no `chsh`/`usermod`, no `ssh-keygen`, and no GPG import or key generation.

## Tasks / Subtasks

- [x] Task 1: Red phase — extend `tests/validate-setup.ps1` (AC: 1, 2)
  - [x] Instance packages `@('chezmoi', 'git', 'openssh', 'zsh', 'neovim')`. The editor check needs a real nvim; every other toolchain binary is faked (decision: fake toolchain).
  - [x] Shims and fixture reset as in "Test harness changes": pacman `-Q` fake db, `chsh` shim that really edits `/etc/passwd`, fake tool executables, copy `tests/verify-setup.sh` into the fixture.
  - [x] Static checks for `setup.sh` and `tests/verify-setup.sh` ("Static checks").
  - [x] Scenario changes A, B, L and new scenarios M, N, P, Q, R ("Scenario changes").
  - [x] Run it against the current tree. Record in the Debug Log which checks go red (expected: all new static checks, A "Verification passed", M–R, and L's new non-zero exit expectation).
- [x] Task 2: Red phase — extend `tests/validate-readme.ps1` (AC: 1). Require the documented `./setup.sh --verify` command and a bootstrap step that names smoke verification. Confirm it goes red.
- [x] Task 3: Create `tests/verify-setup.sh` per "Target `tests/verify-setup.sh`" (AC: 1, 2)
- [x] Task 4: Wire verification into `setup.sh` per "Target `setup.sh` changes" (AC: 1, 2)
  - [x] Argument parsing (`--verify` only), preflight asset check for `tests/verify-setup.sh`, derived `TARGET_USER`/`FNM_DIR` moved before the verify-only branch, `run_smoke_verification` function, final stage (5), `Bootstrap complete` after it.
- [x] Task 5: `.gitattributes` gets `tests/*.sh text eol=lf`. README gets a step 5 and the `./setup.sh --verify` sentence (AC: 1)
- [x] Task 6: Green phase + mutation checks (AC: 1, 2)
  - [x] All four validators pass under Windows PowerShell (commands in Testing Requirements).
  - [x] Mutation checks on temp copies (each must go red, then discard):
    - (a) `verify-setup.sh` always exits 0 → N.
    - (b) verify stops at the first failure (`exit 1` inside `fail`) → N failure count.
    - (c) `setup.sh` ignores a non-zero verification exit → N/L.
    - (d) the `run_smoke_verification` call moved before `chezmoi init --apply` → static order + A.
    - (e) `verify-setup.sh` runs `chezmoi apply --force` → static forbid + N ("init.lua still missing").
    - (f) the login shell check removed → N.
    - (g) the orphan `.pub` treated as OK → L.
    - (h) a GPG miss turned into a FAIL → A (no fixture key is imported).
    - (i) `verify-setup.sh` saved with CRLF → static.
    - (j) README without `./setup.sh --verify` → readme validator.
- [x] Task 7: Scope guard — `git status` shows only the files in the File Structure table.

### Review Findings

- [x] [Review][Patch] Read-only forbid guard misses `set -euo pipefail` (`\bset -e\b` has no match before `u`) [tests/validate-setup.ps1:143]
- [x] [Review][Patch] `gpg --list-keys` creates `~/.gnupg` when missing, breaking the read-only guarantee [tests/verify-setup.sh:50]
- [x] [Review][Patch] Fixture copy of `verify-setup.sh` swallows failures (`2>/dev/null || true`) [tests/validate-setup.ps1:196]
- [x] [Review][Patch] Misleading comment: `TARGET_USER` is not passed to verification, only `FNM_DIR` is [setup.sh:73]
- [x] [Review][Defer] Neovim check has no timeout and may write state files [tests/verify-setup.sh:87] — deferred, `init.lua` is plugin-free today
- [x] [Review][Defer] Empty SSH key file passes; `$ZDOTDIR` ignored for `.zshrc` [tests/verify-setup.sh:42] — deferred, low-impact hardening
- [x] [Review][Defer] Hardcoded command list duplicates the manifest; forbid scan masks quoted `pass`/`fail`/`warn`/`echo` text [tests/verify-setup.sh:30] — deferred, documented trade-off

## Dev Notes

### Scope Boundaries (read first)

| In this story | NOT in this story (owner) |
| --- | --- |
| `tests/verify-setup.sh` (read-only checks, stage-tagged output) | Fixing what verification finds: no reinstall loops, no auto-repair (verification only reports) |
| `setup.sh` stage (5) + `--verify` argument | Any other `setup.sh` behavior change; new config keys (AD-8) |
| README: one list step + one `./setup.sh --verify` sentence; validator for both | README two-repo wording ("separate dotfiles repo" in step 4, "Architecture Overview"), full rewrite, deferred-scope text (Story 2.5; leave untouched) |
| Faked toolchain in the WSL test (pacman query db + fake binaries) | Real full-manifest install in tests (rejected: dotnet-sdk/docker download cost) |
| `[stateful]` fnm presence check | Fixing an fnm installer that exits 0 without a binary, or pinning the installer (still deferred) |
| — | `sudo -v` rights check, legacy `chezmoi.yaml/json`, `require_repo_asset_path` `-e` vs `-f`, guard-order check by message text, quoted `ID="arch"` scenario, scenario K `~/.gnupg` seeding (see `deferred-work.md`; do not fix, do not regress) |

### Current `setup.sh` (UPDATE) — what changes, what stays

Current structure (after Story 2.3, commit `91ec6cf` + 2.3 work):

1. `REPO_ROOT` and the config block (`GIT_USER_NAME`, `GIT_USER_EMAIL`, `GPG_FINGERPRINT`, `SSH_KEY_FILE`), then `require_repo_asset_path()`.
2. `(1) Preflight`: not root, sudo present, Arch-only guard (`/etc/os-release` read in a subshell), `require_repo_asset_path` for `.git`, `dotfiles/.chezmoi.toml.tmpl`, `packages/arch.txt`.
3. `(2)` `sudo pacman -S --needed --noconfirm - < "$(require_repo_asset_path "packages/arch.txt")"`, then the chezmoi-missing and zsh-missing checks.
4. `(3) Stateful assets`: `TARGET_USER`, `FNM_DIR`, then fnm detect/install, login shell `sudo chsh`, SSH key (incl. orphan `.pub` skip), GPG check.
5. `(4)`: legacy chezmoi notice, `env GIT_USER_NAME=… chezmoi init --apply --force --no-tty --source "$(require_repo_asset_path "dotfiles")"`.
6. `echo "INFO: Bootstrap complete."`

**Preserve exactly:** everything in 1–5 except the moves listed below; all `INFO:`/`ERROR:` messages; the single line-start assignment of each identity key (a second `GIT_USER_NAME=` etc. at line start fails three validators); no literal managed-target names on non-comment lines (AD-5 static forbid: `.zshrc`, `.gitconfig`, `.config/starship|nvim|tmux`); no `ubuntu`/`apt`/`dpkg`/`ID_LIKE` words even in comments (the forbid list scans the whole file).

### Target `setup.sh` changes

```bash
# (after the configuration block and require_repo_asset_path)

# --- Arguments: none = full bootstrap; --verify = preflight + smoke verification only (no mutation) ---
VERIFY_ONLY=false
if [[ $# -gt 1 || ( $# -eq 1 && "$1" != "--verify" ) ]]; then
  echo "ERROR: Unknown arguments '$*'. Usage: ./setup.sh [--verify]" >&2
  exit 1
fi
if [[ "${1:-}" == "--verify" ]]; then
  VERIFY_ONLY=true
fi

# Runs the repo-local smoke verification (AD-6, AD-9 step 6). Exits non-zero with an actionable hint on failure.
run_smoke_verification() {
  echo "INFO: Running smoke verification (tests/verify-setup.sh)."
  if ! env SSH_KEY_FILE="$SSH_KEY_FILE" GPG_FINGERPRINT="$GPG_FINGERPRINT" FNM_DIR="$FNM_DIR" \
      bash "$(require_repo_asset_path "tests/verify-setup.sh")"; then
    echo "ERROR: Smoke verification failed. Fix the [stage] items reported above, then rerun ./setup.sh (or ./setup.sh --verify to re-check only)." >&2
    exit 1
  fi
}

# (1) Preflight: unchanged, plus one more asset check next to the others:
require_repo_asset_path "tests/verify-setup.sh" >/dev/null

# Derived values (not configuration, AD-8) — moved here from section (3) so --verify can pass them on.
TARGET_USER="$(id -un)"
# Must match the fnm path in dotfiles/dot_zshrc.
FNM_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fnm"

if [[ "$VERIFY_ONLY" == true ]]; then
  run_smoke_verification
  echo "INFO: Verification complete; nothing was changed."
  exit 0
fi

# (2) packages … (3) stateful assets (minus the two moved lines) … (4) chezmoi apply — all unchanged

# --- (5) Smoke verification (AD-6, AD-9) ---
run_smoke_verification

echo "INFO: Bootstrap complete."
```

Rules:
- Argument parsing must sit **before** the root check, so `./setup.sh --bogus` fails without any side effect. The usage error is an `ERROR:` line on stderr with exit 1.
- `--verify` still runs the full preflight: not root, sudo present, Arch-only, checkout assets. Verification needs no sudo, but the preflight keeps one code path, and a non-Arch host must never be told "verified".
- Invoke the script with `bash <path>`, never `./tests/verify-setup.sh`. Git stores files `100644`; the WSL fixture copy is not guaranteed to be executable.
- `env … bash` inherits `PATH`/`HOME` (needed for the test shims and `chezmoi`). Only the three named values are passed: `SSH_KEY_FILE`, `GPG_FINGERPRINT`, `FNM_DIR`. Identity keys stay in their one `env … chezmoi init` line.
- `set -euo pipefail` stays. The `if ! … ; then` form keeps `set -e` from aborting before the hint is printed.

### Target `tests/verify-setup.sh` (NEW)

```bash
#!/usr/bin/env bash
# Repo-local smoke verification for the config-v2 bootstrap (AD-6). Read-only: reports, never repairs.
# Run it through ./setup.sh (last stage) or ./setup.sh --verify; setup.sh passes the values below.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for required in SSH_KEY_FILE GPG_FINGERPRINT FNM_DIR; do
  if [[ -z "${!required+x}" ]]; then
    echo "ERROR: $required is not set. Run verification via ./setup.sh --verify from the config-v2 checkout." >&2
    exit 2
  fi
done

checks=0; failed=0; failed_stages=()
pass() { checks=$((checks + 1)); echo "INFO: [$1] OK: $2"; }
fail() {
  checks=$((checks + 1)); failed=$((failed + 1))
  [[ " ${failed_stages[*]-} " == *" $1 "* ]] || failed_stages+=("$1")
  echo "ERROR: [$1] $2" >&2
}
warn() { echo "WARN: [$1] $2"; }

# [packages] manifest entries installed, key commands on PATH
while IFS= read -r line || [[ -n "$line" ]]; do
  pkg="${line%%#*}"; pkg="${pkg//[[:space:]]/}"
  [[ -n "$pkg" ]] || continue
  if pacman -Q "$pkg" >/dev/null 2>&1; then pass packages "package $pkg installed"
  else fail packages "Package '$pkg' from packages/arch.txt is not installed. Rerun ./setup.sh or run: sudo pacman -S --needed $pkg"; fi
done < "$REPO_ROOT/packages/arch.txt"
for cmd in chezmoi git zsh nvim tmux starship zoxide fzf docker dotnet; do
  if command -v "$cmd" >/dev/null 2>&1; then pass packages "command $cmd on PATH"
  else fail packages "Command '$cmd' is not on PATH. Check packages/arch.txt and rerun ./setup.sh."; fi
done

# [stateful] fnm, SSH key, login shell; GPG warn-only
...  # see "Check catalog"

# [dotfiles] [shell] [editor]
...

if (( failed > 0 )); then
  echo "ERROR: Verification failed: $failed of $checks checks failed (stages: ${failed_stages[*]})." >&2
  exit 1
fi
echo "INFO: Verification passed ($checks checks)."
```

The skeleton is binding for structure and names; complete the elided sections from the catalog.

### Check catalog (messages are part of the contract; tests match the bold fragments)

| Stage | Check | Command (read-only) | Failure line (after `ERROR: [stage] `) |
| --- | --- | --- | --- |
| packages | each `arch.txt` entry (blank/`#` lines skipped) | `pacman -Q "$pkg"` | **`Package '<pkg>' from packages/arch.txt is not installed`**. Rerun ./setup.sh or run: sudo pacman -S --needed <pkg> |
| packages | key commands | `command -v` for `chezmoi git zsh nvim tmux starship zoxide fzf docker dotnet` | **`Command '<cmd>' is not on PATH`**. Check packages/arch.txt and rerun ./setup.sh. |
| stateful | fnm | `[[ -x "$FNM_DIR/fnm" ]]` | **`fnm is not installed at <FNM_DIR>`**. Rerun ./setup.sh (it installs fnm when missing). |
| stateful | SSH key | `[[ -f "$SSH_KEY_FILE" ]]`; else if `.pub` exists → orphan | orphan: **`Found <file>.pub without its private key`**. Restore the private key or remove the .pub file, then rerun ./setup.sh. / missing: **`SSH key <file> is missing`**. Rerun ./setup.sh to generate it. |
| stateful | login shell | `basename "$(getent passwd "$(id -un)" \| cut -d: -f7)"` == `zsh` | **`Login shell for <user> is <shell>, not zsh`**. Run: sudo chsh -s "$(command -v zsh)" <user>, then start a new login session. |
| stateful | GPG (WARN) | `gpg --list-keys "$GPG_FINGERPRINT"` (skip if empty) | `WARN: [stateful] GPG key <fpr> is not in your keyring; commit signing will fail until you import it.` Never counts as failed. |
| dotfiles | source dir | `chezmoi source-path` == `$REPO_ROOT/dotfiles` | **`chezmoi source is <got>, expected <REPO_ROOT>/dotfiles`**. Rerun ./setup.sh from this checkout. |
| dotfiles | no drift | `chezmoi verify` exit 0 | **`Managed dotfiles differ from dotfiles/ (chezmoi verify)`**. Inspect with chezmoi diff, then rerun ./setup.sh. |
| dotfiles | targets exist | each line of `chezmoi managed --include=files --path-style absolute` is a file (`-f`) | **`Managed file <path> is missing`**. Rerun ./setup.sh. |
| shell | zsh entrypoint | `[[ -f "$HOME/.zshrc" ]] && zsh -n "$HOME/.zshrc"` | **`~/.zshrc is missing or has a zsh syntax error`**: <first error line>. Rerun ./setup.sh to restore the managed version. |
| editor | nvim entrypoint | `out="$(nvim --headless -i NONE -c 'lua io.write(vim.env.MYVIMRC or "")' -c 'qa!' 2>&1)"`; pass iff exit 0 and `out` == `${XDG_CONFIG_HOME:-$HOME/.config}/nvim/init.lua` | **`Neovim did not load <expected init.lua>`**: <out or "no config loaded">. Rerun ./setup.sh to restore the managed config. |

Notes:
- `nvim -i NONE` disables shada, so verification writes no `~/.local/state/nvim/shada`. Confirm in the instance that `io.write` reaches stdout in `--headless` mode. If not, use `-c 'lua io.stdout:write(...)'`. Any Lua error in `init.lua` adds text to `out` and therefore fails the check.
- `chezmoi verify` already fails when a target is missing; the per-file check exists to *name* the missing file (AC2 "which part"). Both failing for one deleted file is expected.
- `--path-style absolute` is supported by chezmoi v2.73 `managed`. If it is rejected, fall back to `"$HOME/$line"`.
- Literal managed paths (`~/.zshrc`, nvim `init.lua`) are fine in `verify-setup.sh`. The AD-5 forbid applies to `setup.sh` only.
- Do not use `set -e` in `verify-setup.sh`: a failing check must not abort the run.

### Architecture Compliance (MUST FOLLOW)

| Rule | Requirement for this story |
| --- | --- |
| AD-2 | `setup.sh` only sequences; the check logic lives in `tests/verify-setup.sh` (spine convention: "verification in repo-local test scripts"). |
| AD-3 | `verify-setup.sh` resolves `packages/arch.txt` and `dotfiles/` from its own location (`tests/..`), never from the caller's cwd. `setup.sh` requires `tests/verify-setup.sh` in preflight. |
| AD-5 | Verification writes no managed or stateful path. |
| AD-6 | Verification is the final stage, checks toolchain + managed files + shell/editor entrypoints, belongs to the repo. |
| AD-7 | `--verify` keeps the Arch-only guard. |
| AD-8 | No new configuration keys. `SSH_KEY_FILE` and `GPG_FINGERPRINT` come from the `setup.sh` block via `env`. `FNM_DIR`/`TARGET_USER`/`VERIFY_ONLY` are derived values. `verify-setup.sh` declares no defaults for them. |
| AD-9 | Order: preflight → packages → stateful → chezmoi apply → verification. |
| NFR3 | No prompts; verification needs no sudo. |
| NFR7 | Setup success = verification passed, not exit-0 of earlier stages. |

### Test harness changes (`tests/validate-setup.ps1`)

New variables: `$fakeToolDir = '/opt/config-v2-fake-tools'`, `$pacmanDb = '/var/tmp/config-v2-pacman-db.txt'`, `$fakeTools = @('docker', 'dotnet', 'starship', 'tmux', 'zoxide', 'fzf')`. `$shimPath = "${shimDir}:${fakeToolDir}:$basePath"` (scenario G's `$basePath` stays shim-free).

Shims (inside `$shimSetup`, PowerShell here-string escaping as today):
- **pacman** — keep logging and the stdin capture, and add:
  - `-S … -`: after capturing stdin, append its non-blank, non-`#` lines to `$pacmanDb`.
  - `-Q <pkg…>`: for each name, print `<pkg> 0-fixture` if `grep -qx` finds it in `$pacmanDb`, else print `error: package '<pkg>' was not found` to stderr. Exit 1 if any name was missing.
- **chsh** (called as `chsh -s <shell> <user>` through the sudo shim, i.e. as `tester`): log as today, then really set the field so verification sees the change:

```bash
awk -F: -v OFS=: -v u="$3" -v s="$2" '$1==u{$7=s}1' /etc/passwd > /tmp/config-v2-passwd.$$ && cat /tmp/config-v2-passwd.$$ > /etc/passwd; rm -f /tmp/config-v2-passwd.$$
```

  This requires `/etc/passwd` to be mode `0666` **in the disposable instance only** (decision 2026-11-05). `cat >` keeps the inode and mode.

`Reset-Fixture` additions (before `$mutation`):
- `chmod 0666 /etc/passwd` (after `useradd`; shadow tools may rewrite the file).
- `rm -f $pacmanDb && install -m 0666 /dev/null $pacmanDb`
- `rm -rf $fakeToolDir && mkdir -p $fakeToolDir` and, for each fake tool, `printf '#!/bin/sh\nexit 0\n' > $fakeToolDir/<t> && chmod 0755 …`. These are recreated per scenario, because N deletes one.
- `mkdir -p $fixtureRoot/tests && cp "$src/tests/verify-setup.sh" $fixtureRoot/tests/` (before `chown -R`).

`Invoke-Setup` gets an optional `[string]$arguments = ''` appended after `$fixtureRoot/setup.sh`.

### Static checks

`setup.sh` required patterns:
- `'verify-only usage error'` → `Usage: \./setup\.sh \[--verify\]`
- `'smoke verification invocation'` → `bash "\$\(require_repo_asset_path "tests/verify-setup\.sh"\)"`
- `'verification script preflight check'` → `require_repo_asset_path "tests/verify-setup\.sh" >/dev/null`

Order check: the last index of `run_smoke_verification` must be greater than the index of `chezmoi init --apply` and smaller than the index of `INFO: Bootstrap complete.`; the argument check (`Usage: ./setup.sh`) must come before `Do not run setup.sh as root`.

`tests/verify-setup.sh`:
- It exists, and its raw bytes contain no `\r` (LF only, `.gitattributes`).
- Required patterns: `pacman -Q`, `chezmoi verify`, `chezmoi source-path`, `chezmoi managed --include=files`, `zsh -n`, `nvim --headless`, `getent passwd`, and each tag `[packages]` `[stateful]` `[dotfiles]` `[shell]` `[editor]` (checked as literal strings `packages`, … in `pass`/`fail` calls; simplest: require `fail packages`, `fail stateful`, `fail dotfiles`, `fail shell`, `fail editor`).
- Forbidden on non-comment lines (`(?m)^(?!\s*#)[^\n]*…`): `\bsudo\b`, `pacman -(S|R|U)`, `chezmoi (apply|init|update|add|re-add)\b`, `\b(curl|wget)\b`, `\b(chsh|usermod)\b`, `ssh-keygen`, `gpg --(import|gen-key|full-generate-key|quick-gen-key)`, `\bset -e\b`.
- `bash -n $fixtureRoot/tests/verify-setup.sh` in the instance (next to the existing `setup.sh` syntax check).

### Scenario changes

- **A (happy path):**
  - Exit 0; the output contains `Verification passed` before `Bootstrap complete` and no `ERROR:`.
  - The shim log has a non-sudo `pacman -Q <pkg>` line for every `arch.txt` entry.
  - No `sudo pacman -Q`; keep the "sudo only for pacman|chsh" loop.
  - `getent passwd tester` ends in `:/usr/bin/zsh` (the chsh shim really applied it).
  - The output contains `WARN: [stateful] GPG key` (fixture has no key; must not fail).
- **B (rerun):** add the output contains `Verification passed`, and `Login shell for tester is already zsh`, and no new `chsh` line (now assertable because A really changed it).
- **M (verify-only, on B's state, before C's reset):**
  1. Record the shim-log line count, the `sha256sum` of the five managed targets and `~/.ssh/id_rsa`, and `stat -c %Y ~/.config/chezmoi/chezmoi.toml`.
  2. `Invoke-Setup -arguments '--verify'`. Expect exit 0, `Verification passed`, `nothing was changed`, and no `Applying dotfiles` in the output.
  3. New shim-log lines only match `^pacman -Q ` (no `sudo`/`curl`/`fnm-installer`/`chsh`/`pacman -S`). Hashes and mtime are unchanged.
- **N (broken outcomes, on M's state):**
  1. As root: remove `tmux` from `$pacmanDb` and delete `$fakeToolDir/tmux`; run `usermod -s /bin/bash tester` and then `chmod 0666 /etc/passwd`.
  2. As tester: delete `~/.config/nvim/init.lua`, and append `if then` to `~/.zshrc`.
  3. `Invoke-Setup -arguments '--verify'`. Expect a non-zero exit, and the output contains each of:
     - `ERROR: [packages] Package 'tmux'`
     - `ERROR: [packages] Command 'tmux'`
     - `ERROR: [stateful] Login shell for tester is bash`
     - `ERROR: [dotfiles] Managed dotfiles differ`
     - `ERROR: [dotfiles] Managed file`
     - `ERROR: [shell]`
     - `ERROR: [editor]`
     - `Verification failed: `
     - `Smoke verification failed`
  4. No-fail-fast check: the failed count printed is at least 7.
  5. Read-only check: `init.lua` is still missing and the `if then` line is still in `~/.zshrc`. The new shim-log lines only match `^pacman -Q `.
- **L (orphaned public key):** the expectation flips from exit 0 to **non-zero**. Keep the existing `.pub` untouched / no private key / `without its private key` assertions, and add:
  - the output contains `ERROR: [stateful] Found` and `Smoke verification failed`
  - the output does not contain `Bootstrap complete`
  - `chezmoi verify` as tester exits 0, which proves apply ran before verification.
- **K:** unchanged assertions, plus the output contains `Verification passed`.
- **P (missing verification script):** `Reset-Fixture 'rm -f tests/verify-setup.sh'` → `Assert-FailedBeforeMutation 'P missing verify script' … 'Missing tests/verify-setup.sh relative to setup.sh'`.
- **Q (unknown argument):** `Assert-FailedBeforeMutation 'Q unknown argument' (Invoke-Setup -arguments '--bogus') 'Usage: ./setup.sh [--verify]'`.
- **R (direct invocation without setup.sh values):** as tester, `bash $fixtureRoot/tests/verify-setup.sh` exits 2 with `Run verification via ./setup.sh --verify`.

Order: A, B, M, N, C, D, E, F, G, P, Q, R, K, L, then H–J last (they fake `/etc/os-release`). Keep `Assert-FailedBeforeMutation`, `-KeepInstance`, and the `finally` cleanup.

### validate-readme.ps1 changes (UPDATE)

Add required checks:
- `'documented verify-only command'` → `[regex]::Escape('./setup.sh --verify')`
- `'smoke verification bootstrap step'` → `(?im)^\d+\.\s+.*smoke verification` (inside the numbered "What the Linux bootstrap does" list)

Keep everything else unchanged (the two-repo check stays until Story 2.5 replaces it).

### README.md (UPDATE, minimal)

In "What the Linux bootstrap does", append step `5. runs the smoke verification in tests/verify-setup.sh (packages, stateful assets, managed dotfiles, zsh and Neovim entrypoints) and exits non-zero with an ERROR: [stage] line for each broken part`. Then add the sentence: "Run `./setup.sh --verify` at any time to re-check an existing machine without changing anything." Do not edit step 4's wording, "Architecture Overview", or "Path Ownership" (Story 2.5). Verification touches no path, so it adds no Path Ownership row.

### File Structure Requirements

| Path | Action |
| --- | --- |
| `tests/verify-setup.sh` | NEW |
| `setup.sh` | UPDATE (args, preflight asset, derived values moved, stage 5) |
| `tests/validate-setup.ps1` | UPDATE |
| `tests/validate-readme.ps1` | UPDATE |
| `README.md` | UPDATE (step 5 + `--verify` sentence) |
| `.gitattributes` | UPDATE (`tests/*.sh text eol=lf`) |
| `_bmad-output/implementation-artifacts/2-4-…md`, `sprint-status.yaml` | status/record updates only |
| `dotfiles/**`, `packages/arch.txt`, `tests/lib/WslTestInstance.ps1`, `tests/validate-dotfiles.ps1`, `tests/validate-wsl-test-ca.ps1`, planning artifacts | DO NOT MODIFY |

### Testing Requirements

Run under **Windows PowerShell**, sequentially (they share the `config-v2-test` instance name):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\validate-setup.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests\validate-dotfiles.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests\validate-readme.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests\validate-wsl-test-ca.ps1
```

- Never touch other WSL distros (currently `archlinux`), not even read-only. List `wsl -l -q` before/after.
- Expect ~5–6 min for `validate-setup.ps1` (neovim in the instance, five more scenarios).
- Mutated copies must stay valid bash (Story 2.6 lesson). Run `bash -n` inside `config-v2-test` (`-KeepInstance`) or rely on the validator's own `bash -n`.
- Mutation check (d) from Story 2.3 was first missed because of a regex/comment interaction. For each mutation here, run the full validator end-to-end and record the red line in the Debug Log.

### Previous Story Intelligence

- **Story 2.3:** the shim log is the mutation oracle. The `chsh` shim currently cannot change the shell, so B could not assert the chsh skip; this story's real `/etc/passwd` edit enables that. Scenario K seeds `usermod -s /usr/bin/zsh`. Scenario L (orphan `.pub`) currently expects exit 0 and must flip. The 2.3 review deferred "fnm not verified afterwards" and "K seeds no ~/.gnupg"; this story covers the first only at detection level.
- **Story 2.6:** H–J must stay last. The forbid list scans the whole `setup.sh`, comments included, for Ubuntu/apt words.
- **Story 2.2:** use `setpriv` (not `runuser`); use `sha256sum` (not `cmp`); the Arch image lacks `sudo` (scenario G relies on it); the identity keys pass through one `env …` line.
- **Story 2.1:** `nvim/init.lua` is plugin-free, so a headless load needs no network. `dot_zshrc` clones zinit only when sourced interactively, so `zsh -n` stays offline.

### Git Intelligence

- `91ec6cf feat: narrow bootstrap to Arch Linux only (Story 2.6)` and the Story 2.3 work form the current `setup.sh`/validator baseline. `c9b569e` made expected-failure stderr capturable under Windows PowerShell 5.1.
- Commit convention: `feat: add smoke verification stage (Story 2.4)` with the `Co-authored-by` trailer.

### Latest Technical Information

- **chezmoi v2.73** (instance): `verify` exits 1 on any drift and 0 otherwise. `managed --include=files --path-style absolute` lists absolute targets. `source-path` prints the configured `sourceDir`. All three are read-only.
- **pacman**: `pacman -Q <name>` exits 1 with `error: package '<name>' was not found` for a missing package; it is a read-only local db query that needs no root.
- **Neovim 0.10+/0.11**: `--headless` with `-c 'qa!'` exits 0. `$MYVIMRC` is set to the loaded user init file. `-i NONE` disables shada.
- **zsh**: `zsh -n file` parses without executing (no zinit clone, no network).

### Project Structure Notes

- No `project-context.md`. Authoritative context: `epics.md` (Story 2.4), the 2026-08-07 spine (AD-6, AD-9, consistency table "verification in repo-local test scripts"), readiness report 2026-10-07 (Major #7, FR1 login-shell and runtime notes, UX console-message note), SPEC success signal, Stories 2.1/2.2/2.3/2.6, and the current code.
- `tests/` now holds one Linux-side script (`verify-setup.sh`) next to the Windows-side validators. This matches the spine source tree ("tests/ — smoke verification for the supported setup flow").

### References

- [epics.md: Story 2.4](../planning-artifacts/epics.md)
- [ARCHITECTURE-SPINE.md (2026-08-07): AD-2, AD-3, AD-5, AD-6, AD-8, AD-9](../planning-artifacts/architecture/architecture-config-v2-dotfiles-integration-2026-08-07/ARCHITECTURE-SPINE.md)
- [implementation-readiness-report-2026-10-07.md: Major #7; FR1 sub-requirements](../planning-artifacts/implementation-readiness-report-2026-10-07.md)
- [SPEC.md: Success signal](../specs/spec-dev-env-config-repo/SPEC.md)
- [2-3-preserve-stateful-asset-safety-in-the-integrated-flow.md](./2-3-preserve-stateful-asset-safety-in-the-integrated-flow.md), [2-6-narrow-the-bootstrap-to-arch-linux-only.md](./2-6-narrow-the-bootstrap-to-arch-linux-only.md), [deferred-work.md](./deferred-work.md)
- [setup.sh](../../setup.sh), [tests/validate-setup.ps1](../../tests/validate-setup.ps1), [tests/validate-readme.ps1](../../tests/validate-readme.ps1), [README.md](../../README.md), [dotfiles/dot_zshrc](../../dotfiles/dot_zshrc), [dotfiles/dot_config/nvim/init.lua](../../dotfiles/dot_config/nvim/init.lua), [packages/arch.txt](../../packages/arch.txt)

## Dev Agent Record

### Agent Model Used

AI assistant (Copilot SDK in VS Code), bmad-dev-story workflow

### Debug Log References

- Red phase `tests/validate-setup.ps1` (current tree, before implementation): red on all 5 new `setup.sh` static checks, `verify-setup.sh` missing and `bash -n`, A (no `Verification passed`, no GPG WARN, no `pacman -Q` per manifest entry), B (`Verification passed`), M (full bootstrap ran, mutated state), N (all expected `ERROR: [stage]` lines, count, read-only), P, Q, R (exit 127), K (`Verification passed`), L (exit 0, no `ERROR: [stateful] Found`, `Bootstrap complete` printed). B's "chsh ran once" was already green, which confirms the new `/etc/passwd`-editing chsh shim.
- Red phase `tests/validate-readme.ps1`: `documented verify-only command`, `smoke verification bootstrap step`.
- Instance probe: `nvim --headless -i NONE -c 'lua io.stdout:write(vim.env.MYVIMRC or "")' -c 'qa!'` prints exactly `~/.config/nvim/init.lua` with exit 0. With an `error("boom")` init.lua the E5113 text is added to the output, so the check fails. Nvim writes only `~/.local/state/nvim/nvim.log` (no shada). `io.stdout:write` is used, which the story allows as the fallback.
- Green: `validate-setup.ps1` passed on the first full run. Final regression: setup, dotfiles, readme and wsl-test-ca validators all passed (Windows PowerShell, sequential). `wsl -l -q` before and after shows only `archlinux` (untouched); `config-v2-test` was removed.
- Mutation checks, each run end-to-end on a temporary mutation of the working tree with originals restored byte-for-byte; every one went red:
  - (a) verify always exits 0 → `[N] setup.sh --verify exited 0 on a broken machine`, plus L.
  - (b) `exit 1` in `fail` → `[N] … at least 7 failed checks (stopped early?)` and missing later stage lines.
  - (c) `setup.sh` ignores non-zero verification (the `exit 1` in `run_smoke_verification` removed) → `[N] … exited 0`, `[L] … reported 'Bootstrap complete'`. A first attempt (`… || true; then`) was an invalid mutation: it bound to the `if !` condition and made verification always fail. It was redone.
  - (d) call moved before `chezmoi init --apply` → static order check, A/K exit 1, `[L] dotfiles were not applied before verification ran`.
  - (e) `chezmoi apply --force` in verify → static `read-only but contains chezmoi mutation`, `[N] verification restored ~/.config/nvim/init.lua`.
  - (f) login shell check removed → static `missing 'getent passwd'`, `[N] … Login shell for tester is bash`.
  - (g) orphan `.pub` passes → `[L] setup.sh exited 0 …`, no `ERROR: [stateful] Found`.
  - (h) GPG miss is a FAIL → A and K exit 1.
  - (i) CRLF → static `contains CR characters`, `bash -n` failure.
  - (j) README without `./setup.sh --verify` → `Missing README requirement: documented verify-only command`.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- `tests/verify-setup.sh` (new) follows the binding skeleton and check catalog:
  - read-only; uses `set -uo pipefail` without `set -e`
  - stages `[packages] [stateful] [dotfiles] [shell] [editor]`
  - every failure prints `ERROR: [stage] <what>. <fix>`; all checks run, with a final passed/failed summary
  - a missing GPG key is WARN only
  - exits 2 with a `./setup.sh --verify` hint when run directly without the `setup.sh` values
  - `chezmoi managed --path-style absolute` worked on the instance chezmoi, so no fallback was needed
- `setup.sh`:
  - `--verify` parsing before the root check (`Usage: ./setup.sh [--verify]`)
  - preflight asset check for `tests/verify-setup.sh`
  - `TARGET_USER`/`FNM_DIR` moved before the verify-only branch
  - `run_smoke_verification` (`env SSH_KEY_FILE GPG_FINGERPRINT FNM_DIR bash <path>`) as stage (5) after `chezmoi init --apply`; `INFO: Bootstrap complete.` only after it passes
  - `--verify` runs the full preflight, then verification only, and prints `Verification complete; nothing was changed.`
- `tests/validate-setup.ps1`:
  - neovim added to the instance; faked toolchain (`/opt/config-v2-fake-tools`)
  - pacman shim with a `-Q` db; chsh shim that really edits `/etc/passwd` (mode 0666 in the disposable instance only)
  - fixture copies `tests/verify-setup.sh`; `Invoke-Setup -arguments`
  - new static checks for both scripts
  - scenarios A/B/K/L extended (L now expects a non-zero exit), M/N/P/Q/R added; order A, B, M, N, C–G, P, Q, R, K, L, H–J
- Decision: the read-only forbid list for `verify-setup.sh` scans commands only. Comment lines and the double-quoted message of `pass`/`fail`/`warn`/`echo` are stripped first. Without this, the catalog's own fix hints (`sudo pacman -S --needed <pkg>`, `sudo chsh -s …`) would trip the `sudo`/`pacman -S`/`chsh` forbids. Mutation (e) confirms a real command is still caught.
- README: step 5 and the `./setup.sh --verify` sentence only (step 4, Architecture Overview and Path Ownership untouched). `validate-readme.ps1` requires both. `.gitattributes` adds `tests/*.sh text eol=lf`.
- Scope guard: `git status` shows only the files below. `dotfiles/**`, `packages/arch.txt`, `tests/lib/WslTestInstance.ps1`, `tests/validate-dotfiles.ps1` and `tests/validate-wsl-test-ca.ps1` are unchanged.

### File List

- `tests/verify-setup.sh` (new)
- `setup.sh` (modified)
- `tests/validate-setup.ps1` (modified)
- `tests/validate-readme.ps1` (modified)
- `README.md` (modified)
- `.gitattributes` (modified)
- `_bmad-output/implementation-artifacts/2-4-add-smoke-verification-for-integrated-bootstrap.md` (modified: status/record)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified: status)

## Change Log

- 2026-11-06: Added the repo-local smoke verification stage. Added `tests/verify-setup.sh`, `setup.sh` stage (5) and `--verify`, validator scenarios M/N/P/Q/R, and the README step 5 and `--verify` docs. Status → review.