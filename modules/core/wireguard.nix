{
  host,
  lib,
  pkgs,
  ...
}:
let
  vars = import ../../hosts/${host}/variables.nix;
  wgIf = "wg0";
  wgKeyFile = "/etc/wireguard/protonvpn-private.key";
  getentBin = "${pkgs.getent}/bin/getent";
  wgAutostart = vars.wgAutostart or false;
  wgKillSwitch = vars.wgKillSwitch or false;
  wgBypassDomains = vars.wgBypassDomains or [ ];
  wgPresharedKeyFile = vars.wgPresharedKeyFile or "";
  wgEndpointHost = if vars.wgEnable then lib.head (lib.splitString ":" vars.wgServerEndpoint) else "";
  wgEndpointPort = if vars.wgEnable then lib.last (lib.splitString ":" vars.wgServerEndpoint) else "";
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
    # Keep WG control plane in systemd; avoid NM creating/activating its own WG profile.
    networkmanager.unmanaged = lib.optional vars.wgEnable "interface-name:${wgIf}";

    wireguard.interfaces.${wgIf} = lib.mkIf vars.wgEnable {
      ips = [ vars.wgAddress ];
      privateKeyFile = wgKeyFile;
      # Keep endpoint reachability outside the tunnel to avoid recursive routing failures.
      postSetup = ''
                BYPASS_FILE="/run/wireguard-bypass-ips"
                read -r WAN_GW WAN_IF <<EOF
        $(${pkgs.iproute2}/bin/ip -4 route show default | ${pkgs.gawk}/bin/awk '
          $1 == "default" {
            via = ""; dev = "";
            for (i = 1; i <= NF; i++) {
              if ($i == "via") via = $(i + 1);
              if ($i == "dev") dev = $(i + 1);
            }
            if (via != "" && dev != "" && dev != "${wgIf}" && dev != "tailscale0") {
              print via, dev;
              exit;
            }
          }
        ')
        EOF
                if [ -n "$WAN_GW" ] && [ -n "$WAN_IF" ]; then
                  ${pkgs.iproute2}/bin/ip -4 route replace ${wgEndpointHost}/32 via "$WAN_GW" dev "$WAN_IF"
                  # Resolve bypass domain IPs and stash them for clean teardown.
                  : > "$BYPASS_FILE"
                  for domain in ${lib.escapeShellArgs wgBypassDomains}; do
                    for ip in $(${getentBin} ahostsv4 "$domain" | ${pkgs.gawk}/bin/awk '{print $1}' | ${pkgs.coreutils}/bin/sort -u); do
                      ${pkgs.iproute2}/bin/ip -4 route replace "$ip/32" via "$WAN_GW" dev "$WAN_IF"
                      echo "$ip" >> "$BYPASS_FILE"
                    done
                  done
                fi
      '';
      postShutdown = ''
        ${pkgs.iproute2}/bin/ip -4 route del ${wgEndpointHost}/32 2>/dev/null || true
        BYPASS_FILE="/run/wireguard-bypass-ips"
        if [ -f "$BYPASS_FILE" ]; then
          while IFS= read -r ip; do
            [ -n "$ip" ] && ${pkgs.iproute2}/bin/ip -4 route del "$ip/32" 2>/dev/null || true
          done < "$BYPASS_FILE"
          rm -f "$BYPASS_FILE"
        fi
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
        # Kill switch: allow VPN endpoint handshake first, then block all non-tunnel egress.
        # Order matters: ACCEPT must come before REJECT so the handshake isn't blocked.
        ${pkgs.iptables}/bin/iptables -A OUTPUT -d ${wgEndpointHost} -p udp --dport ${wgEndpointPort} -j ACCEPT
        ${pkgs.iptables}/bin/iptables -A OUTPUT ! -o ${wgIf} ! -o tailscale0 \
          -m addrtype ! --dst-type LOCAL -j REJECT
        # IPv6: block non-tunnel egress (no IPv6 endpoint whitelist needed for IPv4-only ProtonVPN).
        ${pkgs.iptables}/bin/ip6tables -A OUTPUT ! -o ${wgIf} ! -o tailscale0 \
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
    # During `nixos-rebuild switch`, avoid restart/start churn when autostart is disabled.
    restartIfChanged = false;
    stopIfChanged = true;
  };

  # Ensure WireGuard sessions do not persist across boot/switch when autostart is disabled.
  # This runs after target activation and force-stops wg0 if it is up.
  systemd.services."wireguard-${wgIf}-nonpersistent" = lib.mkIf (vars.wgEnable && !wgAutostart) {
    description = "Force stop WireGuard when wgAutostart is disabled";
    wantedBy = [
      "multi-user.target"
      "sysinit-reactivation.target"
    ];
    after = [
      "network.target"
      "wireguard-${wgIf}.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
    };
    script = ''
      # Stop peer units first to avoid stop-order races being reported as failed units.
      for unit in $(${pkgs.systemd}/bin/systemctl list-units --all --full --plain 'wireguard-${wgIf}-peer-*.service' --no-legend 2>/dev/null | ${pkgs.gawk}/bin/awk '{print $1}'); do
        ${pkgs.systemd}/bin/systemctl stop "$unit" 2>/dev/null || true
        ${pkgs.systemd}/bin/systemctl reset-failed "$unit" 2>/dev/null || true
      done

      ${pkgs.systemd}/bin/systemctl stop wireguard-${wgIf}.service 2>/dev/null || true
      ${pkgs.systemd}/bin/systemctl reset-failed wireguard-${wgIf}.service 2>/dev/null || true
    '';
  };

  environment.systemPackages = with pkgs; [ wireguard-tools ];

  warnings = lib.optional (!vars.wgEnable) ''
    Proton WireGuard is disabled for host "${host}". Set wgEnable = true in hosts/${host}/variables.nix after filling wg values.
  '';
}
