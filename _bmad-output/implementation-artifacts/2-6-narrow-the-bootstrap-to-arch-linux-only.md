---
baseline_commit: caeec503728d21671a8c8a6f4e8ddd96e439fb27
---

# Story 2.6: Narrow the Bootstrap to Arch Linux Only

Status: done
> **Added by correct-course 2026-10-29 (Arch Linux only).** Implement next, before Story 2.3. Planning artifacts (SPEC, stack.md, architecture spine AD-7, epics, Story 3.1 file, deferred-work, sprint-status) were already updated by the correct-course commit `caeec50`. This story is the **code** half: delete Windows/Ubuntu files, add the Arch-only guard to `setup.sh`, retarget the validators, and make minimal README edits.

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As the maintainer of config-v2,
I want the repository to contain only the Arch Linux bootstrap path,
so that every tracked script and validator matches the supported scope and nothing untested ships.

## Acceptance Criteria

1. **Given** the repository, **When** I list tracked files, **Then** `setup.ps1`, `packages/scoop.txt`, `packages/winget.txt`, `packages/ubuntu.txt`, and `tests/validate-setup-ps1.ps1` no longer exist **And** `tests/lib/WslTestInstance.ps1` (the Windows-hosted WSL Arch test harness) is kept.
2. **Given** `setup.sh`, **When** I run it on a host whose `/etc/os-release` `ID` is not `arch`, **Then** it exits non-zero during preflight with an actionable "only Arch Linux is supported" error **And** no package, file, or key mutation happens before that exit (AD-7, AD-9, NFR2) **And** `setup.sh` contains no apt, dpkg, or Ubuntu repository logic.
3. **Given** `tests/validate-setup.ps1` and `tests/validate-readme.ps1`, **When** the Ubuntu and Windows assertions are removed, **Then** they assert the Arch-only guard and the absence of Ubuntu/Windows paths instead **And** `README.md` no longer has a Windows Companion Bootstrap section or a `packages/ubuntu.txt` reference (the full in-repo dotfiles README rewrite stays in Story 2.5).
4. **Given** the Windows PowerShell validation commands, **When** I run `validate-setup.ps1`, `validate-dotfiles.ps1`, `validate-readme.ps1`, and `validate-wsl-test-ca.ps1`, **Then** all pass.

## Tasks / Subtasks

- [x] Task 1: Delete Windows and Ubuntu files (AC: 1)
  - [x] `git rm setup.ps1 packages/scoop.txt packages/winget.txt packages/ubuntu.txt tests/validate-setup-ps1.ps1`
  - [x] Do **not** touch `tests/lib/WslTestInstance.ps1`, `tests/certs/`, `tests/validate-wsl-test-ca.ps1`, `tests/validate-dotfiles.ps1`, or `.gitattributes` (no Windows-specific entries exist there).
- [x] Task 2: Red phase — update validators first, confirm they fail against the current `setup.sh`/README (AC: 2, 3)
  - [x] `tests/validate-setup.ps1`: apply every change in "validate-setup.ps1 changes" below.
  - [x] `tests/validate-readme.ps1`: apply every change in "validate-readme.ps1 changes" below.
  - [x] Run both; record in the Debug Log that the static checks and scenarios H/I/J go red against the old code.
- [x] Task 3: Rewrite the distro handling in `setup.sh` (AC: 2)
  - [x] Replace the `. /etc/os-release` + `case` + `if/elif/else` block with the Arch-only guard in preflight and a single pacman install stage (see "Target `setup.sh` shape").
  - [x] Remove every apt/dpkg/lsb_release/Docker/Microsoft repo line and every `ubuntu` mention, including the `(both distros)` fnm comment and `$DISTRO` in the chezmoi-missing message.
  - [x] `bash -n setup.sh` passes (the validator runs it in the instance).
- [x] Task 4: Minimal README edits (AC: 3)
  - [x] Apply exactly the edits in "README.md (minimal edits)". Nothing else; Story 2.5 owns the rewrite.
