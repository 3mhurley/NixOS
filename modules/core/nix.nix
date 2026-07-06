{ ... }:
{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    # Only root and wheel can talk to the daemon.
    allowed-users = [ "@wheel" ];
    trusted-users = [ "root" ];
    auto-optimise-store = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  nixpkgs.config.allowUnfree = true; # NVIDIA driver, Steam
}
