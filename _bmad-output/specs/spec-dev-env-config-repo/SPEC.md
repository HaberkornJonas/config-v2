---
id: SPEC-dev-env-config-repo
companions:
  - stack.md
sources:
  - ../../brainstorming/brainstorm-dev-env-config-repo-2026-08-04/brainstorm-intent.md
---

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate. Source documents listed in frontmatter are for traceability only — consult them only if you need narrative rationale or prose color this contract intentionally omits.

# Reproducible Dev Environment Config

## Why

A developer working across multiple Linux machines (WSL/VM on Arch and Ubuntu) wastes significant time and effort re-configuring environments from scratch. The existing toolchain (chezmoi, zsh, fnm, Neovim, tmux, and a curated plugin set) is well-chosen but lacks a reproducible local bootstrap flow and a reliable sync mechanism. This spec realizes a single-repo setup — `config-v2` holds bootstrap orchestration, package manifests, and the `chezmoi` source tree under `dotfiles/` — so that any fresh machine can reach a fully configured, usable dev state by installing Git manually, cloning this repo, and running `setup.sh` locally, while any existing machine can be kept in sync with the same local script.

## Capabilities

- **CAP-1**
  - **intent:** User can bootstrap a fresh Linux (Arch or Ubuntu) dev environment from zero by manually installing Git, cloning `config-v2`, and running the local `setup.sh`.
  - **success:** On a fresh machine with no prior configuration, cloning the repository and executing `./setup.sh` from that checkout produces a fully configured, usable dev environment; the run exits cleanly.

- **CAP-2**
  - **intent:** User can apply and sync dotfiles across machines via `chezmoi`, using the in-repo `dotfiles/` tree of the local `config-v2` checkout as the single source.
  - **success:** Running `chezmoi apply` on any registered machine reaches the same dotfile state as the source; idempotent across repeated runs.

- **CAP-3**
  - **intent:** User can re-run setup to update or sync an existing environment without destroying stateful assets.
  - **success:** Re-running setup on a previously configured machine reflects the latest config state, exits without errors, and leaves existing SSH keys and secrets untouched.

- **CAP-4**
  - **intent:** User can bootstrap a Windows companion environment via `setup.ps1` using Scoop and winget.
  - **success:** Running `setup.ps1` on a fresh Windows machine installs the defined Windows tool set without manual steps beyond the initial script invocation.

## Constraints

- **Public repo:** No secrets are stored; only safe references (e.g. GPG key fingerprint) are permitted in the repository.
- **Linux-first targets:** WSL/VM on Arch and Ubuntu are the primary targets. Per-distro package manifests (`packages/arch.txt`, `packages/ubuntu.txt`) are required; Arch and Ubuntu differ materially in package names and repo setup (e.g. Docker, .NET).
- **Same Git identity across machines:** a single identity is configured and must be consistent everywhere.
- **Fully silent/non-interactive once the local checkout is ready:** Linux bootstrap configuration lives at the top of `setup.sh`; no interactive prompts occur once the user has cloned the repo and started the script.
- **Non-destructive for stateful assets:** existing SSH keys must be preserved on every re-run; setup must detect and skip rather than overwrite.
- **Ownership model:** package managers own software installs; `chezmoi` owns dotfiles, templating, and conflict/state handling; `setup.sh` / `setup.ps1` orchestrate only. Host-only concerns (e.g. Nerd Fonts installation) live on a post-install checklist outside the repo.
- **Single-repo, split ownership:** `config-v2` holds bootstrap logic, package manifests, and all `chezmoi`-managed user config under `dotfiles/`. Ownership stays split by concern (orchestrators sequence, package managers install, `chezmoi` applies). Tracked `dotfiles/` content must be safe to use as a repeatable bootstrap test fixture.
- **Always overwrite managed config on apply:** repo-owned files are applied as-is; no soft merges for managed config.
- **No global npm packages; no project-specific tools in global machine config.** See `stack.md` for the full tool catalog.

## Non-goals

- Full Windows/WSL2 auto-bootstrap through Linux user creation.
- Ansible-based provisioning.
- YubiKey-backed SSH as a required path for initial setup.
- Secrets storage in the repository beyond safe references.
- Mac support (future evaluation only).

## Success signal

A developer on a fresh Arch or Ubuntu machine (WSL or VM) manually installs Git, clones the repository, runs `./setup.sh`, waits for completion, and has a fully configured, usable dev environment — correct shell, plugins, editor, runtime, and dotfiles in place. The same developer re-runs setup on an existing machine a week later and the environment updates cleanly, SSH keys intact.

Setup ends with a repo-local smoke verification that confirms the environment is usable, not just that the script exited 0.
## Assumptions

- `zsh` is the target shell on all Linux machines; no alternative shell support is required.
- Single developer / single Git identity; multi-user or team scenarios are not in scope.

## Open Questions

- YubiKey SSH bridge in WSL/VM: feasibility and integration path — noted for future evaluation, not blocking.
- CI coverage beyond Ubuntu: currently out of scope; scope and trigger conditions undefined.
- Mac support: path and priority undefined; flagged as future evaluation only.
