# Managed by chezmoi from config-v2/dotfiles. Local edits are overwritten on apply.
# Shared, POSIX-sh environment for every shell (zsh, bash, sh), interactive or not.
# Sourced by ~/.zshrc, ~/.bashrc and ~/.profile so agents running /bin/bash get the same tools as zsh.
# Keep it fast and side-effect free: PATH and exports only, no output, safe to source repeatedly.

_config_v2_path_prepend() {
  if [ -d "$1" ]; then
    case ":$PATH:" in
      *":$1:"*) ;;
      *) PATH="$1:$PATH" ;;
    esac
  fi
}

# Homebrew on Apple silicon macOS (what `brew shellenv` sets, without spawning brew).
# Prepended first so that user-local binaries and fnm below take precedence over it.
if [ -x /opt/homebrew/bin/brew ]; then
  export HOMEBREW_PREFIX=/opt/homebrew
  export HOMEBREW_CELLAR=/opt/homebrew/Cellar
  export HOMEBREW_REPOSITORY=/opt/homebrew
  _config_v2_path_prepend /opt/homebrew/sbin
  _config_v2_path_prepend /opt/homebrew/bin
fi

# User-local binaries (uv, pipx and other per-user installers).
_config_v2_path_prepend "$HOME/.local/bin"

# fnm (installed by setup.sh; must match FNM_DIR there). The default alias exposes node/npm/npx
# without `fnm env`, so non-interactive shells work; interactive zsh layers `fnm env --use-on-cd` on top.
_config_v2_fnm_dir="${XDG_DATA_HOME:-$HOME/.local/share}/fnm"
_config_v2_path_prepend "$_config_v2_fnm_dir/aliases/default/bin"
_config_v2_path_prepend "$_config_v2_fnm_dir"
export PATH

unset _config_v2_fnm_dir
unset -f _config_v2_path_prepend

export EDITOR=nvim
export VISUAL=nvim
export COLORTERM=truecolor
export DOTNET_CLI_TELEMETRY_OPTOUT=1
