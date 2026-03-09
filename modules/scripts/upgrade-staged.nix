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

  check_host() {
    run nix eval --raw ".#nixosConfigurations.''${HOST}.config.system.build.toplevel.drvPath"
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
  check_host

  echo
  echo "Batch A: core platform"
  run nix flake update nixpkgs
  run nix flake update nixpkgs-stable
  run nix flake update home-manager
  run nix flake update nix-index-database
  check_host
  run sudo nixos-rebuild boot --flake ".#$HOST"
  echo "Reboot recommended now for kernel validation."
  pause_step || exit 0

  echo
  echo "Batch B: module ecosystem"
  run nix flake update nix-flatpak
  run nix flake update plasma-manager
  run nix flake update zen-browser
  run nix flake update spicetify-nix
  run nix flake update nixvim
  run nix flake update nvchad4nix
  run nix flake update nur
  check_host
  run sudo nixos-rebuild switch --flake ".#$HOST"
  pause_step || exit 0

  echo
  echo "Batch C: non-flake repos"
  run nix flake update nix-doom-emacs-unstraightened
  run nix flake update doom-config
  run nix flake update neovim
  run nix flake update betterfox
  run nix flake update thunderbird-catppuccin
  check_host
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
