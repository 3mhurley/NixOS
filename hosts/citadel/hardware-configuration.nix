{ lib, ... }:
# PLACEHOLDER — replace with the file generated on the target machine:
#   nixos-generate-config --show-hardware-config > hosts/citadel/hardware-configuration.nix
# Then delete the filesystem stubs below (real ones come from the generated file
# or disks.nix).
{
  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" "kvm-amd" ];

  # Stubs so `nix flake check` passes before install:
  fileSystems."/" = lib.mkDefault {
    device = "/dev/mapper/cryptroot";
    fsType = "ext4";
  };
  fileSystems."/boot" = lib.mkDefault {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
  };

  nixpkgs.hostPlatform = "x86_64-linux";
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault true;
}
