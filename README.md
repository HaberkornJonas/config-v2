# config-v2

`config-v2` is the bootstrap repository for bringing up an Arch Linux development machine (WSL or VM) from a local checkout.

## Linux Quick Start

Install Git manually first, then clone this repository and run the Linux bootstrap from the local checkout:

```bash
# Arch
pacman -Syu
pacman -S git
```

```bash
git clone https://github.com/HaberkornJonas/config-v2.git
cd config-v2
chmod +x ./setup.sh
./setup.sh
```

`setup.sh` carries its bootstrap configuration inline. If you need different values in your own copy or fork, update the configuration block at the top of `setup.sh` before you run that variant.

`setup.sh` reads `packages/arch.txt` from the same checkout. Running the script from the cloned repository is the supported bootstrap path.

### What the Linux bootstrap does

The Linux entry point is `setup.sh` in your local checkout. The script then:

1. loads the bootstrap configuration declared at the top of the script
2. checks that the host is Arch Linux and installs packages from `packages/arch.txt` in this repository
3. runs `chezmoi init --apply` to apply your user configuration from the separate dotfiles repo

## Architecture Overview

This project follows a strict two-repo model:

- `config-v2` owns bootstrap orchestration, inline bootstrap configuration, and package manifests
- the dotfiles repo owns user configuration managed by chezmoi

That split keeps bootstrap orchestration in this repo while letting `setup.sh` delegate user configuration application to chezmoi.
