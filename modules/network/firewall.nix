{ ... }:
{
  # nftables-backed firewall, deny-by-default inbound.
  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];

    # Trust the tailnet only — SSH etc. live here, never on the LAN/WAN.
    trustedInterfaces = [ "tailscale0" ];

    # Don't answer pings from the LAN/WAN
    allowPing = false;

    logRefusedConnections = false; # set true when debugging
  };
}
