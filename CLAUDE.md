# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a modular, flake-based NixOS configuration with support for multiple hosts. The system uses a variables-driven approach where each host defines its preferences (desktop environment, applications, hardware) in a `variables.nix` file, and modules are dynamically imported based on these variables.

## Build and Rebuild Commands

**System rebuild (primary method):**
```bash
rebuild
```
Custom script that automatically updates hardware configuration, sets username, and rebuilds the system using the current host's flake configuration.

**Initial installation:**
```bash
./install.sh
```
Interactive installer that guides through host selection/creation, generates hardware config, and performs initial system build.

**Rollback to previous generation:**
```bash
rollback
```
Lists previous system generations and allows rolling back.

**Format Nix files:**
```bash
nix fmt
```
Uses `nixfmt-tree` as defined in flake outputs.

**Clean old generations:**
The system uses `nh` (nix-helper) which automatically cleans generations older than 7 days, keeping at least 3 most recent. Configuration in `modules/core/nh.nix`.

## Architecture

### Host Configuration System

Hosts are defined in `hosts/<hostname>/`:
- `configuration.nix` - Imports modules for the host
- `variables.nix` - Defines host preferences (desktop, terminal, editor, browser, video driver, etc.)
- `host-packages.nix` - Host-specific packages
- `hardware-configuration.nix` - Auto-generated hardware config

The variables system allows dynamic module loading:
```nix
modules/desktop/${vars.desktop}          # hyprland, i3, gnome, plasma6
modules/hardware/video/${vars.videoDriver}.nix  # nvidia, amdgpu, intel
modules/programs/browser/${vars.browser}  # zen, firefox, floorp
modules/programs/terminal/${vars.terminal}  # kitty, alacritty
modules/programs/editor/${vars.editor}    # nixvim, vscode, helix, doom-emacs, nvchad, neovim
```

### Module Organization

**modules/core/** - Essential system modules that rarely change:
- `users.nix` - Home-manager integration, user configuration, session variables
- `boot.nix`, `hardware.nix`, `network.nix` - Core system settings
- `nh.nix` - Nix-helper configuration (flake path: `/home/${username}/NixOS`)
- `packages.nix`, `services.nix`, `security.nix` - System-wide configs
- `games.nix` - Gaming-related packages, conditionally loaded via `vars.games`

**modules/desktop/** - Window managers/desktop environments (hyprland, i3, gnome, plasma6)

**modules/hardware/** - Hardware-specific configurations:
- `video/` - GPU driver configs (nvidia, amdgpu, intel)
- `drives/` - Automatic mounting of external/internal drives

**modules/programs/** - Application configurations split by category:
- `browser/`, `terminal/`, `editor/` - Main applications
- `cli/` - Terminal tools (yazi, lf, tmux, direnv, lazygit, btop, cava, fastfetch)
- `media/` - Media apps (discord, spicetify, youtube-music, thunderbird, obs-studio, mpv)
- `misc/` - Utilities (tlp, thunar, lact for GPU control)

**modules/scripts/** - Custom shell scripts packaged as Nix derivations:
- Scripts are defined in individual files and collected in `default.nix`
- Each script is a `pkgs.writeShellScriptBin` derivation
- Available scripts: `rebuild`, `rollback`, `launcher`, `network`, `tmux-sessionizer`, `extract`, `driverinfo`, `underwatt`

**modules/themes/** - Appearance configurations for desktop environments

### Flake Structure

The flake uses a `mkHost` function that:
1. Loads the host's `configuration.nix` from `hosts/<hostname>/`
2. Passes special arguments: `self`, `inputs`, `outputs`, `host`, and `overlays`
3. Overlays are imported from `overlays/default.nix` with host-specific context

**Key flake inputs:**
- `nixpkgs` (unstable) and `nixpkgs-stable` (25.11)
- `home-manager` - User environment management
- `plasma-manager` - KDE Plasma configuration
- `spicetify-nix` - Spotify theming
- `nixvim` - Neovim configuration as flake
- `nix-doom-emacs-unstraightened` - Doom Emacs
- `zen-browser`, `betterfox`, `thunderbird-catppuccin` - Application configurations

### Home Manager Integration

Home-manager is imported as a NixOS module in `modules/core/users.nix`:
- `useGlobalPkgs = true` - Uses system nixpkgs
- `useUserPackages = true` - Installs packages to user profile
- Session variables (`EDITOR`, `BROWSER`, `TERMINAL`) are set based on `variables.nix`
- User home state version: 23.11

Many modules use `home-manager.sharedModules` to configure user-level settings (see `bash.nix`, `starship.nix`, `games.nix`).

## Development Shells

The `dev-shells/` directory contains flake templates for 40+ languages and frameworks. Each provides a development environment with language-specific tools and dependencies.

**Usage:**
```bash
nix flake init -t .#<language>  # Initialize from template
nix develop                     # Enter the dev shell
```

Available templates defined in `dev-shells/default.nix`.

## Adding New Hosts

1. **Via install script:**
   ```bash
   ./install.sh
   # Select "n" to create new host, choose template, edit variables
   ```

2. **Manual process:**
   - Copy existing host: `cp -r hosts/Default hosts/NewHost`
   - Update `hostname` in `hosts/NewHost/variables.nix`
   - Add to `flake.nix` in `nixosConfigurations`
   - Generate hardware config: `nixos-generate-config --show-hardware-config > hosts/NewHost/hardware-configuration.nix`

## Creating New Modules

1. Create module file in appropriate directory (`modules/core/`, `modules/programs/`, etc.)
2. Add import to host's `configuration.nix` or `modules/default.nix`
3. For variable-driven modules, reference: `inherit (import ../../hosts/${host}/variables.nix) variableName;`
4. For home-manager configs, use: `home-manager.sharedModules = [ { ... } ];`

**Example script module:**
```nix
# modules/scripts/myscript.nix
{ pkgs, ... }:
pkgs.writeShellScriptBin "myscript" ''
  #!/usr/bin/env bash
  echo "My custom script"
''
```
Then add `(import ./myscript.nix scriptArgs)` to `modules/scripts/default.nix`.

## Logging

Error logs are stored in `logging/` directory (not tracked in git). Used for debugging boot and application issues.

## Important Notes

- The flake path is hardcoded to `/home/${username}/NixOS` in `modules/core/nh.nix`
- The `rebuild` script automatically updates the username in `variables.nix` to the current user
- Hardware configuration is regenerated on every `rebuild` from `/etc/nixos/hardware-configuration.nix`
- The system uses `nixos-unstable` channel by default, with `nixos-25.11` available as `nixpkgs-stable`
- When modifying variables that change module imports, a rebuild is required
