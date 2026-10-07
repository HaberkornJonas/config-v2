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

# --- (1) Preflight: target user, sudo, local checkout (AD-3, AD-9). No mutation before this passes. ---
if [[ "$EUID" -eq 0 ]]; then
  echo "ERROR: Do not run setup.sh as root. Run it as the user you are setting up; it calls sudo for system commands." >&2
  exit 1
fi
if ! command -v sudo >/dev/null 2>&1; then
  echo "ERROR: sudo is required. Install sudo and grant your user sudo rights, then rerun ./setup.sh." >&2
  exit 1
fi
# chezmoi would git-init dotfiles/ if the checkout were not a git working tree.
require_repo_asset_path ".git" >/dev/null
require_repo_asset_path "dotfiles/.chezmoi.toml.tmpl" >/dev/null

# --- (2) Detect distro exactly once (AD-7) ---
# shellcheck source=/dev/null
. /etc/os-release
DISTRO="${ID:-}"

case "$DISTRO" in
  arch) require_repo_asset_path "packages/arch.txt" >/dev/null ;;
  ubuntu) require_repo_asset_path "packages/ubuntu.txt" >/dev/null ;;
esac

# --- (3) Install packages; only system commands run through sudo ---
if [[ "$DISTRO" == "arch" ]]; then
  echo "INFO: Detected Arch Linux — installing packages via pacman."
  sudo pacman -S --needed --noconfirm - < "$(require_repo_asset_path "packages/arch.txt")"

elif [[ "$DISTRO" == "ubuntu" ]]; then
  echo "INFO: Detected Ubuntu — adding required apt repositories before package install."

  # Prerequisites for apt over HTTPS
  sudo apt-get install -y ca-certificates curl gnupg lsb-release

  # Docker CE: GPG key + apt repo
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  # Microsoft apt repo: GPG key + repo
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | sudo gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg
  sudo chmod a+r /etc/apt/keyrings/microsoft.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] \
https://packages.microsoft.com/repos/microsoft-ubuntu-$(lsb_release -cs)-prod $(lsb_release -cs) main" \
    | sudo tee /etc/apt/sources.list.d/microsoft.list > /dev/null

  echo "INFO: Installing packages via apt."
  sudo apt-get update
  sudo xargs -a "$(require_repo_asset_path "packages/ubuntu.txt")" apt-get install -y

else
  echo "ERROR: Unsupported distro '$DISTRO'. Supported distros: arch, ubuntu." >&2
  exit 1
fi

if ! command -v chezmoi >/dev/null 2>&1; then
  echo "ERROR: chezmoi is not installed after the package stage. Check the $DISTRO package manifest and package manager output." >&2
  exit 1
fi

# --- (4) User-level installs and stateful assets, run as the target user (no sudo) ---
# fnm via the official curl installer (both distros)
echo "INFO: Installing fnm via official curl installer."
curl -fsSL https://fnm.vercel.app/install | bash

# --- SSH key: detect-before-mutate (AC 4, 5, 8, AD-4, AD-7) ---
# NOTE: ~/.ssh/config is chezmoi-managed — never written here (AD-7)
if [[ -f "$SSH_KEY_FILE" ]]; then
  echo "INFO: SSH key already exists at $SSH_KEY_FILE — skipping generation."
else
  echo "INFO: Generating SSH key at $SSH_KEY_FILE."
  mkdir -p "$(dirname "$SSH_KEY_FILE")"
  ssh-keygen -t rsa -b 4096 -C "$GIT_USER_EMAIL" -f "$SSH_KEY_FILE" -N ""
fi

# --- GPG key: detect-before-mutate (AC 6, 8, AD-4) ---
if gpg --list-keys "$GPG_FINGERPRINT" &>/dev/null; then
  echo "INFO: GPG key $GPG_FINGERPRINT already registered — skipping."
else
  echo "INFO: GPG key $GPG_FINGERPRINT not found in keyring — please import it manually or via your dotfiles."
fi

# --- (5) Apply managed dotfiles from the local checkout (AD-1, AD-8, AD-9) ---
# dotfiles/.chezmoi.toml.tmpl persists sourceDir, so later plain `chezmoi apply` uses this checkout.
if [[ -d "${HOME}/.local/share/chezmoi" ]]; then
  echo "INFO: Leaving legacy chezmoi source at ~/.local/share/chezmoi untouched; config now points at $REPO_ROOT/dotfiles."
fi
echo "INFO: Applying dotfiles from $REPO_ROOT/dotfiles via chezmoi."
env GIT_USER_NAME="$GIT_USER_NAME" GIT_USER_EMAIL="$GIT_USER_EMAIL" GPG_FINGERPRINT="$GPG_FINGERPRINT" \
  chezmoi init --apply --force --no-tty --source "$(require_repo_asset_path "dotfiles")"

echo "INFO: Bootstrap complete."
