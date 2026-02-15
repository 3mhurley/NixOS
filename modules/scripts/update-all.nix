{ host, pkgs, ... }:
pkgs.writeShellScriptBin "update-all" ''
  set -euo pipefail

  FLAKE_DIR="''${1:-$HOME/NixOS}"
  DO_CLEANUP="''${2:-yes}"

  if [ ! -d "$FLAKE_DIR" ]; then
    echo "Flake directory not found: $FLAKE_DIR"
    echo "Usage: update-all [flake-dir] [yes|no]"
    exit 1
  fi

  if [ ! -f "$FLAKE_DIR/flake.nix" ]; then
    echo "No flake.nix found in: $FLAKE_DIR"
    exit 1
  fi

  echo "Updating flake inputs in: $FLAKE_DIR"
  nix flake update --flake "$FLAKE_DIR"

  echo "Applying NixOS configuration for host: ${host}"
  sudo nixos-rebuild switch --flake "$FLAKE_DIR#${host}"

  if command -v flatpak >/dev/null 2>&1; then
    echo "Updating Flatpak packages"
    sudo flatpak update -y

    if [ "$DO_CLEANUP" = "yes" ]; then
      echo "Removing unused Flatpak runtimes and extensions"
      sudo flatpak uninstall --unused -y
    fi
  else
    echo "Flatpak is not installed; skipping Flatpak update steps"
  fi

  echo "Update completed successfully"
''
