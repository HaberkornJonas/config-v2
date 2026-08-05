# Brainstorm Implementation Tasks

## Phase 1: Foundation
- [ ] Create a shared `config.sh` at the repo root with pre-filled `KEY=value` settings for the common Git identity, GPG signing key fingerprint/thumbprint, repo URLs, and any machine-level toggles both `setup.sh` and `setup.ps1` need.
- [ ] Create a fully non-interactive `setup.sh` entry point that sources `config.sh`, uses `set -euo pipefail`, and supports both first-time bootstrap and repeat update/sync runs.
- [ ] Make `setup.sh` non-destructive for secrets and always-overwrite for managed config: keep an existing SSH key if present, but always re-apply tracked configuration.
- [ ] Detect the target distro in `setup.sh` and route package installation through distro-specific functions instead of one shared package list.
- [ ] Split Linux packages into `packages/arch.txt` and `packages/ubuntu.txt` so Arch/Ubuntu naming differences are handled explicitly.
- [ ] Keep ownership boundaries strict: `config-v2` owns bootstrap/orchestration and package manifests only; the separate dotfiles repo owns shell/editor/terminal config via chezmoi.

## Phase 2: Linux Setup
- [ ] Add the shared Linux development tool set to the distro package manifests, including Git, curl, zsh, tmux, Neovim, Docker, Docker Compose, ripgrep, fd (`fd`/`fd-find`), bat (`bat`/`batcat`), eza, fzf, zoxide, starship, and GPG support where needed.
- [ ] Add Ubuntu-specific repository/bootstrap steps before package install so Docker and .NET packages come from the correct upstream repositories.
- [ ] Add Arch-specific package installation flow that maps the same tool set to Arch package names without introducing Ubuntu-only assumptions.
- [ ] Install `chezmoi` as part of Linux bootstrap and have `setup.sh` run `chezmoi init --apply <dotfiles-repo>` so dotfile deployment is handled by chezmoi instead of custom copy logic.
- [ ] Install `fnm` via its curl-based installer instead of `nvm`, then wire shell startup to use `fnm` for per-project Node version switching.
- [ ] Configure the default shell change in a WSL-safe way by using `usermod` for zsh instead of relying on `chsh`.
- [ ] Add Docker post-install user setup (group membership) and emit a clear reminder that a relogin/new session is required before Docker works without `sudo`.
- [ ] Generate a fresh SSH key only when one does not already exist, and skip key creation on machines that already have an SSH key.
- [ ] Do not pin a fast-aging global .NET SDK version in the bootstrap; install .NET from the distro/upstream channel strategy chosen above.

## Phase 3: Windows Setup
- [ ] Create `setup.ps1` that reads the same `config.sh` values with PowerShell-native parsing so Windows and Linux bootstrap share one config source.
- [ ] Use `setup.ps1` to bootstrap Windows-side packages with Scoop and winget for the host environment needed around the Linux setup flow.
- [ ] Keep Windows setup focused on host preparation only; do not automate WSL distro creation or Linux user creation since that interactive step was explicitly dropped.
- [ ] Prepare Windows-side terminal/profile assets to be managed through the dotfiles repo so host shell experience stays in sync with Linux-managed dotfiles.

## Phase 4: Dotfiles
- [ ] Create the separate public dotfiles repo in chezmoi layout and make it the single owner of tracked dotfiles and local change/conflict handling.
- [ ] Add a chezmoi-managed `.zshrc` that initializes zinit, `zsh-autosuggestions`, `fast-syntax-highlighting`, `fzf-tab`, `zoxide`, `starship`, and `eval "$(fnm env --use-on-cd)"`.
- [ ] Add a chezmoi-managed Git config/template that applies the shared Git identity and GPG signing key fingerprint from `config.sh`.
- [ ] Add a Neovim config that lets `lazy.nvim` self-bootstrap from `init.lua` without a separate manual install step.
- [ ] Add a tmux config plus a chezmoi `run_once_` script that bootstraps TPM exactly once per machine.
- [ ] Add Windows Terminal settings and a PowerShell profile to the dotfiles repo so Windows host configuration is deployed by chezmoi too.

## Phase 5: Polish
- [ ] Add a curl one-liner bootstrap path that can clone/bootstrap silently with pre-filled `config.sh` and the `chezmoi init --apply` flow.
- [ ] Add a minimal README that answers the Persona Journey gaps: what to run first, whether `config.sh` needs editing, how long setup roughly takes, where the post-install checklist lives, and that dotfiles changes should be pushed back to the dotfiles repo.
- [ ] Add a user-level systemd service/timer that performs the confirmed nightly `chezmoi update` flow.
- [ ] Verify the bootstrap stays intentionally light: no project-specific tooling, no global npm packages, and no extra personal/gaming setup.

## Post-Install Checklist
- [ ] Install a Nerd Font on the host OS and select it in the terminal emulator (for example Windows Terminal) so starship/eza/icon-capable tooling renders correctly.
- [ ] Start a new login session after the Docker group change before testing Docker without `sudo`.
- [ ] Start a new shell/session after the zsh default-shell change so the expected shell environment is actually active.
- [ ] Confirm chezmoi has applied the dotfiles repo successfully, then push any intentional local dotfile improvements back to the dotfiles repo.

## Future / Out of Scope
- YubiKey as SSH agent via `gpg-agent` (`enable-ssh-support`) and bridging into WSL/VMs.
- Automatic WSL2 install + distro handoff from PowerShell.
- Mac support.
- GitHub Actions validation for `setup.sh`.
- Arch CI coverage beyond Ubuntu-based validation.
