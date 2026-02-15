{ pkgs, ... }:
pkgs.writeShellScriptBin "flake-update-input" ''
  set -euo pipefail

  FLAKE_DIR="''${FLAKE_DIR:-$PWD}"

  if [ "''${1:-}" = "--flake-dir" ]; then
    if [ -z "''${2:-}" ]; then
      echo "Missing directory after --flake-dir"
      echo "Usage: flake-update-input [--flake-dir <dir>] <input> [input ...]"
      exit 1
    fi
    FLAKE_DIR="$2"
    shift 2
  fi

  if [ "$#" -lt 1 ]; then
    echo "Usage: flake-update-input [--flake-dir <dir>] <input> [input ...]"
    echo "Example: flake-update-input nixpkgs home-manager"
    exit 1
  fi

  if [ ! -d "$FLAKE_DIR" ]; then
    echo "Flake directory not found: $FLAKE_DIR"
    exit 1
  fi

  if [ ! -f "$FLAKE_DIR/flake.nix" ]; then
    echo "No flake.nix found in: $FLAKE_DIR"
    exit 1
  fi

  cd "$FLAKE_DIR"

  for input in "$@"; do
    echo "Updating input: $input"
    nix flake update "$input"
  done
''
