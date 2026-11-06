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

checks=0
failed=0
failed_stages=()
pass() { checks=$((checks + 1)); echo "INFO: [$1] OK: $2"; }
fail() {
  checks=$((checks + 1))
  failed=$((failed + 1))
  [[ " ${failed_stages[*]-} " == *" $1 "* ]] || failed_stages+=("$1")
  echo "ERROR: [$1] $2" >&2
}
warn() { echo "WARN: [$1] $2"; }

# [packages] manifest entries installed, key commands on PATH
while IFS= read -r line || [[ -n "$line" ]]; do
  pkg="${line%%#*}"
  pkg="${pkg//[[:space:]]/}"
  [[ -n "$pkg" ]] || continue
  if pacman -Q "$pkg" >/dev/null 2>&1; then pass packages "package $pkg installed"
  else fail packages "Package '$pkg' from packages/arch.txt is not installed. Rerun ./setup.sh or run: sudo pacman -S --needed $pkg"; fi
done < "$REPO_ROOT/packages/arch.txt"
for cmd in chezmoi git zsh nvim tmux starship zoxide fzf docker dotnet; do
  if command -v "$cmd" >/dev/null 2>&1; then pass packages "command $cmd on PATH"
  else fail packages "Command '$cmd' is not on PATH. Check packages/arch.txt and rerun ./setup.sh."; fi
done

# [stateful] fnm, SSH key, login shell; GPG is warn-only (import is manual by design)
if [[ -x "$FNM_DIR/fnm" ]]; then pass stateful "fnm installed at $FNM_DIR"
else fail stateful "fnm is not installed at $FNM_DIR. Rerun ./setup.sh (it installs fnm when missing)."; fi

if [[ -f "$SSH_KEY_FILE" ]]; then pass stateful "SSH key $SSH_KEY_FILE present"
elif [[ -f "$SSH_KEY_FILE.pub" ]]; then fail stateful "Found $SSH_KEY_FILE.pub without its private key. Restore the private key or remove the .pub file, then rerun ./setup.sh."
else fail stateful "SSH key $SSH_KEY_FILE is missing. Rerun ./setup.sh to generate it."; fi

user="$(id -un)"
login_shell="$(getent passwd "$user" | cut -d: -f7)"
login_shell="$(basename "${login_shell:-none}")"
if [[ "$login_shell" == "zsh" ]]; then pass stateful "login shell for $user is zsh"
else fail stateful "Login shell for $user is $login_shell, not zsh. Run: sudo chsh -s \"\$(command -v zsh)\" $user, then start a new login session."; fi

if [[ -n "$GPG_FINGERPRINT" ]]; then
  # gpg creates its home directory on first use, so only query it when it already exists (read-only).
  if [[ -d "${GNUPGHOME:-$HOME/.gnupg}" ]] && gpg --list-keys "$GPG_FINGERPRINT" >/dev/null 2>&1; then pass stateful "GPG key $GPG_FINGERPRINT in keyring"
  else warn stateful "GPG key $GPG_FINGERPRINT is not in your keyring; commit signing will fail until you import it."; fi
fi

# [dotfiles] chezmoi source is this checkout, no drift, every managed target exists
expected_source="$REPO_ROOT/dotfiles"
source_path="$(chezmoi source-path 2>&1)"
if [[ "$source_path" == "$expected_source" ]]; then pass dotfiles "chezmoi source is $expected_source"
else fail dotfiles "chezmoi source is ${source_path:-unknown}, expected $expected_source. Rerun ./setup.sh from this checkout."; fi

if chezmoi verify >/dev/null 2>&1; then pass dotfiles "managed dotfiles match dotfiles/"
else fail dotfiles "Managed dotfiles differ from dotfiles/ (chezmoi verify). Inspect with chezmoi diff, then rerun ./setup.sh."; fi

if managed="$(chezmoi managed --include=files --path-style absolute 2>&1)"; then
  while IFS= read -r target; do
    [[ -n "$target" ]] || continue
    if [[ -f "$target" ]]; then pass dotfiles "managed file $target present"
    else fail dotfiles "Managed file $target is missing. Rerun ./setup.sh."; fi
  done <<< "$managed"
else
  fail dotfiles "Could not list managed files (chezmoi managed): ${managed%%$'\n'*}. Rerun ./setup.sh from this checkout."
fi

# [shell] zsh entrypoint parses
zshrc="$HOME/.zshrc"
if [[ -f "$zshrc" ]] && zsh_error="$(zsh -n "$zshrc" 2>&1)"; then pass shell "~/.zshrc parses"
else
  [[ -f "$zshrc" ]] || zsh_error="file not found"
  fail shell "~/.zshrc is missing or has a zsh syntax error: ${zsh_error%%$'\n'*}. Rerun ./setup.sh to restore the managed version."
fi

# [editor] Neovim loads the managed init.lua without errors (-i NONE: no shada write)
expected_vimrc="${XDG_CONFIG_HOME:-$HOME/.config}/nvim/init.lua"
if nvim_out="$(nvim --headless -i NONE -c 'lua io.stdout:write(vim.env.MYVIMRC or "")' -c 'qa!' 2>&1)" && [[ "$nvim_out" == "$expected_vimrc" ]]; then
  pass editor "Neovim loads $expected_vimrc"
else
  fail editor "Neovim did not load $expected_vimrc: ${nvim_out:-no config loaded}. Rerun ./setup.sh to restore the managed config."
fi

if (( failed > 0 )); then
  echo "ERROR: Verification failed: $failed of $checks checks failed (stages: ${failed_stages[*]})." >&2
  exit 1
fi
echo "INFO: Verification passed ($checks checks)."
