{ config, lib, ... }:
{
  # WireGuard tunnel to your own VPS / commercial endpoint (Tailscale covers
  # device-to-device; this covers exit traffic). Disabled until you fill in
  # the endpoint + keys, then set enable = true.
  options.my.wireguard.enable = lib.mkEnableOption "WireGuard exit tunnel";

  config = lib.mkIf config.my.wireguard.enable {
    networking.wg-quick.interfaces.wg0 = {
      address = [ "10.100.0.2/32" ];
      privateKeyFile = config.sops.secrets.wireguard-private-key.path;
      dns = [ "10.100.0.1" ];

      peers = [
        {
          publicKey = "SERVER_PUBLIC_KEY_HERE";
          endpoint = "vpn.example.com:51820";
          allowedIPs = [ "0.0.0.0/0" "::/0" ]; # full tunnel
          persistentKeepalive = 25;
        }
      ];
    };
  };
}
