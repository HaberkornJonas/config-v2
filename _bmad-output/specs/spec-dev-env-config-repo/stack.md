# Tech Stack

Full tool catalog for the reproducible dev-environment setup. Every item here is a binding decision that downstream implementation must respect.

## Shell

| Layer | Tool |
|---|---|
| Shell | `zsh` |

## Dotfiles management

| Layer | Tool |
|---|---|
| Dotfile manager | `chezmoi` — owns all user config, templating, and conflict/state handling |

## Linux package management

| Distro | Manifest |
|---|---|
| Arch | `packages/arch.txt` |
| Ubuntu | `packages/ubuntu.txt` |

## Dev runtime

| Layer | Tool |
|---|---|
| Node version manager | `fnm` |
| Frontend framework | Angular |
| Backend framework | C# / .NET |
| Containerisation | Docker + Docker Compose |
| Editor | Neovim |
| Terminal multiplexer | tmux |

## zsh plugins / prompt

| Purpose | Tool |
|---|---|
| Plugin manager | `zinit` |
| Autosuggestions | `zsh-autosuggestions` |
| Syntax highlighting | `fast-syntax-highlighting` |
| Fuzzy-completion UI | `fzf-tab` |
| Directory jumping | `zoxide` |
| Prompt | `starship` |

## Windows companion

| Layer | Tool |
|---|---|
| Entrypoint | `setup.ps1` |
| Package managers | Scoop, winget |

## Scripting convention

- `config.sh` (`KEY=value`) is the single source of truth for all script parameters; scripts read it rather than accepting interactive input.
- `setup.sh` / `setup.ps1` orchestrate only; they do not own software installs or dotfile state.
