{ host, lib, pkgs, ... }:
let
  vars = import ../../hosts/${host}/variables.nix;
  wgIf = "wg0";
  wgKeyFile = "/etc/wireguard/protonvpn-private.key";
  wgEndpointHost = lib.head (lib.splitString ":" vars.wgServerEndpoint);
  wgEndpointPort = lib.last (lib.splitString ":" vars.wgServerEndpoint);
in
{
  assertions = [
    {
      assertion =
        !vars.wgEnable
        || (vars.wgAddress != "" && vars.wgServerPublicKey != "" && vars.wgServerEndpoint != "");
      message = "wgEnable is true, but wgAddress/wgServerPublicKey/wgServerEndpoint are not fully set in hosts/${host}/variables.nix.";
    }
  ];

  networking = {
    # Keep DNS pinned to local AdGuard -> Unbound chain.
    nameservers = [ "127.0.0.1" ];
    networkmanager.dns = "none";

    wireguard.interfaces.${wgIf} = lib.mkIf vars.wgEnable {
      ips = [ vars.wgAddress ];
      privateKeyFile = wgKeyFile;
      peers = [
        {
          publicKey = vars.wgServerPublicKey;
          endpoint = vars.wgServerEndpoint;
          allowedIPs = [ "0.0.0.0/0" ];
          persistentKeepalive = 25;
        }
      ];
    };

    firewall = {
      # Do not open inbound 51820 for ProtonVPN client mode.
      allowedUDPPorts = [ ];
      extraCommands = lib.mkIf vars.wgEnable ''
        # Kill switch: only allow local/tailscale/wg egress, plus Proton endpoint handshake.
        ${pkgs.iptables}/bin/iptables -I OUTPUT -d ${wgEndpointHost} -p udp --dport ${wgEndpointPort} -j ACCEPT
        ${pkgs.iptables}/bin/iptables -I OUTPUT ! -o ${wgIf} ! -o tailscale0 \
          -m addrtype ! --dst-type LOCAL -j REJECT
        ${pkgs.iptables}/bin/ip6tables -I OUTPUT ! -o ${wgIf} ! -o tailscale0 \
          -m addrtype ! --dst-type LOCAL -j REJECT
      '';
      extraStopCommands = lib.mkIf vars.wgEnable ''
        ${pkgs.iptables}/bin/iptables -D OUTPUT -d ${wgEndpointHost} -p udp --dport ${wgEndpointPort} -j ACCEPT || true
        ${pkgs.iptables}/bin/iptables -D OUTPUT ! -o ${wgIf} ! -o tailscale0 \
          -m addrtype ! --dst-type LOCAL -j REJECT || true
        ${pkgs.iptables}/bin/ip6tables -D OUTPUT ! -o ${wgIf} ! -o tailscale0 \
          -m addrtype ! --dst-type LOCAL -j REJECT || true
      '';
    };
  };

  # Coexist with strict global rp_filter from security.nix.
  boot.kernel.sysctl."net.ipv4.conf.${wgIf}.rp_filter" = lib.mkIf vars.wgEnable 2;

  environment.systemPackages = with pkgs; [ wireguard-tools ];

  warnings = lib.optional (!vars.wgEnable) ''
    Proton WireGuard is disabled for host "${host}". Set wgEnable = true in hosts/${host}/variables.nix after filling wg values.
  '';
}
