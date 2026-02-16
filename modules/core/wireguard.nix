{ host, lib, pkgs, ... }:
let
  vars = import ../../hosts/${host}/variables.nix;
  wgIf = "wg0";
  wgKeyFile = "/etc/wireguard/protonvpn-private.key";
  getentBin = "${pkgs.getent}/bin/getent";
  wgAutostart = vars.wgAutostart or false;
  wgKillSwitch = vars.wgKillSwitch or false;
  wgBypassDomains = vars.wgBypassDomains or [ ];
  wgPresharedKeyFile = vars.wgPresharedKeyFile or "";
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
    # Keep WG control plane in systemd; avoid NM creating/activating its own WG profile.
    networkmanager.unmanaged = lib.optional vars.wgEnable "interface-name:${wgIf}";

    wireguard.interfaces.${wgIf} = lib.mkIf vars.wgEnable {
      ips = [ vars.wgAddress ];
      privateKeyFile = wgKeyFile;
      # Keep endpoint reachability outside the tunnel to avoid recursive routing failures.
      postSetup = ''
        WAN_GW=$(${pkgs.iproute2}/bin/ip -4 route show default | ${pkgs.gawk}/bin/awk '$5 != "${wgIf}" && $3 != "" {print $3; exit}')
        WAN_IF=$(${pkgs.iproute2}/bin/ip -4 route show default | ${pkgs.gawk}/bin/awk '$5 != "${wgIf}" {print $5; exit}')
        if [ -n "$WAN_GW" ] && [ -n "$WAN_IF" ]; then
          ${pkgs.iproute2}/bin/ip -4 route replace ${wgEndpointHost}/32 via "$WAN_GW" dev "$WAN_IF"
          # Optional split-tunnel bypasses for domains that break behind VPN exits.
          for domain in ${lib.escapeShellArgs wgBypassDomains}; do
            for ip in $(${getentBin} ahostsv4 "$domain" | ${pkgs.gawk}/bin/awk '{print $1}' | ${pkgs.coreutils}/bin/sort -u); do
              ${pkgs.iproute2}/bin/ip -4 route replace "$ip/32" via "$WAN_GW" dev "$WAN_IF"
            done
          done
        fi
      '';
      postShutdown = ''
        ${pkgs.iproute2}/bin/ip -4 route del ${wgEndpointHost}/32 2>/dev/null || true
        for domain in ${lib.escapeShellArgs wgBypassDomains}; do
          for ip in $(${getentBin} ahostsv4 "$domain" | ${pkgs.gawk}/bin/awk '{print $1}' | ${pkgs.coreutils}/bin/sort -u); do
            ${pkgs.iproute2}/bin/ip -4 route del "$ip/32" 2>/dev/null || true
          done
        done
      '';
      peers = [
        (
          {
            publicKey = vars.wgServerPublicKey;
            endpoint = vars.wgServerEndpoint;
            allowedIPs = [ "0.0.0.0/0" ];
            persistentKeepalive = 25;
          }
          // lib.optionalAttrs (wgPresharedKeyFile != "") {
            presharedKeyFile = wgPresharedKeyFile;
          }
        )
      ];
    };

    firewall = {
      # Do not open inbound 51820 for ProtonVPN client mode.
      allowedUDPPorts = [ ];
      extraCommands = lib.mkIf (vars.wgEnable && wgKillSwitch) ''
        # Kill switch: only allow local/tailscale/wg egress, plus Proton endpoint handshake.
        ${pkgs.iptables}/bin/iptables -I OUTPUT -d ${wgEndpointHost} -p udp --dport ${wgEndpointPort} -j ACCEPT
        ${pkgs.iptables}/bin/iptables -I OUTPUT ! -o ${wgIf} ! -o tailscale0 \
          -m addrtype ! --dst-type LOCAL -j REJECT
        ${pkgs.iptables}/bin/ip6tables -I OUTPUT ! -o ${wgIf} ! -o tailscale0 \
          -m addrtype ! --dst-type LOCAL -j REJECT
      '';
      extraStopCommands = lib.mkIf (vars.wgEnable && wgKillSwitch) ''
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

  # `networking.wireguard.interfaces` does not expose an autostart toggle on this channel.
  # Control boot behavior by adjusting the generated systemd unit links.
  systemd.services."wireguard-${wgIf}" = lib.mkIf (vars.wgEnable && !wgAutostart) {
    wantedBy = lib.mkForce [ ];
  };

  environment.systemPackages = with pkgs; [ wireguard-tools ];

  warnings = lib.optional (!vars.wgEnable) ''
    Proton WireGuard is disabled for host "${host}". Set wgEnable = true in hosts/${host}/variables.nix after filling wg values.
  '';
}
