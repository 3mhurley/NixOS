{ host, pkgs, ... }:
pkgs.writeShellScriptBin "rebuild" ''
  set -euo pipefail
  # Colors for output
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  NC='\033[0m' # No Color

  if [[ $EUID -eq 0 ]]; then
    echo "This script should not be executed as root! Exiting..."
    exit 1
  fi

  if [ -f "$HOME/NixOS/flake.nix" ]; then
    flake=$HOME/NixOS
  elif [ -f "/etc/nixos/flake.nix" ]; then
    flake=/etc/nixos
  else
    echo "Error: flake not found. ensure flake.nix exists in either $HOME/NixOS or /etc/nixos"
    exit 1
  fi
  echo -e "''${GREEN}Flake: $flake''${NC}"
  echo -e "''${GREEN}Host: ${host}''${NC}"
  currentUser="$(id -un)"

  # Escape replacement string for sed (handles / and & safely)
  escapedUser=$(printf '%s\n' "$currentUser" | sed 's/[\/&]/\\&/g')

  # replace username variable in variables.nix with $USER
  sudo sed -i -e "s|username = \".*\"|username = \"$escapedUser\"|" "$flake/hosts/${host}/variables.nix"

  if [ -f "/etc/nixos/hardware-configuration.nix" ]; then
    cat "/etc/nixos/hardware-configuration.nix" | sudo tee "$flake/hosts/${host}/hardware-configuration.nix" >/dev/null
  else
    sudo nixos-generate-config --show-hardware-config >"$flake/hosts/${host}/hardware-configuration.nix" || {
      echo -e "''${RED}Failed to generate hardware config''${NC}"
      exit 1
    }
  fi

  sudo git -C "$flake" add hosts/${host}/hardware-configuration.nix

  # nh os switch --hostname "${host}"
  sudo nixos-rebuild switch --impure --flake "$flake#${host}"

  echo
  read -rsn1 -p"$(echo -e "''${GREEN}Press any key to continue''${NC}")"
''
