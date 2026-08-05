# Intent: Reproducible Dev Environment Config

## Project goal
- Minimize time and manual effort to spin up a fresh development environment across multiple machines.
- Support repeatable setup and ongoing sync/update with the same toolchain and configs.

## Scope constraints
- Public repo approach.
- Software development use only; no personal or gaming setup.
- Linux-first target environments: WSL/VM on Arch and Ubuntu; multi-PC use.
- Same Git identity across machines.

## Architecture decisions
- Two-repo split:
  - `config-v2`: bootstrap/setup logic, package installation, OS-specific provisioning.
  - `dotfiles`: all user config managed by `chezmoi`.
- Ownership model:
  - `setup.sh` / `setup.ps1` orchestrate only.
  - Package managers own software installs.
  - `chezmoi` owns dotfiles, templating, and conflict/state handling.
  - Manual post-install checklist covers host-side items outside Linux repo control.
- Shared config file: `config.sh` (`KEY=value`) as the single source of truth for scripts.
- Setup must be fully silent/non-interactive once config is prepared.
- Bootstrap target: curl one-liner leading into `chezmoi init --apply`.

## Tech stack
- Shell: `zsh`
- Dotfiles manager: `chezmoi`
- Node: `fnm`
- Dev stack: Angular, C#/.NET, Docker + Compose, Neovim, tmux, modern terminal config
- Windows companion bootstrap: `setup.ps1` with Scoop + winget
- Package manifests split by distro (`packages/arch.txt`, `packages/ubuntu.txt`)
- zsh tooling: zinit, zsh-autosuggestions, fast-syntax-highlighting, fzf-tab, zoxide, starship

## Key design principles
- Keep setup light; avoid over-configuration.
- Non-destructive for secrets/stateful assets (e.g. keep existing SSH keys if present).
- Always overwrite managed config.
- Script should work for both first-time install and update/sync.
- Project-specific tools stay in project repos, not global machine config.
- No global npm packages.

## Explicitly out of scope
- Full Windows/WSL2 auto-bootstrap through Linux user creation.
- Ansible-based provisioning.
- YubiKey-backed SSH as a required path for initial setup.
- Secrets storage in repo beyond safe references such as GPG key fingerprint.

## Critical discoveries
- `chezmoi` solves dotfile deployment, machine-specific templating, and conflict/state tracking better than custom shell logic.
- Public repo is viable because key material can stay local/hardware-backed; repo mainly stores config and safe identifiers.
- Host-only concerns such as Nerd Fonts must remain on a post-install checklist.
- Ubuntu package/repo setup differs materially from Arch (e.g. package names, Docker/.NET repo setup), so per-distro manifests are required.

## Open questions
- None blocking. Future evaluation: YubiKey SSH bridge in WSL/VM, Mac support, and CI coverage beyond Ubuntu.