- [x] Task 5: Green phase + mutation checks (AC: 2, 3, 4)
  - [x] Run all four validators under Windows PowerShell (commands in Testing Requirements). All pass.
  - [x] Mutation checks on a temp copy (each must go red, then revert): (a) re-add an `ubuntu)` branch → static; (b) move the guard after `sudo pacman` → static order check + scenario H shim log; (c) accept `ID_LIKE=arch` → scenario I; (d) drop the `-r /etc/os-release` check → scenario J (bash error, no actionable message); (e) re-create `packages/ubuntu.txt` → static absence check; (f) re-add a `## Windows Companion Bootstrap` heading to README → readme validator.
- [x] Task 6: Scope guard
  - [x] `git status` shows only the files in the File Structure table. No planning artifact edits are needed beyond this story file and `sprint-status.yaml` status changes.

### Review Findings

- [x] [Review][Patch] Make the `/etc/os-release` fake/restore crash-safe: call `Set-FakeOsRelease` inside the `try` so a partial swap is always restored, and refuse to swap when `/etc/os-release.config-v2-orig` already exists (a leftover from an interrupted run would otherwise be overwritten by the fake) [tests/validate-setup.ps1:187]
- [x] [Review][Patch] A malformed `/etc/os-release` (e.g. unquoted value with spaces as its last line) makes the `$(. /etc/os-release && printf ...)` substitution fail, so `set -e` exits with a raw shell error instead of the actionable Arch-only message; fall back to an empty `DISTRO` on sourcing failure [setup.sh:36]
- [x] [Review][Patch] Restore the `# shellcheck source=/dev/null` directive removed above the `/etc/os-release` source line [setup.sh:36]
- [x] [Review][Patch] README forbid only matches the literal `.\setup.ps1`; broaden to any `setup.ps1` mention (`./setup.ps1`, `pwsh -File setup.ps1`) [tests/validate-readme.ps1:69]
- [x] [Review][Patch] Drop the stale `# implement next, before 2-3` comment on the 2-6 entry [_bmad-output/implementation-artifacts/sprint-status.yaml:62]
- [x] [Review][Defer] Guard-order static check keys on the first occurrence of the message text `only Arch Linux is supported`, not the `if [[ "$DISTRO" != "arch" ]]` guard itself; a comment with that text above `sudo pacman` would mask a moved guard [tests/validate-setup.ps1:93] — deferred, spec-defined check, low risk
- [x] [Review][Defer] No scenario covers a quoted `ID="arch"` (accepted) or an os-release with no `ID` line (refused as `unknown`) [tests/validate-setup.ps1:450] — deferred, coverage gap, behaviour correct by inspection

## Dev Notes

### Scope Boundaries (read first)

| In this story | NOT in this story (owner) |
| --- | --- |
| Delete `setup.ps1`, `packages/{scoop,winget,ubuntu}.txt`, `tests/validate-setup-ps1.ps1` | SPEC / stack.md / spine / epics / Story 3.1 file / deferred-work edits (already done in `caeec50`) |
| Arch-only guard in `setup.sh` preflight; remove Ubuntu branch | fnm `--skip-shell`, SSH/GPG rerun hardening, stateful vs managed classification (Story 2.3) |
| Retarget `validate-setup.ps1` / `validate-readme.ps1` to Arch-only | Smoke verification stage, AD-9 step (6) (Story 2.4) |
| Minimal README edits (intro line, manifest sentence, "what it does" step 2, delete Windows section) | Full README rewrite, two-repo wording, "Linux Quick Start" heading, `sudo` in the pacman prerequisite snippet, "deferred" wording for Windows/other distros (Story 2.5) |
| | Open deferred items: `sudo -v` rights check, `require_repo_asset_path` accepting directories, arch.txt comment filtering (`deferred-work.md`; leave alone) |

