#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Bootstrap configuration ---
DOTFILES_REPO="git@github.com:HaberkornJonas/dotfiles.git"
GIT_USER_NAME="Jonas Haberkorn"
GIT_USER_EMAIL="jonas@haberkorn.fr"
GPG_FINGERPRINT="CA09410D7AD0C086893352466E118DFA78A27A9F"
SSH_KEY_FILE="${HOME}/.ssh/id_rsa"

# --- (1) Detect distro exactly once (AC 2, AD-5) ---
# shellcheck source=/dev/null
. /etc/os-release
DISTRO="${ID:-}"

# --- (2) Install packages (AC 3) ---
if [[ "$DISTRO" == "arch" ]]; then
  echo "INFO: Detected Arch Linux — installing packages via pacman."
  pacman -S --needed --noconfirm - < ./packages/arch.txt

elif [[ "$DISTRO" == "ubuntu" ]]; then
  echo "INFO: Detected Ubuntu — adding required apt repositories before package install."

  # Prerequisites for apt over HTTPS
  apt-get install -y ca-certificates curl gnupg lsb-release

  # Docker CE: GPG key + apt repo (AC 12)
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null

  # Microsoft apt repo: GPG key + repo (AC 12)
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg
  chmod a+r /etc/apt/keyrings/microsoft.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] \
https://packages.microsoft.com/repos/microsoft-ubuntu-$(lsb_release -cs)-prod $(lsb_release -cs) main" \
    | tee /etc/apt/sources.list.d/microsoft.list > /dev/null

  echo "INFO: Installing packages via apt."
  apt-get update
  xargs -a ./packages/ubuntu.txt apt-get install -y

else
  echo "ERROR: Unsupported distro '$DISTRO'. Supported distros: arch, ubuntu." >&2
  exit 1
fi

# --- Post-package: install fnm via curl (AC 13, both distros) ---
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

# --- (3) chezmoi init --apply (AC 1, 7, 8, AD-2, AD-9) ---
echo "INFO: Running chezmoi init --apply."
chezmoi init --apply "$DOTFILES_REPO"

echo "INFO: Bootstrap complete."
