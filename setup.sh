#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Bootstrap configuration ---
GIT_USER_NAME="Jonas Haberkorn"
GIT_USER_EMAIL="jonas@haberkorn.fr"
GPG_FINGERPRINT="CA09410D7AD0C086893352466E118DFA78A27A9F"
SSH_KEY_FILE="${HOME}/.ssh/id_rsa"

# Prints the absolute path of a required repo-local asset, or exits with an actionable error (AD-3).
require_repo_asset_path() {
  local relative_path="$1"
  local absolute_path="$REPO_ROOT/$relative_path"
  if [[ ! -e "$absolute_path" ]]; then
    echo "ERROR: Missing $relative_path relative to setup.sh. Install Git manually, clone config-v2 locally, and run ./setup.sh from that checkout." >&2
    exit 1
  fi
  printf '%s\n' "$absolute_path"
}

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

# --- (1) Preflight: target user, sudo, Arch-only guard, local checkout (AD-3, AD-7, AD-9). No mutation before this passes. ---
if [[ "$EUID" -eq 0 ]]; then
  echo "ERROR: Do not run setup.sh as root. Run it as the user you are setting up; it calls sudo for system commands." >&2
  exit 1
fi
if ! command -v sudo >/dev/null 2>&1; then
  echo "ERROR: sudo is required. Install sudo and grant your user sudo rights, then rerun ./setup.sh." >&2
  exit 1
fi

# Read ID in a subshell so os-release fields cannot overwrite script variables (AD-7).
# A malformed file yields an empty ID and falls through to the actionable error below.
DISTRO=""
if [[ -r /etc/os-release ]]; then
  # shellcheck source=/dev/null
  DISTRO="$(. /etc/os-release >/dev/null 2>&1; printf '%s' "${ID:-}")" || DISTRO=""
fi
if [[ "$DISTRO" != "arch" ]]; then
  echo "ERROR: Unsupported distro '${DISTRO:-unknown}': only Arch Linux is supported (/etc/os-release must have ID=arch). Run ./setup.sh on an Arch Linux machine (WSL or VM)." >&2
  exit 1
fi

# chezmoi would git-init dotfiles/ if the checkout were not a git working tree.
require_repo_asset_path ".git" >/dev/null
require_repo_asset_path "dotfiles/.chezmoi.toml.tmpl" >/dev/null
require_repo_asset_path "packages/arch.txt" >/dev/null
require_repo_asset_path "tests/verify-setup.sh" >/dev/null

# Derived values (not configuration, AD-8). FNM_DIR is passed to verification, so it must be set before the verify-only branch.
TARGET_USER="$(id -un)"
# Must match the fnm path in dotfiles/dot_zshrc.
FNM_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fnm"

if [[ "$VERIFY_ONLY" == true ]]; then
  run_smoke_verification
  echo "INFO: Verification complete; nothing was changed."
  exit 0
fi

# --- (2) Install packages via pacman; only system commands run through sudo (AD-7) ---
echo "INFO: Detected Arch Linux — installing packages via pacman."
sudo pacman -S --needed --noconfirm - < "$(require_repo_asset_path "packages/arch.txt")"

if ! command -v chezmoi >/dev/null 2>&1; then
  echo "ERROR: chezmoi is not installed after the package stage. Check packages/arch.txt and the pacman output." >&2
  exit 1
fi

if ! command -v zsh >/dev/null 2>&1; then
  echo "ERROR: zsh is not installed after the package stage. Check packages/arch.txt and the pacman output." >&2
  exit 1
fi

# --- (3) Stateful assets: detect before mutate, never chezmoi-managed (AD-5; README "Path Ownership") ---
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
elif [[ -f "$SSH_KEY_FILE.pub" ]]; then
  echo "INFO: Found $SSH_KEY_FILE.pub without its private key — skipping generation so the public key is not overwritten. Restore the private key or remove the .pub file, then rerun ./setup.sh."
else
  echo "INFO: Generating SSH key at $SSH_KEY_FILE."
  mkdir -p -m 700 "$(dirname "$SSH_KEY_FILE")"
  ssh-keygen -t rsa -b 4096 -C "$GIT_USER_EMAIL" -f "$SSH_KEY_FILE" -N ""
fi

# GPG key: checked only, never written by setup.sh.
if gpg --list-keys "$GPG_FINGERPRINT" &>/dev/null; then
  echo "INFO: GPG key $GPG_FINGERPRINT already registered — skipping."
else
  echo "INFO: GPG key $GPG_FINGERPRINT not found in keyring — please import it manually or via your dotfiles."
fi

# --- (4) Apply managed dotfiles from the local checkout (AD-1, AD-8, AD-9) ---
# dotfiles/.chezmoi.toml.tmpl persists sourceDir, so later plain `chezmoi apply` uses this checkout.
if [[ -d "${HOME}/.local/share/chezmoi" ]]; then
  echo "INFO: Leaving legacy chezmoi source at ~/.local/share/chezmoi untouched; config now points at $REPO_ROOT/dotfiles."
fi
echo "INFO: Applying dotfiles from $REPO_ROOT/dotfiles via chezmoi."
env GIT_USER_NAME="$GIT_USER_NAME" GIT_USER_EMAIL="$GIT_USER_EMAIL" GPG_FINGERPRINT="$GPG_FINGERPRINT" \
  chezmoi init --apply --force --no-tty --source "$(require_repo_asset_path "dotfiles")"

# --- (5) Smoke verification (AD-6, AD-9): setup succeeds only when the machine is verified usable (NFR7) ---
run_smoke_verification

echo "INFO: Bootstrap complete."