### Current `setup.sh` (UPDATE) — what changes, what stays

- **Today (lines 37–88):** section `(2)` sources `/etc/os-release` **into the script's own shell** (`. /etc/os-release`), sets `DISTRO="${ID:-}"`, then `case` requires `packages/arch.txt` or `packages/ubuntu.txt`. Section `(3)` has `if arch → sudo pacman` / `elif ubuntu → apt-get, Docker + Microsoft GPG keys and repos, sudo xargs apt-get install` / `else → "Unsupported distro … Supported distros: arch, ubuntu."`. If `/etc/os-release` is missing, `set -e` aborts with a raw bash error (not actionable). Sourcing into the main shell also lets os-release fields (`NAME`, `VERSION`, …) clobber script variables.
- **Already mutation-free before packages:** the unsupported-distro exit today happens before any mutation too, but only by accident of ordering at step (3). This story makes it an explicit preflight guard.
- **Preserve exactly:** shebang, `set -euo pipefail`; `REPO_ROOT` line (validator regex); config block keys/values and their **single** line-start assignment each (validators parse `KEY=` lines; a second `KEY=` line silently disables leak checks — see Story 2.2 Debug Log); `require_repo_asset_path` helper and its exact message (validate-readme regex); root and sudo preflight checks and their messages; `.git` and `dotfiles/.chezmoi.toml.tmpl` preflight; the exact line `sudo pacman -S --needed --noconfirm - < "$(require_repo_asset_path "packages/arch.txt")"` (both validators match it); the `INFO: Detected Arch Linux — installing packages via pacman.` line; chezmoi-missing check; fnm curl install; SSH/GPG blocks and messages; legacy chezmoi notice; the `env GIT_USER_NAME=… chezmoi init --apply --force --no-tty --source "$(require_repo_asset_path "dotfiles")"` line; `INFO:`/`ERROR:` prefixes with `ERROR:` on stderr.

### Target `setup.sh` shape (sections 1–3 only; everything after the chezmoi-missing check is unchanged except one comment)

```bash
# --- (1) Preflight: target user, sudo, Arch-only guard, local checkout (AD-3, AD-7, AD-9). No mutation before this passes. ---
if [[ "$EUID" -eq 0 ]]; then ...unchanged... fi
if ! command -v sudo >/dev/null 2>&1; then ...unchanged... fi

# Read ID in a subshell so os-release fields cannot overwrite script variables (AD-7).
DISTRO=""
if [[ -r /etc/os-release ]]; then
  DISTRO="$(. /etc/os-release && printf '%s' "${ID:-}")"
fi
if [[ "$DISTRO" != "arch" ]]; then
  echo "ERROR: Unsupported distro '${DISTRO:-unknown}': only Arch Linux is supported (/etc/os-release must have ID=arch). Run ./setup.sh on an Arch Linux machine (WSL or VM)." >&2
  exit 1
fi

# chezmoi would git-init dotfiles/ if the checkout were not a git working tree.
require_repo_asset_path ".git" >/dev/null
require_repo_asset_path "dotfiles/.chezmoi.toml.tmpl" >/dev/null
require_repo_asset_path "packages/arch.txt" >/dev/null

# --- (2) Install packages via pacman; only system commands run through sudo (AD-7) ---
echo "INFO: Detected Arch Linux — installing packages via pacman."
sudo pacman -S --needed --noconfirm - < "$(require_repo_asset_path "packages/arch.txt")"

if ! command -v chezmoi >/dev/null 2>&1; then
  echo "ERROR: chezmoi is not installed after the package stage. Check packages/arch.txt and the pacman output." >&2
  exit 1
fi

# --- (3) User-level installs and stateful assets ... (renumber following sections (3), (4))
# fnm via the official curl installer
```

