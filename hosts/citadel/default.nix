{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disks.nix

    ../../modules/core
    ../../modules/security
    ../../modules/network
    ../../modules/hardware/nvidia.nix
    ../../modules/desktop
    ../../modules/gaming
    ../../modules/dev
  ];

  networking.hostName = "citadel";

  # Do not change after install — governs stateful data formats.
  system.stateVersion = "26.05";
}
