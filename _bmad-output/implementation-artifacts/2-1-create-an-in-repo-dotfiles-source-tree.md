---
baseline_commit: 05e042f4885ea21a441fd584640ded2a1b671db5
---

# Story 2.1: Create an In-Repo Dotfiles Source Tree

Status: done

> **AC refinement (approved by Jonas, 2026-10-07):** `epics.md` Story 2.1 only requires the `dotfiles/` tree and its safety rules. Per the implementation readiness report 2026-10-07 (Major issue #1, "No managed-content baseline"), this story also delivers the minimum managed-content baseline from `stack.md` (ACs 2 and 5) so an empty or skeleton `dotfiles/` cannot pass. ACs 1, 3, and 4 restate the epics ACs with concrete, testable wording (readiness Minor #3).

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer testing the bootstrap flow,
I want the managed dotfiles source to live under `config-v2/dotfiles/`,
so that the repository itself contains the exact configuration state the setup flow applies.

## Acceptance Criteria

1. **Given** the repository root, **When** I inspect the source tree, **Then** a `dotfiles/` directory exists at repo root as the authoritative chezmoi source-state root **And** `chezmoi --source <repo>/dotfiles` can render and apply it to an isolated destination without errors **And** chezmoi root-level special files (`.chezmoi.toml.tmpl`) live inside `dotfiles/`, not at repo root (AD-1, AD-3)

2. **Given** `dotfiles/` applied to an empty destination home, **When** I list the result, **Then** these managed targets exist (CAP-1, `stack.md`):
   - `~/.zshrc`: bootstraps zinit and loads `fzf-tab`, `zsh-autosuggestions`, `fast-syntax-highlighting`, plus `zoxide`, `starship`, and `fnm` shell integration
   - `~/.config/starship.toml`
   - `~/.config/nvim/init.lua`
   - `~/.config/tmux/tmux.conf`
   - `~/.gitconfig`: carries the single Git identity, and GPG signing when a fingerprint is supplied (NFR3)

3. **Given** content added under `dotfiles/`, **When** I review it for test-fixture safety, **Then** no secrets, private keys, passwords, tokens, or machine-unique credentials are committed **And** personal values are never hardcoded; they come from the canonical keys `GIT_USER_NAME`, `GIT_USER_EMAIL`, `GPG_FINGERPRINT` (AD-8) supplied at `chezmoi init` time, with safe placeholder defaults when absent **And** none of the personal values in the `setup.sh` configuration block appear anywhere under `dotfiles/` (AD-4, NFR1)

4. **Given** `dotfiles/`, **When** I list its scripts, **Then** it contains no `run_once_` script and no `run_` script that installs packages or orchestrates setup (AD-9)

5. **Given** `dotfiles/` applied once to an isolated destination, **When** I run `chezmoi verify` (or apply again), **Then** the destination already matches the target state with no further changes (idempotent apply, CAP-2, NFR8)

6. **Given** the repo-local validation script `tests/validate-dotfiles.ps1`, **When** I run it from repo root, **Then** it checks ACs 1–5 against an isolated temp destination, without touching the real `$HOME` or the real chezmoi config/state, **And** it passes

## Tasks / Subtasks

- [x] Task 1: Write the failing validation script first (AC: 6, red phase)
  - [x] Create `tests/validate-dotfiles.ps1` following the style of `tests/validate-readme.ps1` (`$ErrorActionPreference = 'Stop'`, `$repoRoot = Split-Path -Parent $PSScriptRoot`, collect failures in a `List[string]`, print each, `exit 1`; print `Dotfiles validation passed.` on success).
  - [x] Static checks (no chezmoi needed): `dotfiles/` exists; `dotfiles/.chezmoi.toml.tmpl` exists and there is no `.chezmoi.*.tmpl` at repo root; every required source file from the File Structure table exists.
  - [x] Safety checks (AC 3): scan every file under `dotfiles/` and fail on `-----BEGIN .*PRIVATE KEY-----`, `encrypted_`- or `private_`-prefixed source names, private-key file names (`id_rsa`, `id_ed25519`, `id_ecdsa` without `.pub`), and `(?i)(password|passwd|secret|token|api[_-]?key)\s*[:=]\s*\S+`.
  - [x] Personal-value leak check (AC 3): parse `setup.sh` the same way `validate-readme.ps1` does (`^\s*([A-Z_]+)=["']?(.+?)["']?\s*$`) and fail if the values of `GIT_USER_NAME`, `GIT_USER_EMAIL`, `GPG_FINGERPRINT` appear in any file under `dotfiles/`.
  - [x] Script checks (AC 4): fail on any path segment starting with `run_once_`; fail on any `run_*` file containing `pacman`, `apt-get`, `apt `, `curl `, `wget `, `setup.sh`, or `| bash`/`| sh`.
  - [x] Render/apply checks (AC 1, 2, 5): run inside a fresh disposable `config-v2-test` Arch WSL instance (see Testing Requirements). If the instance cannot be prepared, fail with the reason. Then run scenario A and scenario B from the Testing Requirements section.
  - [x] Run the script and confirm it fails before `dotfiles/` exists.
- [x] Task 2: Create the `dotfiles/` source root and init config template (AC: 1, 3)
  - [x] Create `dotfiles/.chezmoi.toml.tmpl` exactly as specified in Dev Notes → Config template. Only the three canonical keys, read via `env` with safe defaults.
  - [x] Add `.gitattributes` at repo root with `dotfiles/** text eol=lf`, so Linux-consumed dotfiles stay LF even in Windows working copies (`core.autocrlf=true` here).
- [x] Task 3: Add the managed-content baseline (AC: 2, 3, 4)
  - [x] `dotfiles/dot_zshrc` (see Dev Notes → zsh).
  - [x] `dotfiles/dot_gitconfig.tmpl` (see Dev Notes → git).
  - [x] `dotfiles/dot_config/starship.toml`: small, valid TOML (for example `add_newline = false` plus one module tweak). No Nerd-Font-only glyphs required (fonts are a host concern).
  - [x] `dotfiles/dot_config/nvim/init.lua`: plugin-free baseline (line numbers, relative numbers, 2-space expandtab, `clipboard=unnamedplus`, `mouse=a`, `termguicolors`, leader = space). No plugin manager: it would add network bootstrap and is out of scope.
  - [x] `dotfiles/dot_config/tmux/tmux.conf`: `set -g default-terminal "tmux-256color"`, `set -g mouse on`, `set -g base-index 1`, `setw -g pane-base-index 1`, `set -sg escape-time 10`, `set -g history-limit 50000`. Do not hardcode a shell path; tmux uses `$SHELL`.
  - [x] No `run_*` scripts, no `.chezmoiexternal.*`, no encrypted files.
- [x] Task 4: Make validation green and confirm idempotence (AC: 1–6)
  - [x] Run `pwsh -NoProfile -File tests\validate-dotfiles.ps1` until it passes.
  - [x] Run real `zsh -n` on the rendered `.zshrc` inside the test instance (zsh is installed there).
  - [x] Confirm the real `~/.config/chezmoi`, `~/.local/share/chezmoi`, and the real home were not touched (the test only uses temp dirs).
- [x] Task 5: Regression and scope guard (AC: all)
  - [x] Run `pwsh -NoProfile -File tests\validate-readme.ps1`. Its **baseline is already failing** with 3 `setup.sh` assertions (`require_repo_asset_path`, Arch/Ubuntu manifest usage) that Story 2.2 owns. Confirm this story adds **no new** failures. Do not edit `setup.sh`, `README.md`, or `validate-readme.ps1` here.
  - [x] Confirm `git status` shows only the files in the File Structure table.

## Dev Notes

### Scope Boundaries (read first)

| In this story | NOT in this story (owner) |
| --- | --- |
| `dotfiles/` source tree + baseline content | Wiring `setup.sh` to apply local `dotfiles/`, removing `DOTFILES_REPO`, repo-root paths, persisting chezmoi `sourceDir` for plain `chezmoi apply` (Story 2.2) |
| `.chezmoi.toml.tmpl` reading canonical keys from env | `setup.sh` exporting `GIT_USER_NAME`/`GIT_USER_EMAIL`/`GPG_FINGERPRINT` into `chezmoi init` (Story 2.2) |
| fnm shell integration inside `.zshrc` | fnm installer `--skip-shell`, zsh as login shell, stateful vs managed path classification, `~/.ssh/config` (Story 2.3) |
| `tests/validate-dotfiles.ps1` (fixture/render checks) | On-machine smoke verification of tools/shell/editor (Story 2.4) |
| — | README / `validate-readme.ps1` refresh (Story 2.5) |
| — | Installing a Node version via fnm; Angular CLI (no global npm packages, NFR9) |

### Architecture Compliance (MUST FOLLOW)

| Rule | Requirement for this story |
| --- | --- |
| AD-1 | All chezmoi source lives under `dotfiles/`. No managed config at repo root. |
| AD-2 | `dotfiles/` holds config only; no package installation or orchestration. |
| AD-3 | Paths are repo-relative; the test derives everything from `$PSScriptRoot`. |
| AD-4 | Public-safe fixture: placeholders by default, real values injected at init, nothing personal tracked. |
| AD-5 | Every target in this story is `chezmoi-managed`: `~/.zshrc`, `~/.gitconfig`, `~/.config/{starship.toml,nvim/init.lua,tmux/tmux.conf}`. Never add a target that `setup.sh` writes (`$SSH_KEY_FILE`, GPG keyring). |
| AD-8 | Template data uses only the canonical keys, mapped 1:1 to lowercase data names: `GIT_USER_NAME`→`git_user_name`, `GIT_USER_EMAIL`→`git_user_email`, `GPG_FINGERPRINT`→`gpg_fingerprint`. No new keys and no `DOTFILES_REPO`. |
| AD-9 | No `run_once_` scripts; no `run_` scripts that install packages or replace `setup.sh`. |

### Config template: `dotfiles/.chezmoi.toml.tmpl`

`chezmoi init` uses this file to generate the machine's chezmoi config. The persisted `[data]` values then serve every later plain `chezmoi apply` (CAP-2). Story 2.2 supplies real values through environment variables. Without them you get safe test-fixture placeholders.

```toml
{{- $gitUserName := env "GIT_USER_NAME" | default "Bootstrap Test User" -}}
{{- $gitUserEmail := env "GIT_USER_EMAIL" | default "bootstrap-test@example.invalid" -}}
{{- $gpgFingerprint := env "GPG_FINGERPRINT" -}}
[data]
    git_user_name = {{ $gitUserName | quote }}
    git_user_email = {{ $gitUserEmail | quote }}
    gpg_fingerprint = {{ $gpgFingerprint | quote }}
```

- Do **not** use `prompt*` functions. Setup is non-interactive (NFR3).
- Do **not** add `sourceDir` here. Story 2.2 owns the sync path.

### git: `dotfiles/dot_gitconfig.tmpl`

```ini
[user]
	name = {{ .git_user_name }}
	email = {{ .git_user_email }}
{{- if .gpg_fingerprint }}
	signingkey = {{ .gpg_fingerprint }}
[commit]
	gpgsign = true
[tag]
	gpgsign = true
{{- end }}
[init]
	defaultBranch = main
[core]
	editor = nvim
```

Signing is enabled **only** when a fingerprint is supplied, so the placeholder fixture has no signing. chezmoi's default `missingkey=error` makes apply fail if the config was not generated from `.chezmoi.toml.tmpl`. That is the desired signal.

### zsh: `dotfiles/dot_zshrc` (plain file, not a template)

Required order (fzf-tab must load **after** `compinit` and **before** widget-wrapping plugins):

1. History options (`HISTFILE=~/.zsh_history`, `HISTSIZE`/`SAVEHIST`, `setopt share_history hist_ignore_dups`), `export EDITOR=nvim VISUAL=nvim`.
2. zinit bootstrap, official snippet (zdharma-continuum):
   ```zsh
   ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
   [ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
   [ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
   source "${ZINIT_HOME}/zinit.zsh"
   ```
3. `autoload -Uz compinit && compinit`
4. `zinit light Aloxaf/fzf-tab`
5. `zinit light zsh-users/zsh-autosuggestions`
6. `zinit light zdharma-continuum/fast-syntax-highlighting` (stack.md says **fast**-syntax-highlighting, not zsh-syntax-highlighting)
7. fnm (matches the fnm installer's default dir, without the installer writing rc files):
   ```zsh
   FNM_PATH="${XDG_DATA_HOME:-$HOME/.local/share}/fnm"
   if [ -d "$FNM_PATH" ]; then export PATH="$FNM_PATH:$PATH"; fi
   if command -v fnm >/dev/null 2>&1; then eval "$(fnm env --use-on-cd --shell zsh)"; fi
   ```
8. `command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"`
9. `command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"` (last, so it owns the prompt)

Guard every tool init with `command -v` so a partial install never breaks the shell. Story 2.4 verification reports missing tools. zinit clones the plugins on first interactive start; this is runtime state under `~/.local/share/zinit`, not a bootstrap-touched path.

### File Structure Requirements

| Path | Action |
| --- | --- |
| `dotfiles/.chezmoi.toml.tmpl` | NEW |
| `dotfiles/dot_zshrc` | NEW |
| `dotfiles/dot_gitconfig.tmpl` | NEW |
| `dotfiles/dot_config/starship.toml` | NEW |
| `dotfiles/dot_config/nvim/init.lua` | NEW |
| `dotfiles/dot_config/tmux/tmux.conf` | NEW |
| `.gitattributes` | NEW (`dotfiles/** text eol=lf`) |
| `tests/validate-dotfiles.ps1` | NEW |
| `setup.sh`, `README.md`, `tests/validate-readme.ps1`, `packages/*` | DO NOT MODIFY |

Layout is a flat chezmoi source root at `dotfiles/` (the spine leaves internal layout to implementation). Story 2.2 may point chezmoi at it either with `--source <repo>/dotfiles` or with a repo-root `.chezmoiroot` containing `dotfiles`. Both work with this layout, provided `.chezmoi.toml.tmpl` stays inside `dotfiles/`.

### Testing Requirements

> **Linux test instance (Jonas, 2026-10-07):** chezmoi/zsh checks run inside a **fresh, disposable Arch WSL instance named `config-v2-test`**, created per test run and unregistered afterwards. Never use or modify other WSL instances (`archlinux`, `MyArch`, …). The shared helper is `tests/lib/WslTestInstance.ps1`; reuse it for later Linux-side tests (Stories 2.2, 2.4).

Static checks (structure, safety, leaks, AD-9 scripts) run on Windows against the working tree. For render/apply checks, `tests/validate-dotfiles.ps1`:

1. `New-ConfigV2TestInstance @('chezmoi','zsh')` →
   - download the Arch image listed in Microsoft's WSL manifest once into `%LOCALAPPDATA%\config-v2\wsl-cache` (SHA256-verified)
   - remove any leftover `config-v2-test`
   - `wsl --install --from-file <image> --name config-v2-test --location %LOCALAPPDATA%\config-v2\wsl\config-v2-test --no-launch`
   - copy the TLS roots Windows trusts for the pacman mirrors/GitHub into the instance's trust store (needed behind TLS-inspecting proxies such as Zscaler)
   - `pacman -Syu` + install the packages, with retries
2. Copy the working-tree `dotfiles/` into `/var/tmp/config-v2-dotfiles/<scenario>/source` and isolate **every** chezmoi call to that sandbox:

```text
--source $sandbox/source --destination $sandbox/home --config $sandbox/chezmoi.toml
--persistent-state $sandbox/state.boltdb --cache $sandbox/cache --no-tty
```

3. Generate the config without `chezmoi init` (which would `git init` the source): `chezmoi execute-template --init --file "$sandbox/source/.chezmoi.toml.tmpl" > "$sandbox/chezmoi.toml"`. Apply and verify with `--exclude scripts`, so a stray `run_` script can never execute.
4. Always `Remove-ConfigV2TestInstance` in `finally`, unless `-KeepInstance` is passed for debugging.

- **Scenario A (fixture defaults):** identity env unset → render config → `apply --force` → assert all 5 targets exist; `.gitconfig` contains `Bootstrap Test User` and `bootstrap-test@example.invalid` and contains no `signingkey`/`gpgsign`; `.zshrc` contains `zinit.zsh`, `Aloxaf/fzf-tab`, `zsh-users/zsh-autosuggestions`, `zdharma-continuum/fast-syntax-highlighting`, `zoxide init zsh`, `starship init zsh`, `fnm env`, compinit → fzf-tab → widget plugins order, and passes real `zsh -n` → `chezmoi verify` exits 0 (AC 5).
- **Scenario B (injected values):** env set to **fake** values (`Fixture Person`, `fixture@example.invalid`, `0000000000000000000000000000000000000000`) in a fresh sandbox → assert `.gitconfig` contains them plus `gpgsign = true`.
- Match file content with CRLF-tolerant regexes.
- Prerequisites: WSL 2 with `--install --from-file/--name/--location` support (WSL 3.0.1 here), pwsh 7.4, network access to the Arch mirrors. Windows-side chezmoi is not required.

Run: `pwsh -NoProfile -File tests\validate-dotfiles.ps1` (about 50 s per run once the image is cached; add `-KeepInstance` to inspect the instance).

### Previous Work Intelligence

- Epic 1 (Stories 1.1–1.5) delivered `setup.sh`, the manifests, and the README. Both manifests already install `chezmoi`, `zsh`, `neovim`, `tmux`, `starship`, `zoxide`, `fzf`, `git`. fnm comes from its curl installer, whose rc-file writing Story 2.3 will disable.
- `setup.sh` comment states `~/.ssh/config` is chezmoi-managed. **Do not** add it in this story; Story 2.3 classifies SSH paths.
- `validate-readme.ps1` pattern to reuse: repo-root resolution from `$PSScriptRoot`, failure list, parsing the `setup.sh` config block to prevent value leaks.
- Commit convention: `feat: <summary> (Story 2.1)`, for example `feat: add in-repo dotfiles source tree with baseline config (Story 2.1)`.
- `config.sh` no longer exists (inline config moved into `setup.sh`). Ignore stale references in Epic 1 story files.

### Latest Technical Information

- chezmoi 2.70.x: `init` creates a git repo in the source dir if none is detected. Never run `init` against `dotfiles/` in tests; use `execute-template --init`. `.chezmoiroot` (repo root) is the documented way to keep source state in a repo subdirectory. Root special files must then live in that subdirectory.
- zinit lives at `zdharma-continuum/zinit`. The original `zdharma/zinit` is gone; do not use it. Same org for `fast-syntax-highlighting`.
- fzf-tab docs: load after `compinit`, before plugins that wrap widgets (autosuggestions, syntax highlighting).
- fnm installer default install dir is `$XDG_DATA_HOME/fnm` → `~/.local/share/fnm`. `fnm env --use-on-cd --shell zsh` is the current integration.

### Project Structure Notes

- No `project-context.md` exists; epics, SPEC/stack.md, the 2026-08-07 spine, and existing code are the authoritative context.
- The superseded 2026-08-05 spine and older story files mention `config.sh`, `DOTFILES_REPO`, `zsh-syntax-highlighting`, and two repos. **Do not follow them.**

### References

- [epics.md: Story 2.1](../planning-artifacts/epics.md)
- [implementation-readiness-report-2026-10-07.md: Major #1, Minor #3](../planning-artifacts/implementation-readiness-report-2026-10-07.md)
- [ARCHITECTURE-SPINE.md (2026-08-07, AD-1..AD-9)](../planning-artifacts/architecture/architecture-config-v2-dotfiles-integration-2026-08-07/ARCHITECTURE-SPINE.md)
- [sprint-change-proposal-2026-10-07.md](../planning-artifacts/sprint-change-proposal-2026-10-07.md)
- [SPEC.md](../specs/spec-dev-env-config-repo/SPEC.md), [stack.md](../specs/spec-dev-env-config-repo/stack.md)
- [brainstorm memlog 2026-08-07](../brainstorming/brainstorm-dotfiles-setup-flow-2026-08-07/.memlog.md) (fake-input overlay, verification script)
- [setup.sh](../../setup.sh), [tests/validate-readme.ps1](../../tests/validate-readme.ps1), [packages/arch.txt](../../packages/arch.txt), [packages/ubuntu.txt](../../packages/ubuntu.txt)
- chezmoi docs: `init`, `.chezmoiroot`, "Customize your source directory"; zinit README (Manual install)

## Dev Agent Record

### Agent Model Used

Claude (AI assistant using Copilot SDK in VS Code)

### Debug Log References

- Workflow customization resolved manually: `_bmad/scripts/resolve_customization.py` needs Python 3.11+ (`tomllib`), which is not available here. No team/user overrides exist for dev-story or create-story.
- `scoop install chezmoi` failed on Scoop self-update (`Sync-Scoop ... CommitHash empty`); installed with `scoop install chezmoi --no-update-scoop` → chezmoi v2.70.0.
- Red phase: `tests/validate-dotfiles.ps1` failed with `dotfiles/ directory is missing at repository root.` before any content existed.
- Mutation run 1 showed that a `run_once_*.sh` placed in `dotfiles/` was **executed** by the sandbox `chezmoi apply` (only failed because Windows cannot exec `.sh`). Fixed by passing `--exclude scripts` to sandbox `apply`/`verify`, so the test can never run repo scripts on the host.
- Mutation run 1 also showed the fzf-tab-order mutation was a no-op because new files had CRLF endings (`core.autocrlf=true`). Normalized `dotfiles/**` and `.gitattributes` to LF and re-ran.
- Mutations verified to fail validation: `run_once_` package-install script, fzf-tab loaded after widget plugins, missing starship init, personal `GIT_USER_EMAIL` value leaked into `dotfiles/`, unconditional GPG signing, template referencing an undeclared data key. Restored tree passes.
- `zsh` is not installed on this Windows box, so the first Windows-side version only ran `bash -n` as a rough check. Superseded: real `zsh -n` now runs inside the `config-v2-test` instance.
- 2026-10-07 (Jonas): moved Linux-side checks into a fresh `config-v2-test` Arch WSL instance per run. First attempt: pacman failed on SSL (`unable to get local issuer certificate`). Windows reaches the mirrors through a Zscaler TLS-inspection root, so the helper now copies the roots Windows trusts for `geo/fastly.mirror.pkgbuild.com` and `github.com` into the instance's trust store. Second attempt: `extra.db` stalled ("Operation too slow"); added `--disable-download-timeout` and 3 retries. Then green: about 48–70 s per run with the image cached (118 MB, `archlinux-2026.10.01.179549.wsl`). Instance chezmoi is v2.73.0 and zsh is 5.9.2.
- WSL mutation checks fail as expected: zsh syntax error (caught by real `zsh -n`), unconditional signing, undeclared template key. `-KeepInstance` leaves the instance for inspection; the next run removes the leftover and recreates it. `archlinux` and `MyArch` were never touched (listed before, during, and after each run).

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- Created `dotfiles/` as a flat chezmoi source-state root with `.chezmoi.toml.tmpl` inside it. The template maps the canonical AD-8 keys `GIT_USER_NAME`/`GIT_USER_EMAIL`/`GPG_FINGERPRINT` from env into `[data]` (`git_user_name`/`git_user_email`/`gpg_fingerprint`), with public-safe placeholder defaults (`Bootstrap Test User`, `bootstrap-test@example.invalid`, empty fingerprint). No prompts and no `sourceDir`; Story 2.2 owns both the env injection and the sync path.
- Managed-content baseline: `dot_zshrc` (zinit bootstrap → compinit → fzf-tab → zsh-autosuggestions → fast-syntax-highlighting → fnm env → zoxide → starship, all tool inits `command -v`-guarded), `dot_gitconfig.tmpl` (identity, GPG signing only when a fingerprint is supplied, `init.defaultBranch=main`, `core.editor=nvim`), `dot_config/starship.toml`, plugin-free `dot_config/nvim/init.lua`, `dot_config/tmux/tmux.conf`.
- No `run_` scripts, externals, encrypted/private files, or personal values under `dotfiles/`. Every target is `chezmoi-managed` (AD-5); `setup.sh`-owned paths (SSH key, GPG keyring) are not touched.
- Added `.gitattributes` (`dotfiles/** text eol=lf`) so Linux-consumed dotfiles stay LF in Windows working copies.
- `tests/validate-dotfiles.ps1` runs static structure, fixture-safety, personal-value-leak and AD-9 script checks, plus two fully sandboxed chezmoi scenarios (temp `--source/--destination/--config/--persistent-state/--cache`, `--no-tty`, `--exclude scripts`). Scenario A covers defaults: all 5 targets, placeholder identity, no signing, `.zshrc` content and plugin order, then `chezmoi verify` for idempotence. Scenario B covers injected fake values: identity plus `signingkey` and `gpgsign = true`. Env vars are restored and temp dirs removed in `finally`. Confirmed the real `~/.config/chezmoi` and `~/.local/share/chezmoi` did not exist before or after, and no temp sandboxes remain.
- Results: `pwsh -NoProfile -File tests\validate-dotfiles.ps1` → passed. `tests\validate-readme.ps1` → same 3 pre-existing `setup.sh` failures as the baseline (owned by Story 2.2), no new failures. `setup.sh`, `README.md`, `validate-readme.ps1`, and `packages/*` are unchanged.

### File List

- `.gitattributes` (new)
- `dotfiles/.chezmoi.toml.tmpl` (new)
- `dotfiles/dot_zshrc` (new)
- `dotfiles/dot_gitconfig.tmpl` (new)
- `dotfiles/dot_config/starship.toml` (new)
- `dotfiles/dot_config/nvim/init.lua` (new)
- `dotfiles/dot_config/tmux/tmux.conf` (new)
- `tests/validate-dotfiles.ps1` (new)
- `tests/lib/WslTestInstance.ps1` (new)
- `_bmad-output/implementation-artifacts/2-1-create-an-in-repo-dotfiles-source-tree.md` (new, story file)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified: epic-2 in-progress, 2-1 status)

### Change Log

- 2026-10-07: Story created with the managed-content baseline as an approved AC refinement (readiness report 2026-10-07, Major #1).
- 2026-10-07: Implemented the in-repo `dotfiles/` chezmoi source tree with the baseline config (zsh/zinit, git, starship, Neovim, tmux), the env-driven init config template, `.gitattributes`, and the sandboxed `tests/validate-dotfiles.ps1`. Status → review.
- 2026-10-07: Per Jonas, Linux-side test checks run in a fresh disposable `config-v2-test` Arch WSL instance per run, via the new reusable `tests/lib/WslTestInstance.ps1` (cached SHA256-verified image, host TLS roots, `-KeepInstance` for debugging). Windows-side chezmoi is no longer a test prerequisite.
- 2026-10-07: Validated (all ACs pass; validate-readme baseline unchanged). Status → done.
