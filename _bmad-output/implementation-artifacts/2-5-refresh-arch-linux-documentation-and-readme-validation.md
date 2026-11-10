---
baseline_commit: bf8468e4a634e8da86ad1bde53228b03f0cf4bd3
---

# Story 2.5: Refresh Arch Linux Documentation and README Validation

Status: done

> **Sequencing:** last story of Epic 2. It builds on Stories 2.1 to 2.4 and 2.6 (all done). Those stories deliberately left README wording alone; this story owns the full README rewrite, and `tests/validate-readme.ps1` is its test. No production script changes: `setup.sh`, `tests/verify-setup.sh`, `dotfiles/**` and `packages/arch.txt` stay as they are.

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer using or maintaining this repository,
I want the documentation and its validation test to describe the in-repo dotfiles model,
so that the supported workflow is clear and the README stays truthful as the setup flow evolves.

## Acceptance Criteria

1. **Given** the repository documentation, **When** I read the bootstrap flow description, **Then** it describes `dotfiles/` as part of `config-v2` rather than a separate dotfiles repository **And** it explains the local-checkout execution contract and verification expectations (FR1, AD-1, AD-3, AD-6) **And** it states Arch Linux (WSL or VM) as the only supported target and lists Windows and other distros as deferred (FR1, NFR2).
2. **Given** the updated docs, **When** I review examples and configuration guidance, **Then** no sensitive values are introduced **And** the public-safe and test-fixture-safe rules remain explicit (NFR1, AD-4).
3. **Given** `tests/validate-readme.ps1`, **When** the README is updated, **Then** the two-repo and `DOTFILES_REPO` assertions are replaced by in-repo dotfiles, local-checkout, and verification assertions **And** the test passes against the new README.

Concrete interpretation (binding for this story):

