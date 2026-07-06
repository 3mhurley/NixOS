{ pkgs, lib, ... }:
{
  # Secure Boot via lanzaboote (replaces systemd-boot once keys are enrolled).
  # First boot uses systemd-boot; see README for sbctl key enrollment.
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # Latest kernel: best for recent NVIDIA GPUs + game performance.
  # (linux_hardened costs real gaming perf; hardening is done via sysctls instead.)
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.tmp.useTmpfs = true;

  environment.systemPackages = [ pkgs.sbctl ];
}