Rules:
- **Exact phrase** `only Arch Linux is supported` must appear in the error (validators match it). Keep the message on one line.
- **`ID` only, never `ID_LIKE`.** Derivatives (`ID=endeavouros`, `ID=manjaro` with `ID_LIKE=arch`) are refused. AD-7: "`ID=arch` is the only supported value … Adding a distro later requires a new architecture decision."
- **Guard order:** root → sudo → Arch guard → `.git` → dotfiles template → `packages/arch.txt`. The guard must come before every `sudo`/`pacman`/`curl`/`ssh-keygen`/`chezmoi` call.
- `$(. /etc/os-release && …)` runs in a subshell; `set -u` is inherited, so keep `${ID:-}`. Do not `source` os-release in the main shell anymore.
- Do **not** add a configurable os-release path or env override for tests (AD-8: no undeclared config keys). Tests fake `/etc/os-release` inside the disposable instance instead.
- Renumber the section comments so they stay sequential; keep the AD references. Section numbers are not asserted by any validator.

### Architecture Compliance (MUST FOLLOW)

| Rule | Requirement for this story |
| --- | --- |
| AD-2 | `setup.sh` stays an orchestrator; only `packages/arch.txt` feeds pacman. |
| AD-3 | Manifest resolved via `require_repo_asset_path` from `REPO_ROOT`; no `./packages/`. |
| AD-7 (rewritten 2026-10-29) | Read `/etc/os-release` once during preflight; `ID=arch` only; any other value exits with an actionable error before any mutation; packages solely from `packages/arch.txt` via pacman. |
| AD-8 | No new config keys. Canonical keys unchanged. |
| AD-9 | Order: config + root → distro guard → packages → stateful assets → chezmoi apply (→ verification in 2.4). Guard is now part of preflight. |
| NFR2 | Arch Linux (WSL or VM) is the only supported target; refuse others before mutation. |
| NFR3 | No new prompts. |

### validate-setup.ps1 changes (UPDATE)

Current file: static checks (lines 27–94), then WSL scenarios A–G (lines 233–312). Changes:

1. **Remove** the `'Ubuntu manifest install via sudo from repo root'` entry from `$requiredSetupPatterns` (line 73) and the whole "Ubuntu branch … must use sudo" block (lines 81–94).
2. **Add repo absence/presence checks** (static, against `$repoRoot` working tree, independent of `$setupContent`):
   - must NOT exist: `setup.ps1`, `packages/scoop.txt`, `packages/winget.txt`, `packages/ubuntu.txt`, `tests/validate-setup-ps1.ps1` → failure `"<path> must not exist (Arch-only scope, AD-7)."`
   - must exist: `tests/lib/WslTestInstance.ps1`, `packages/arch.txt`.
3. **Add to `$forbiddenSetupPatterns`** (setup.sh content):
   - `(?i)ubuntu` — Ubuntu reference (AD-7)
   - `\bapt(-get|-key)?\b` — apt logic
   - `\bdpkg\b`, `\blsb_release\b`
   - `download\.docker\.com|packages\.microsoft\.com` — third-party apt repos
   - `(?i)\bID_LIKE\b` — derivatives must not be accepted
4. **Add to `$requiredSetupPatterns`:** `'Arch-only guard message'` → `only Arch Linux is supported`.
5. **Add a static order check:** the index of `only Arch Linux is supported` in `$setupContent` must be lower than the index of the first `sudo pacman` and of `require_repo_asset_path ".git"`. Fail with `"setup.sh Arch-only guard must run in preflight before any package step."`
6. **Extend `Assert-FailedBeforeMutation`:** also fail if `$testHome/.ssh` exists (covers "no key mutation"; `useradd -m` on Arch does not create `~/.ssh` from `/etc/skel`). Existing scenarios C–G must stay green with this.
7. **Add scenarios H, I, J at the end** (after G), so a failed restore can never affect earlier scenarios. Use a helper pair and always restore in `finally`:

