{ pkgs, ... }:
{
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true; # `gamescope` session at SDDM for HDR/VRR
    protontricks.enable = true;
    # Keep firewall closed: Remote Play / local transfer open ports — opt in if used.
    remotePlay.openFirewall = false;
    localNetworkGameTransfers.openFirewall = false;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

  programs.gamemode = {
    enable = true;
    settings.general.renice = 10;
  };

  programs.gamescope.enable = true;

  environment.systemPackages = with pkgs; [
    mangohud
    lutris
    heroic
  ];

  # Steam needs this for some titles; harmless otherwise.
  boot.kernel.sysctl."vm.max_map_count" = 2147483642;
}
