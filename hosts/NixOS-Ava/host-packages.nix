{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    obsidian
    ludusavi # For game saves
    protonvpn-gui # VPN
    github-desktop
    # pokego # Overlayed
    # claude-code
    gimp
    rusty-path-of-building
    protonup-qt
    protonplus
  ];
}
