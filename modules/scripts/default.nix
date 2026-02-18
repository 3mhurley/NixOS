{
  pkgs,
  lib,
  host,
  config,
  ...
}:
let
  inherit (import ../../hosts/${host}/variables.nix) terminal;
in
let
  # Define your custom args once
  scriptArgs = {
    inherit
      host
      pkgs
      lib
      config
      terminal
      ;
  };

  scripts = [
    (import ./rebuild.nix scriptArgs)
    (import ./rollback.nix scriptArgs)
    (import ./launcher.nix scriptArgs)
    (import ./network.nix scriptArgs)
    (import ./tmux-sessionizer.nix scriptArgs)
    (import ./extract.nix scriptArgs)
    (import ./driverinfo.nix scriptArgs)
    (import ./underwatt.nix scriptArgs)
    (import ./update-all.nix scriptArgs)
    (import ./upgrade-staged.nix scriptArgs)
    (import ./flake-update-input.nix scriptArgs)
    (pkgs.writeShellScriptBin "wg-toggle" ''
      set -euo pipefail

      iface="''${1:-wg0}"
      unit="wg-quick-''${iface}"

      run_systemctl() {
        if [ "''${EUID}" -eq 0 ]; then
          systemctl "$@"
        else
          sudo systemctl "$@"
        fi
      }

      if systemctl is-active --quiet "''${unit}"; then
        echo "Stopping ''${unit}..."
        run_systemctl stop "''${unit}"
      else
        echo "Starting ''${unit}..."
        run_systemctl start "''${unit}"
      fi

      if systemctl is-active --quiet "''${unit}"; then
        echo "WireGuard status: ACTIVE (''${unit})"
      else
        echo "WireGuard status: INACTIVE (''${unit})"
      fi
    '')
    # Add new scripts here as you create them
  ];
in
{
  environment.systemPackages = scripts;
}
