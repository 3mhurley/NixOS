{ pkgs, ... }:
{
  # KDE Plasma 6 on Wayland
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.desktopManager.plasma6.enable = true;

  # Audio: PipeWire
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  services.printing.enable = false; # enable if you print
  hardware.bluetooth.enable = true;

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-emoji
  ];

  environment.systemPackages = with pkgs; [
    firefox
    kdePackages.kate
  ];

  # Trim Plasma bloat
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    elisa
    khelpcenter
  ];
}
