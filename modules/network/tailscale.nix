{ config, ... }:
{
  services.tailscale = {
    enable = true;
    # Auth key from sops — node joins the tailnet automatically.
    # Generate at https://login.tailscale.com/admin/settings/keys
    authKeyFile = config.sops.secrets.tailscale-authkey.path;
    extraUpFlags = [
      "--ssh" # Tailscale SSH: key distribution + access controlled by tailnet ACLs
    ];
    openFirewall = true; # UDP 41641 for direct (non-DERP) connections
  };

  # Trusted interface is declared in firewall.nix.
}
