{ ... }:
{
  imports = [
    ./firewall.nix
    ./tailscale.nix
    ./wireguard.nix
    ./dns.nix
  ];

  networking.networkmanager = {
    enable = true;
    wifi.macAddress = "random"; # MAC randomization on Wi-Fi
  };
}