- **AC1a — no stale two-repo wording.** README no longer says "separate dotfiles repo", "dotfiles repo", "two-repo", or mentions `DOTFILES_REPO`. Step 4 of "What the Linux bootstrap does" now says `chezmoi init --apply` applies the managed configuration from `dotfiles/` in this checkout. "Architecture Overview" is rewritten for the one-repo model.
- **AC1b — local-checkout contract.** README states: the only supported entry point is a local clone run from the repository root; `setup.sh` reads `packages/arch.txt` **and** `dotfiles/` from that same checkout; it exits with an actionable error when a repo-local asset is missing (AD-3). The existing "supported bootstrap path" sentence (validator check) stays.
- **AC1c — ongoing sync path** (readiness report Major #3, deferred to this story). README documents how an existing machine picks up changes: `git pull` in the checkout, then plain `chezmoi apply` (chezmoi's `sourceDir` was persisted to the checkout's `dotfiles/` by `chezmoi init`, so no flags are needed), or rerun `./setup.sh` to also re-run the stateful checks and verification. It also states: if the checkout is moved, rerun `./setup.sh` from the new location so `sourceDir` is regenerated.
- **AC1d — verification expectations.** A `## Verification` section lists what the smoke verification checks per stage tag (`[packages]`, `[stateful]`, `[dotfiles]`, `[shell]`, `[editor]`), that it runs automatically as the last `setup.sh` stage and via `./setup.sh --verify`, that it is read-only, that every failure prints `ERROR: [<stage>] …` and the run exits non-zero, and that a GPG key missing from the keyring is a warning only (import stays manual). Keep the numbered bootstrap step 5 and the `./setup.sh --verify` sentence the Story 2.4 validator checks require.
- **AC1e — scope.** README states Arch Linux (WSL or VM) is the only supported target and has a `## Not Supported Yet` section that lists Windows (a native/PowerShell bootstrap) and other Linux distros (for example Ubuntu) as deferred. It must **not** name `setup.ps1`, `packages/ubuntu.txt`, `packages/scoop.txt`, `packages/winget.txt`, or reintroduce a "Windows Companion Bootstrap" heading (existing forbid checks).
- **AC2a — public-safe rules.** A `## Public-Safe Rules` section states: this repository is public and is also the end-to-end test fixture; nothing secret is committed (no private keys, passwords, tokens or machine-unique credentials); `dotfiles/` personal values are templated or come from the `setup.sh` configuration block, which holds only public-safe values (name, email, GPG fingerprint, key path); secrets (`$SSH_KEY_FILE` private key, GPG private keys) stay on the machine and are never managed by chezmoi. README must **not** repeat any `setup.sh` configuration value verbatim (the validator already enforces this for `GIT_USER_EMAIL`, `GPG_FINGERPRINT`, `SSH_KEY_FILE`).
- **AC3a — validator.** In `tests/validate-readme.ps1`: remove the `Two-repo architecture explanation` required check and the dead `'DOTFILES_REPO' = $null` entry in `$setupValuesToBlock`; add the new required and forbidden README checks listed under "validate-readme.ps1 changes". Keep every existing check that is still true (quick-start heading, git prerequisite, clone command, `./setup.sh`, inline-config note, local-checkout sentence, verify-only command, smoke-verification step, `config.sh` forbid, Arch-only forbids, Path Ownership checks, setup.sh assignment and pattern checks).

## Tasks / Subtasks

- [x] Task 1: Red phase — update `tests/validate-readme.ps1` (AC: 3)
  - [x] Remove the two-repo required check and the `DOTFILES_REPO` entry from `$setupValuesToBlock`.
  - [x] Add the new required and forbidden checks (see "validate-readme.ps1 changes").
  - [x] Run it against the current README and confirm it goes red on every new check and on the stale two-repo wording.
- [x] Task 2: Rewrite `README.md` (AC: 1, 2)
  - [x] Intro and scope line, Quick Start (unchanged commands), step 4 rewording, local-checkout contract, update flow, `## Verification`, keep `## Path Ownership` intact, `## Public-Safe Rules`, `## Not Supported Yet`, rewritten `## Architecture Overview`, short maintainer `## Validation` list.
  - [x] Check the README against "Do not write" below.
- [x] Task 3: Green phase (AC: 3)
  - [x] `tests\validate-readme.ps1` passes.
  - [x] Run `validate-setup.ps1`, `validate-dotfiles.ps1` and `validate-wsl-test-ca.ps1` once to prove nothing else regressed (docs only, so expect green).
- [x] Task 4: Mutation checks on temp copies of README (each must go red, then discard) (AC: 3)
  - (a) README step 4 says "separate dotfiles repo" → forbidden check.
  - (b) README mentions `DOTFILES_REPO` → forbidden check.
  - (c) remove the `## Verification` section → required check.
  - (d) remove the `## Not Supported Yet` section → required check.
  - (e) remove the update flow sentence (`git pull` / `chezmoi apply`) → required check.
  - (f) paste the GPG fingerprint from `setup.sh` into README → "README exposes setup.sh value".
  - (g) add `setup.ps1` or a `## Windows Companion Bootstrap` heading → existing forbid.
  - (h) remove the `## Public-Safe Rules` section → required check.
- [x] Task 5: Scope guard — `git status` shows only the files in the File Structure table.

### Review Findings

- [x] [Review][Patch] `setup.ps1` forbid weakened: the `(?<![\w-])` lookbehind exempts any prefixed name (`win-setup.ps1`), not just `validate-setup.ps1` [tests/validate-readme.ps1:122]
- [x] [Review][Patch] Update flow has no recovery for a changed `dotfiles/.chezmoi.toml.tmpl`; running `chezmoi init` by hand renders the template's test identity into `~/.gitconfig` [README.md:46]
- [x] [Review][Patch] `## Validation` omits `validate-wsl-test-ca.ps1`, which also uses `config-v2-test` [README.md:101]
- [x] [Review][Patch] Public-Safe Rules does not name the SSH key as `$SSH_KEY_FILE` (AC2a) [README.md:86]
- [x] [Review][Patch] Section-check failure message prints a raw regex instead of the spec message style [tests/validate-readme.ps1:107]
- [x] [Review][Patch] Stage tags and `ERROR: [<stage>]` are matched anywhere in the README, not inside `## Verification` [tests/validate-readme.ps1:66]
- [x] [Review][Patch] Stale-wording forbids miss "dotfiles repository", "two repositories" and line-wrapped phrases [tests/validate-readme.ps1:124]
- [x] [Review][Patch] An empty README makes the validator throw on `$null` instead of reporting a failure [tests/validate-readme.ps1:20]
- [x] [Review][Patch] `GIT_USER_NAME` is not blocked although the README says no configuration value is repeated [tests/validate-readme.ps1:177]
- [x] [Review][Patch] Verification section omits the final `ERROR: Verification failed: <k> of <n> checks failed` summary line [README.md:57]
- [x] [Review][Patch] `## Architecture Overview` is no longer guarded after the two-repo check was removed [tests/validate-readme.ps1:48]
- [x] [Review][Defer] Path Ownership row shows the literal default `~/.ssh/id_rsa`; the blocked-value check only compares the `${HOME}/…` form [README.md:74] — deferred, pre-existing

## Dev Notes

### Scope Boundaries (read first)

| In scope | Out of scope |
| --- | --- |
| `README.md` rewrite for the in-repo, Arch-only model | Any change to `setup.sh`, `tests/verify-setup.sh`, `dotfiles/**`, `packages/arch.txt` |
| `tests/validate-readme.ps1` assertions | New validators or a docs site; docs outside `README.md` |
| Documenting the sync path (`git pull` + `chezmoi apply`) | Changing how chezmoi `sourceDir` is persisted (done in Story 2.2) |
| Listing Windows and other distros as deferred | Implementing, scaffolding or testing a Windows or Ubuntu path (correct-course 2026-10-29) |

### Current `README.md` — what changes, what stays

Today it has, in order: intro line, `## Linux Quick Start` (Git prerequisite, `pacman -Syu` / `pacman -S git` block, clone block, inline-config note, packages-manifest sentence), `### What the Linux bootstrap does` (5 steps), `## Path Ownership` (table, 11 rows, plus a `~/.ssh/config` note), `## Architecture Overview` (two-repo model).

- **Stays verbatim:** `## Linux Quick Start` heading and both command blocks, the `Install Git manually first` sentence, the inline-configuration sentence, the `setup.sh reads packages/arch.txt from the same checkout. Running the script from the cloned repository is the supported bootstrap path.` sentence (extend it, keep its validator pattern matching), the whole `## Path Ownership` section (the validator parses its table rows: one row per path, exactly one category per row; do not add a row, verification touches no path).
- **Changes:** step 4 wording; the `Architecture Overview` section; new sections `## Verification`, `## Public-Safe Rules`, `## Not Supported Yet`, and a short `## Validation`.
- **Preserve the `Run ./setup.sh --verify` sentence and the numbered step 5** (Story 2.4 validator checks).

### Facts to document (verify each against the code before writing)

- Entry point and order (AD-9): preflight (not root, sudo present, `/etc/os-release` `ID=arch`, repo-local assets present) → pacman install of `packages/arch.txt` → stateful assets (fnm, zsh login shell, SSH key; GPG only checked) → `chezmoi init --apply --force --no-tty --source <checkout>/dotfiles` → smoke verification. `Bootstrap complete.` is printed only after verification passes. See `setup.sh`.
- `--verify`: runs preflight and then only `tests/verify-setup.sh`; nothing is changed. Any other argument exits 1 with a usage error.
- Managed targets (`dotfiles/`): `~/.zshrc`, `~/.gitconfig`, `~/.config/starship.toml`, `~/.config/nvim/init.lua`, `~/.config/tmux/tmux.conf`, plus `~/.config/chezmoi/chezmoi.toml` generated from `dotfiles/.chezmoi.toml.tmpl` (this file persists `sourceDir` to the checkout's `dotfiles/`). This is already in the Path Ownership table; do not duplicate it elsewhere.
- Verification stages (`tests/verify-setup.sh`): `[packages]` every `packages/arch.txt` entry installed (`pacman -Q`) and commands `chezmoi git zsh nvim tmux starship zoxide fzf docker dotnet` on `PATH`; `[stateful]` fnm executable, SSH private key present (an orphaned `.pub` fails), login shell zsh, GPG key in keyring (warn only); `[dotfiles]` chezmoi source is `<checkout>/dotfiles`, `chezmoi verify` clean, every managed file present; `[shell]` `~/.zshrc` parses (`zsh -n`); `[editor]` Neovim loads `init.lua`. Output: `ERROR: [<stage>] <what>. <fix>` per failure, then `ERROR: Verification failed: <k> of <n> checks failed (stages: …)`, non-zero exit.
- Prerequisites the README must keep: Git installed manually; run as a normal user with `sudo` (setup refuses root).
- Deferred scope: Windows (native/PowerShell bootstrap) and other distros. Say why in one line: the repository ships and tests only the Arch Linux path; adding a target needs a new architecture decision (AD-7).

### Do not write (README guardrails)

- No value copied from the `setup.sh` configuration block: not the email, not the GPG fingerprint, not the literal `${HOME}/.ssh/id_rsa`. Write `$SSH_KEY_FILE`, "the configured GPG fingerprint", "the configured identity". (`validate-readme.ps1` fails on verbatim values; this is the NFR1/AD-4 guard.)
- No `config.sh`, `DOTFILES_REPO`, "dotfiles repo", "two-repo", `setup.ps1`, `packages/ubuntu.txt|scoop.txt|winget.txt`, no "Windows Companion Bootstrap" heading.
- No instructions that curl-pipe a remote script or clone a second repository.
- No new claims about behaviour the code does not have. If unsure, read `setup.sh` or `tests/verify-setup.sh`.

### Target README outline (headings are part of the validator contract)

```markdown
# config-v2
<intro: Arch Linux (WSL or VM) bootstrap from a local checkout; Arch Linux is the only supported target; dotfiles/ is part of this repository>

## Linux Quick Start            <- keep heading + commands
<git prerequisite, clone/run block, inline-config note, local-checkout contract (AD-3)>

### What the Linux bootstrap does   <- 5 numbered steps; step 4 reworded; step 5 keeps "smoke verification"
<sentence: Run ./setup.sh --verify ...>

### Updating an existing machine
<git pull, then chezmoi apply; or rerun ./setup.sh; moved checkout note>

## Verification
## Path Ownership               <- unchanged
## Public-Safe Rules
## Not Supported Yet
## Architecture Overview        <- one-repo model: setup.sh, packages/, dotfiles/, tests/
## Validation                   <- maintainer commands (Windows PowerShell, WSL test instance)
```

Binding phrases (validator patterns match these; keep the wording or change both together):

- Intro or Architecture Overview contains: ``The `dotfiles/` directory is part of `config-v2` `` (no separate dotfiles repository).
- Quick Start contains: ```setup.sh` reads `packages/arch.txt` and `dotfiles/` from the same checkout. Running the script from the cloned repository is the supported bootstrap path.`` This replaces the current sentence; the existing local-checkout validator pattern (`setup.sh … reads … packages/arch.txt … same checkout … supported bootstrap path`) must still match, so keep `reads`, `packages/arch.txt`, `same checkout`, `supported bootstrap path` in that order within one paragraph.
- Update flow contains `git pull` and `chezmoi apply`.
- Scope line contains `Arch Linux (WSL or VM)` and `only supported`.

### validate-readme.ps1 changes (UPDATE)

Remove: the `Two-repo architecture explanation` required check; `'DOTFILES_REPO' = $null` in `$setupValuesToBlock`.

Add required checks (label → pattern):

| Label | Pattern |
| --- | --- |
| `in-repo dotfiles explanation` | `(?is)dotfiles/.{0,40}\bpart of\b.{0,10}config-v2` |
| `dotfiles read from the same checkout` | `(?is)setup\.sh.{0,40}reads.{0,60}packages/arch\.txt.{0,20}and.{0,20}dotfiles/.{0,60}same checkout` |
| `Arch Linux only statement` | `(?is)Arch Linux \(WSL or VM\).{0,80}only supported` |
| `update flow` | `(?is)git pull.{0,200}chezmoi apply` |
| `Verification section` | `(?im)^##\s+Verification\s*$` |
| `verification stage tags` | each of `[packages]`, `[stateful]`, `[dotfiles]`, `[shell]`, `[editor]` appears (literal, `[regex]::Escape`) |
| `verification failure signal` | `ERROR: \[<stage>\]` written as `[regex]::Escape('ERROR: [<stage>]')` |
| `Not Supported Yet section` | `(?im)^##\s+Not Supported Yet\s*$` and its body (up to the next `##`) matches `(?i)windows` and `(?i)other (linux )?distro` |
| `Public-Safe Rules section` | `(?im)^##\s+Public-Safe Rules\s*$` and its body matches `(?i)secret` and `(?i)test fixture` |

Add forbidden checks: `DOTFILES_REPO` (`Pattern = 'DOTFILES_REPO'`), `separate dotfiles repository` (`(?i)\b(separate|second|own) dotfiles repo`), `two-repo model` (`(?i)two-repo`), generic `dotfiles repo` (`(?i)\bdotfiles repo\b`, which guards the old "the dotfiles repo owns…" wording). The `separate|second|own dotfiles repo` pattern also matches "separate dotfiles repository", so the README must not even negate it that way; write "there is no second repository for dotfiles" instead.

Use the existing helper shape (`$requiredChecks` with `Label`/`Pattern`, `$forbiddenReadmeChecks`, and the `Path Ownership` section parser as a template for the section-body checks). Keep failure messages in the existing style (`Missing README requirement: <Label>.` / `README still contains a <Label>.`). Keep PowerShell 5.1 compatible (the suite runs under Windows PowerShell).

### Architecture Compliance (MUST FOLLOW)

| Decision | What it means here |
| --- | --- |
| AD-1 | Docs say `dotfiles/` lives in `config-v2` and is applied from the checkout; no second repository as the supported path. |
| AD-3 | Docs state the repository-root, local-checkout execution contract and the clear failure when assets are missing. |
| AD-4 / NFR1 | README stays public-safe; no setup.sh config value is repeated; fixture-safety rules are explicit. |
| AD-5 | Leave `## Path Ownership` untouched; verification adds no path. |
| AD-6 | Docs describe verification as a first-class final stage, automatic and standalone (`--verify`). |
| AD-7 | Arch-only; other targets are "Not Supported Yet", not described as available. |
| AD-9 | Bootstrap order in the README matches the fixed `setup.sh` order. |

### File Structure Requirements

| Path | Action |
| --- | --- |
| `README.md` | UPDATE |
| `tests/validate-readme.ps1` | UPDATE |
| `_bmad-output/implementation-artifacts/2-5-…md`, `sprint-status.yaml` | status/record updates only |
| `setup.sh`, `tests/verify-setup.sh`, `tests/validate-setup.ps1`, `tests/validate-dotfiles.ps1`, `tests/validate-wsl-test-ca.ps1`, `tests/lib/**`, `dotfiles/**`, `packages/arch.txt`, `.gitattributes`, planning artifacts | DO NOT MODIFY |

### Testing Requirements

Run under **Windows PowerShell**, sequentially (the WSL-backed ones share the `config-v2-test` instance name):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\validate-readme.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests\validate-setup.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests\validate-dotfiles.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests\validate-wsl-test-ca.ps1
```

- `validate-readme.ps1` is the real test for this story (seconds). The other three are a regression check only; run them once at the end.
- Never touch other WSL distros (currently `archlinux`), not even read-only. List `wsl -l -q` before/after.
- Red first: run the updated validator against the old README and record the failing lines in the Debug Log before rewriting the README.
- For each mutation, copy the README to a temp path, mutate the copy, and point a temp copy of the validator at it (or temporarily swap and restore the file); record the red line, then discard. Leave the working tree with only the intended changes.
- The README validator parses `setup.sh` assignments with a line regex; it runs without WSL.

### Previous Story Intelligence

- **Story 2.4:** added README step 5 and the `./setup.sh --verify` sentence and two validator checks (`documented verify-only command`, `smoke verification bootstrap step`); told this story to replace step 4 wording and Architecture Overview. Review (2026-11-06) deferred: Neovim headless check has no timeout, an empty SSH key file passes, command list duplicates the manifest. Do not document verification as stronger than it is: say "presence and parse checks", not "proves everything works".
- **Story 2.3:** the `## Path Ownership` table is parsed by the validator (exactly one row per listed path, exactly one category per row). Write `$SSH_KEY_FILE`, never the literal default path. Deferred README work for this story: "deferred scope text" and two-repo wording.
- **Story 2.6:** README must not contain `setup.ps1`, `packages/ubuntu.txt|scoop.txt|winget.txt`, or a `Windows Companion Bootstrap` heading. Windows and other distros may be named as deferred.
- **Story 2.2:** `chezmoi init --apply` persists `sourceDir` via `dotfiles/.chezmoi.toml.tmpl`; this is why plain `chezmoi apply` works later and why a moved checkout needs a rerun of `./setup.sh`.

### Git Intelligence

- `bf8468e feat: add smoke verification to the bootstrap (Story 2.4)` is the baseline for `README.md` and `tests/validate-readme.ps1`. Earlier commits: `6e880c2` (2.3), `91ec6cf` (2.6).
- Commit convention: `feat: …`/`docs: …` summary with `(Story 2.5)` and the `Co-authored-by` trailer.

### Latest Technical Information

- **chezmoi v2.73** (WSL test instance): after `chezmoi init --apply` with a `sourceDir` set in the generated `chezmoi.toml`, plain `chezmoi apply` and `chezmoi verify` use that source dir; `chezmoi update` would run `git pull` in the source directory's repo (here the whole checkout) and then apply. The README may mention `chezmoi update` as an alternative only if it keeps the two-step wording (`git pull`, then `chezmoi apply`) as the primary documented path.
- No new tools or libraries.

### Project Structure Notes

- No `project-context.md`. Authoritative context: `epics.md` (Story 2.5), the 2026-08-07 spine (AD-1, AD-3, AD-4, AD-6, AD-7, AD-9; "Spec and README refresh is Epic 2 Story 2.5"), readiness report 2026-10-07 (Major #3 sync path; documentation stories acceptable), sprint-change-proposal 2026-10-29 (Arch-only, "listed as deferred"), Stories 2.1 to 2.4 and 2.6, and the current `README.md` and validator.
- Single-developer public repo; the user-facing surface is console output plus this README (no UI).

### References

- [epics.md: Story 2.5](../planning-artifacts/epics.md)
- [ARCHITECTURE-SPINE.md (2026-08-07): AD-1, AD-3, AD-4, AD-5, AD-6, AD-7, AD-9](../planning-artifacts/architecture/architecture-config-v2-dotfiles-integration-2026-08-07/ARCHITECTURE-SPINE.md)
- [implementation-readiness-report-2026-10-07.md: Major #3 (ongoing sync path), minor #7](../planning-artifacts/implementation-readiness-report-2026-10-07.md)
- [sprint-change-proposal-2026-10-29.md](../planning-artifacts/sprint-change-proposal-2026-10-29.md)
- [2-4-add-smoke-verification-for-integrated-bootstrap.md](./2-4-add-smoke-verification-for-integrated-bootstrap.md), [2-3-preserve-stateful-asset-safety-in-the-integrated-flow.md](./2-3-preserve-stateful-asset-safety-in-the-integrated-flow.md), [deferred-work.md](./deferred-work.md)
- [README.md](../../README.md), [tests/validate-readme.ps1](../../tests/validate-readme.ps1), [setup.sh](../../setup.sh), [tests/verify-setup.sh](../../tests/verify-setup.sh), [dotfiles/.chezmoi.toml.tmpl](../../dotfiles/.chezmoi.toml.tmpl)

## Dev Agent Record

### Agent Model Used

AI assistant (Copilot SDK in VS Code), dev-story workflow

### Debug Log References

- Red phase: updated `validate-readme.ps1` against the old README failed on all 16 expected points (in-repo explanation, same-checkout sentence, Arch-only statement, update flow, Verification section, failure signal, five stage tags, Not Supported Yet, Public-Safe Rules, separate-repo, two-repo and dotfiles-repo wording).
- First run also hit a PowerShell bug in the new section parser (`$(` inside a double-quoted pattern); fixed by building the pattern with string concatenation.
- Green: after the README rewrite the validator failed once on `tests\validate-setup.ps1` in the new Validation section, because the existing `setup\.ps1` forbid was an unanchored substring match. Tightened it to `(?<![\w-])setup\.ps1`; `./setup.ps1` is still caught (mutation g).
- Mutations on a temp copy of README and validator, all red: (a) separate dotfiles repo wording, (b) `DOTFILES_REPO`, (c) no Verification section, (d) no Not Supported Yet, (e) no `git pull` flow, (f) GPG fingerprint pasted in, (g) `./setup.ps1` and a `## Windows Companion Bootstrap` heading, (h) no Public-Safe Rules. Temp files removed.
- Regression: `validate-setup.ps1`, `validate-dotfiles.ps1`, `validate-wsl-test-ca.ps1` passed; `wsl -l -q` shows only `archlinux` before and after.

### Completion Notes List

- README now describes the one-repo model: `dotfiles/` is part of `config-v2`, the same-checkout contract (`packages/arch.txt` and `dotfiles/`, actionable failure, no root), an "Updating an existing machine" flow (`git pull`, then `chezmoi apply`, moved-checkout note), a `## Verification` section with stage table, `## Public-Safe Rules`, `## Not Supported Yet` (Windows, other distros), a one-repo Architecture Overview and a maintainer `## Validation` list. `## Path Ownership` is unchanged.
- `validate-readme.ps1`: removed the two-repo check and the dead `DOTFILES_REPO` entry; added required checks (in-repo, same checkout, Arch-only, update flow, Verification section, failure signal, stage tags, Not Supported Yet and Public-Safe Rules section bodies) and forbidden checks (`DOTFILES_REPO`, separate/second dotfiles repo, two-repo, dotfiles repo).
- Decision: the `setup.ps1` forbid was anchored so validator file names such as `validate-setup.ps1` are not flagged. This is test-only and keeps the intent.
- No production script or dotfile changed.

### File List

- `README.md` (modified)
- `tests/validate-readme.ps1` (modified)
- `_bmad-output/implementation-artifacts/2-5-refresh-arch-linux-documentation-and-readme-validation.md` (modified: status/record)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified: status)

## Change Log

- 2026-11-06: Story created (ready-for-dev).
- 2026-11-06: README rewritten for the in-repo, Arch-only model and `validate-readme.ps1` assertions replaced. Status → review.
- 2026-11-09: Code review: 11 patches applied (README and validate-readme.ps1), 1 deferred to deferred-work.md. Status → done.