```powershell
# Swaps /etc/os-release (a symlink to ../usr/lib/os-release on Arch) for a fake; Restore-OsRelease undoes it.
function Set-FakeOsRelease([string]$content) {
    $bash = "mv /etc/os-release /etc/os-release.config-v2-orig && printf '%s' `"`$FAKE_OS_RELEASE`" > /etc/os-release && chmod 0644 /etc/os-release"
    if ([string]::IsNullOrEmpty($content)) { $bash = 'mv /etc/os-release /etc/os-release.config-v2-orig' }
    $result = Invoke-Instance $bash @{ FAKE_OS_RELEASE = $content }
    if ($result.ExitCode -ne 0) { throw "Faking /etc/os-release failed: $($result.Output)" }
}
function Restore-OsRelease {
    $result = Invoke-Instance 'if [ -e /etc/os-release.config-v2-orig ] || [ -L /etc/os-release.config-v2-orig ]; then rm -f /etc/os-release && mv /etc/os-release.config-v2-orig /etc/os-release; fi'
    if ($result.ExitCode -ne 0) { throw "Restoring /etc/os-release failed: $($result.Output)" }
}
```

   - **H, Ubuntu host refused:** `Reset-Fixture`; `Set-FakeOsRelease "NAME=`"Ubuntu`"`nID=ubuntu`nID_LIKE=debian`n"`; `Assert-FailedBeforeMutation 'H non-Arch refused' (Invoke-Setup) 'only Arch Linux is supported'`; also assert output contains `'ubuntu'` (the detected ID is echoed). `Restore-OsRelease` in `finally`.
   - **I, Arch derivative refused:** fake `ID=endeavouros`/`ID_LIKE=arch`; same assertion. Proves `ID_LIKE` is ignored.
   - **J, os-release missing:** `Set-FakeOsRelease ''` (moves it away, no replacement); expect `only Arch Linux is supported` and `'unknown'`.
   - After J, assert `Test-Instance 'grep -qx "ID=arch" /etc/os-release'` to prove restore worked.
   - Fake content travels via the env hashtable (single-quoted export in `Invoke-ConfigV2TestInstance`), so quotes and newlines are safe. Use LF (`` `n ``), not CRLF.

Keep everything else (scenarios A–G, shims, `-KeepInstance`, `finally { Remove-ConfigV2TestInstance }`). Scenario A still proves `ID=arch` passes the guard on the real Arch image.

### validate-readme.ps1 changes (UPDATE)

1. **Change** `'Local checkout requirement explanation'` pattern to `(?is)(setup\.sh.*?reads.*?packages/arch\.txt.*?same checkout.*?supported bootstrap path)` (drop the `packages/ubuntu\.txt` segment).
2. **Remove** required checks `'Windows companion section'`, `'Implemented Windows companion entry point'`, `'Exact Windows companion command'`.
3. **Remove** `'Ubuntu package manifest local checkout usage'` from `$requiredSetupPatterns`; **add** `'Arch-only guard'` → `only Arch Linux is supported`.
4. **Add README forbidden checks** (targeted, so Story 2.5 can still list Windows/other distros as *deferred*):
   - `(?im)^##\s+Windows Companion Bootstrap\s*$` — Windows section
   - `packages/ubuntu\.txt`, `packages/(scoop|winget)\.txt` — removed manifests
   - `[regex]::Escape('.\setup.ps1')` — removed Windows command
   - Do **not** forbid the bare words `Windows` or `Ubuntu` in README.
5. Keep `'Two-repo architecture explanation'`, `config.sh` and value-leak checks unchanged (Story 2.5 replaces two-repo assertions).

### README.md (minimal edits)

- Line 3 → `` `config-v2` is the bootstrap repository for bringing up an Arch Linux development machine (WSL or VM) from a local checkout. ``
- Line 24 → `` `setup.sh` reads `packages/arch.txt` from the same checkout. Running the script from the cloned repository is the supported bootstrap path. `` (must still match the updated validate-readme pattern).
- Line 31 (step 2) → `checks that the host is Arch Linux and installs packages from \`packages/arch.txt\` in this repository`
- Delete the whole `## Windows Companion Bootstrap` section (lines 43–51) and trailing blank line.
- Leave headings ("Linux Quick Start", "What the Linux bootstrap does", "Architecture Overview") and two-repo wording as they are (Story 2.5).

### File Structure Requirements

| Path | Action |
| --- | --- |
| `setup.ps1`, `packages/scoop.txt`, `packages/winget.txt`, `packages/ubuntu.txt`, `tests/validate-setup-ps1.ps1` | DELETE (`git rm`) |
| `setup.sh` | UPDATE (guard + single pacman stage; remove Ubuntu) |
| `tests/validate-setup.ps1` | UPDATE |
| `tests/validate-readme.ps1` | UPDATE |
| `README.md` | UPDATE (minimal) |
| `_bmad-output/implementation-artifacts/2-6-…md`, `sprint-status.yaml` | status updates only |
| `tests/lib/WslTestInstance.ps1`, `tests/validate-dotfiles.ps1`, `tests/validate-wsl-test-ca.ps1`, `tests/certs/*`, `dotfiles/**`, `packages/arch.txt`, `.gitattributes`, planning artifacts | DO NOT MODIFY |

Notes: `tests/validate-dotfiles.ps1` line 151 forbids `apt-get`/`apt` inside `run_` scripts — that is a guard, not Ubuntu support; keep it. `WslTestInstance.ps1` mentions "Windows" only as the test host — keep.

### Testing Requirements

Run under **Windows PowerShell** from the repo root (AC 4):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\validate-setup.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests\validate-dotfiles.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests\validate-readme.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests\validate-wsl-test-ca.ps1
```

- `validate-setup.ps1` and `validate-dotfiles.ps1` each create and destroy the disposable `config-v2-test` WSL instance (`-KeepInstance` on validate-setup to debug). Run them **sequentially**, never in parallel (same instance name). Never touch other WSL distros (`archlinux`, `MyArch`); list `wsl -l -q` before/after.
- Expect ~1–3 min per WSL validator with the cached image; Zscaler CA trust is already handled by the harness.
- Windows PowerShell 5.1 specifics already handled in the harness: expected-failure stderr is captured (commit `c9b569e`). Do not reintroduce `$ErrorActionPreference='Stop'` around `wsl.exe` calls.
- Match output with CRLF-tolerant regexes; `[regex]::Escape` literal messages.
- Mutation checks in Task 5 are required (2.1 and 2.2 both found real gaps this way).

### Previous Story Intelligence

- **Story 2.2 (done):** established preflight ordering, `require_repo_asset_path`, `sudo` only for system commands, `setpriv` (not `runuser`) for the test user, shim log as the "no mutation" oracle, `sha256sum` instead of `cmp`, base image lacks `sudo` (scenario G is meaningful). Debug Log: env-prefix `KEY=` lines break the shared config-block parser → keep identity keys passed via one `env …` line.
- **Story 3.1 (cancelled):** its only surviving output is the `WslTestInstance.ps1` stderr fix (`c9b569e`). Its Debug Log shows the full suite (including scenario C) green under Windows PowerShell 5.1 on 2026-10-29 — that is the baseline this story must keep.
- **Deferred review items still open** (do not fix here, do not regress): no `sudo -v`; `require_repo_asset_path` uses `-e`; arch.txt not comment-filtered; scenario G assumes no sudo in image; one fixture failure aborts later scenarios (another reason H–J go last).

### Git Intelligence

- `caeec50 docs(planning): correct course to Arch Linux only` — planning side of this change; read `sprint-change-proposal-2026-10-29.md` §2 "Technical impact" for the authoritative removal list.
- `c9b569e test: capture expected setup.sh stderr in WSL helper` — harness fix this story depends on.
- `45598f9 feat: align Windows and local dotfiles bootstrap (Stories 2.2, 3.1)` — introduced the files being deleted; history keeps them (spine "Deferred").
- Commit convention: `feat: narrow bootstrap to Arch Linux only (Story 2.6)` with the `Co-authored-by` trailer.

### Latest Technical Information

- `os-release(5)`: shell-compatible `KEY=value`; values may be quoted; `ID` is a lowercase identifier (Arch: `ID=arch`); `ID_LIKE` is a space-separated list of related distros (EndeavourOS/Manjaro: `ID_LIKE=arch`). On Arch, `/etc/os-release` is a relative symlink to `../usr/lib/os-release`; moving the symlink within `/etc` keeps it valid, which is why `Restore-OsRelease` uses `mv` back. Sourcing in a `$( … )` subshell is the standard safe way to read one field.
- No library or package version changes in this story.

### Project Structure Notes

- No `project-context.md` exists. Authoritative context: `epics.md` (Story 2.6), `sprint-change-proposal-2026-10-29.md`, the 2026-08-07 spine (AD-7 rewritten), SPEC/stack.md (already Arch-only), Story 2.2, current code.
- Ignore Ubuntu/Windows wording in Epic 1 story files, the superseded 2026-08-05 spine, the SPEC `.memlog.md`, and the 2026-10-07 readiness report — all historical.
- After this story, the only remaining Ubuntu/Windows mentions in tracked product files should be: validate-dotfiles' `apt` guard in `run_` scripts, WslTestInstance host comments, and the new forbid/absence assertions themselves.

### References

- [epics.md: Story 2.6](../planning-artifacts/epics.md)
- [sprint-change-proposal-2026-10-29.md §2 Technical impact, §4.3 AD-7](../planning-artifacts/sprint-change-proposal-2026-10-29.md)
- [ARCHITECTURE-SPINE.md (2026-08-07): AD-2, AD-3, AD-7, AD-8, AD-9](../planning-artifacts/architecture/architecture-config-v2-dotfiles-integration-2026-08-07/ARCHITECTURE-SPINE.md)
- [SPEC.md: CAP-1, Arch-only constraint, Open Questions](../specs/spec-dev-env-config-repo/SPEC.md)
- [2-2-apply-local-dotfiles-from-setup-sh.md](./2-2-apply-local-dotfiles-from-setup-sh.md), [3-1-align-setup-ps1-with-shared-repository-contract.md](./3-1-align-setup-ps1-with-shared-repository-contract.md), [deferred-work.md](./deferred-work.md)
- [setup.sh](../../setup.sh), [tests/validate-setup.ps1](../../tests/validate-setup.ps1), [tests/validate-readme.ps1](../../tests/validate-readme.ps1), [tests/lib/WslTestInstance.ps1](../../tests/lib/WslTestInstance.ps1), [README.md](../../README.md)

## Dev Agent Record

### Agent Model Used

Claude (AI assistant using Copilot SDK in VS Code)

### Debug Log References

- Workflow customization resolved manually (`resolve_customization.py` needs Python 3.11+ `tomllib`); no team/user overrides for dev-story. No `project-context.md`.
- Baseline WSL distros: `archlinux` only. It was listed before and after every run and never modified. `config-v2-test` was removed after each run. One read-only `bash -n` syntax check of a mutation copy ran inside `archlinux`; nothing was written there.
- Red phase (new validators against the old code): `validate-readme.ps1` failed with Windows section, `packages/ubuntu.txt`, `.\setup.ps1` and missing guard. `validate-setup.ps1` failed the static checks for Ubuntu, apt, dpkg, lsb_release, third-party repos and the missing guard. Scenario H failed with `Missing packages/ubuntu.txt`, I with `Unsupported distro 'endeavouros'. Supported distros: arch, ubuntu.`, and J with a raw `/etc/os-release: No such file or directory` bash error. Scenarios A–G stayed green, and the os-release restore check passed.
- Green phase (Windows PowerShell 5.1): `validate-readme.ps1`, `validate-wsl-test-ca.ps1`, `validate-setup.ps1` (A–J) and `validate-dotfiles.ps1` all passed, run sequentially.
- Mutation checks on temp copies of the repo: each one went red as intended.
  - (a)+(e) `ubuntu)` case added and `packages/ubuntu.txt` recreated: static Ubuntu reference plus the absence check.
  - (b) guard moved after `sudo pacman`: both order checks, plus H/I/J shim logs showing `sudo pacman` before the failure.
  - (c) `ID_LIKE=arch` accepted (via an indirect variable so the static forbid would not fire): only scenario I failed. Setup ran to completion, wrote `~/.ssh` and `~/.config/chezmoi`, and the new `.ssh` assertion caught it.
  - (d) `-r` check dropped: scenario J showed the raw bash error.
  - (f) README Windows heading re-added: readme validator.
- The first version of mutation (c) wrote `${ID_''LIKE:-}`. That is a bash "bad substitution" error and would have broken the happy path too. I fixed it to `${!v:-}` before its run and checked it with `bash -n`.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- Deleted `setup.ps1`, `packages/scoop.txt`, `packages/winget.txt`, `packages/ubuntu.txt` and `tests/validate-setup-ps1.ps1`. `tests/lib/WslTestInstance.ps1` was kept unchanged.
- `setup.sh` preflight order is now: refuse root → require sudo → Arch-only guard → `.git` → `dotfiles/.chezmoi.toml.tmpl` → `packages/arch.txt`.
  - The guard reads `ID` from `/etc/os-release` in a subshell; a missing file reads as `unknown`. It refuses anything other than `arch` with `ERROR: Unsupported distro '<id>': only Arch Linux is supported …` on stderr.
  - `ID_LIKE` is ignored, so derivatives are refused.
- The Ubuntu/apt/dpkg/lsb_release/Docker/Microsoft branch is removed. Packages install in one pacman stage. The chezmoi-missing message points to `packages/arch.txt`, and section comments are renumbered (1)–(4).
- `tests/validate-setup.ps1`:
  - Ubuntu static checks removed. Added forbids for Ubuntu/apt/dpkg/lsb_release/third-party repos/`ID_LIKE`, a required guard message, a guard-before-preflight/pacman order check, and repo absence/presence checks.
  - `Assert-FailedBeforeMutation` now also asserts no `~/.ssh`.
  - New scenarios H (Ubuntu), I (EndeavourOS with `ID_LIKE=arch`) and J (missing os-release) fake `/etc/os-release` and always restore it in `finally`. They run last, followed by a restore assertion.
- `tests/validate-readme.ps1`: dropped the Ubuntu manifest and Windows section assertions. Added an Arch-only guard assertion and targeted README forbids (Windows section heading, removed manifests, `.\setup.ps1`). The words "Windows"/"Ubuntu" are still allowed, so Story 2.5 can list them as deferred.
- `README.md`: only the minimal edits (intro line, manifest sentence, "what it does" step 2, Windows section removed). The two-repo wording is left for Story 2.5.

### File List

- `setup.ps1` (deleted)
- `packages/scoop.txt` (deleted)
- `packages/winget.txt` (deleted)
- `packages/ubuntu.txt` (deleted)
- `tests/validate-setup-ps1.ps1` (deleted)
- `setup.sh` (modified)
- `tests/validate-setup.ps1` (modified)
- `tests/validate-readme.ps1` (modified)
- `README.md` (modified)
- `_bmad-output/implementation-artifacts/2-6-narrow-the-bootstrap-to-arch-linux-only.md` (new)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)

### Change Log

- 2026-10-29: Story 2.6 implemented. Bootstrap narrowed to Arch Linux only: Windows/Ubuntu files removed, Arch-only preflight guard added to `setup.sh`, validators retargeted with non-Arch scenarios H–J, README minimally updated. Status → review.
