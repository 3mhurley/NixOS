{ config, ... }:
{
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # required for Steam/Proton
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # Open kernel module — required for Turing+ (RTX 20xx and newer),
    # set false for GTX 10xx and older.
    open = true;
    modesetting.enable = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest;

    powerManagement.enable = true;
    # powerManagement.finegrained + prime.* only matter on laptops — add if needed.
  };
}
