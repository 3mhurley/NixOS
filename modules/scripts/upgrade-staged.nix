{ pkgs, ... }:
pkgs.writeShellScriptBin "upgrade-staged" ''
  set -euo pipefail

  FLAKE_DIR="''${1:-$HOME/NixOS}"
  HOST="''${2:-NixOS-Ava}"

  run() {
    echo
    echo "==> $*"
    "$@"
  }

  pause_step() {
    read -r -p "Continue? [y/N] " ans
    [[ "''${ans:-}" =~ ^[Yy]$ ]]
  }

  if [ ! -d "$FLAKE_DIR" ]; then
    echo "Flake directory not found: $FLAKE_DIR"
    exit 1
  fi

  if [ ! -f "$FLAKE_DIR/flake.nix" ]; then
    echo "No flake.nix found in: $FLAKE_DIR"
    exit 1
  fi

  cd "$FLAKE_DIR"

  run git status --short
  run nix flake check --no-build

  echo
  echo "Batch A: core platform"
  run nix flake lock --update-input nixpkgs
  run nix flake lock --update-input nixpkgs-stable
  run nix flake lock --update-input home-manager
  run nix flake lock --update-input nix-index-database
  run nix flake check --no-build
  run sudo nixos-rebuild boot --flake ".#$HOST"
  echo "Reboot recommended now for kernel validation."
  pause_step || exit 0

  echo
  echo "Batch B: module ecosystem"
  run nix flake lock --update-input nix-flatpak
  run nix flake lock --update-input plasma-manager
  run nix flake lock --update-input zen-browser
  run nix flake lock --update-input spicetify-nix
  run nix flake lock --update-input nixvim
  run nix flake lock --update-input nvchad4nix
  run nix flake lock --update-input nur
  run nix flake check --no-build
  run sudo nixos-rebuild switch --flake ".#$HOST"
  pause_step || exit 0

  echo
  echo "Batch C: non-flake repos"
  run nix flake lock --update-input nix-doom-emacs-unstraightened
  run nix flake lock --update-input doom-config
  run nix flake lock --update-input neovim
  run nix flake lock --update-input betterfox
  run nix flake lock --update-input thunderbird-catppuccin
  run nix flake check --no-build
  run sudo nixos-rebuild switch --flake ".#$HOST"

  echo
  echo "Flatpak pass"
  run sudo flatpak update -y
  run sudo flatpak uninstall --unused -y

  echo
  echo "Done. Review and commit:"
  echo "  git diff -- flake.lock"
  echo "  git add flake.lock && git commit -m 'chore(upgrade): staged flake input refresh'"
''
