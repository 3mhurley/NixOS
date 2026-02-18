{
  config,
  host,
  lib,
  pkgs,
  ...
}:
let
  vars = import ../../hosts/${host}/variables.nix;
  wgIf = "wg0";
  wgEnable = vars.wgEnable or false;
  wgAutostart = vars.wgAutostart or false;
  wgKillSwitch = vars.wgKillSwitch or false;
  wgBypassDomains = vars.wgBypassDomains or [ ];
  wgPresharedKeyFile = vars.wgPresharedKeyFile or "";
  wgSopsFile = ../../secrets/${host}/wireguard.yaml;
  ageKeyFile = "/home/${vars.username}/.config/sops/age/keys.txt";
  wgTemplateName = "wireguard-${host}-${wgIf}.conf";
  getentBin = "${pkgs.getent}/bin/getent";
  routeScript = pkgs.writeShellScript "wireguard-${wgIf}-routes" ''
    set -eu

    action="''${1:-}"
    BYPASS_FILE="/run/wireguard-bypass-ips-${wgIf}"
    ENDPOINT_FILE="/run/wireguard-endpoint-${wgIf}"

    case "$action" in
      up)
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

        ENDPOINT="$(${pkgs.wireguard-tools}/bin/wg show ${wgIf} endpoints | ${pkgs.gawk}/bin/awk 'NR==1{print $2}')"
        ENDPOINT_HOST="''${ENDPOINT%:*}"
        ENDPOINT_PORT="''${ENDPOINT##*:}"

        if [ -n "$WAN_GW" ] && [ -n "$WAN_IF" ] && [ -n "$ENDPOINT_HOST" ] && [ -n "$ENDPOINT_PORT" ]; then
          ${pkgs.iproute2}/bin/ip -4 route replace "$ENDPOINT_HOST/32" via "$WAN_GW" dev "$WAN_IF"
          printf '%s\n%s\n' "$ENDPOINT_HOST" "$ENDPOINT_PORT" > "$ENDPOINT_FILE"

          : > "$BYPASS_FILE"
          for domain in ${lib.escapeShellArgs wgBypassDomains}; do
            for ip in $(${getentBin} ahostsv4 "$domain" | ${pkgs.gawk}/bin/awk '{print $1}' | ${pkgs.coreutils}/bin/sort -u); do
              ${pkgs.iproute2}/bin/ip -4 route replace "$ip/32" via "$WAN_GW" dev "$WAN_IF"
              echo "$ip" >> "$BYPASS_FILE"
            done
          done

          ${
            lib.optionalString wgKillSwitch ''
              ${pkgs.iptables}/bin/iptables -A OUTPUT -d "$ENDPOINT_HOST" -p udp --dport "$ENDPOINT_PORT" -j ACCEPT
              ${pkgs.iptables}/bin/iptables -A OUTPUT ! -o ${wgIf} ! -o tailscale0 \
                -m addrtype ! --dst-type LOCAL -j REJECT
              ${pkgs.iptables}/bin/ip6tables -A OUTPUT ! -o ${wgIf} ! -o tailscale0 \
                -m addrtype ! --dst-type LOCAL -j REJECT
            ''
          }
        fi
        ;;
      down)
        ENDPOINT_HOST=""
        ENDPOINT_PORT=""
        if [ -f "$ENDPOINT_FILE" ]; then
          ENDPOINT_HOST="$(${pkgs.coreutils}/bin/sed -n '1p' "$ENDPOINT_FILE" 2>/dev/null || true)"
          ENDPOINT_PORT="$(${pkgs.coreutils}/bin/sed -n '2p' "$ENDPOINT_FILE" 2>/dev/null || true)"
        fi

        if [ -n "$ENDPOINT_HOST" ]; then
          ${pkgs.iproute2}/bin/ip -4 route del "$ENDPOINT_HOST/32" 2>/dev/null || true
        fi

        if [ -f "$BYPASS_FILE" ]; then
          while IFS= read -r ip; do
            [ -n "$ip" ] && ${pkgs.iproute2}/bin/ip -4 route del "$ip/32" 2>/dev/null || true
          done < "$BYPASS_FILE"
          rm -f "$BYPASS_FILE"
        fi

        ${
          lib.optionalString wgKillSwitch ''
            if [ -n "$ENDPOINT_HOST" ] && [ -n "$ENDPOINT_PORT" ]; then
              ${pkgs.iptables}/bin/iptables -D OUTPUT -d "$ENDPOINT_HOST" -p udp --dport "$ENDPOINT_PORT" -j ACCEPT || true
            fi
            ${pkgs.iptables}/bin/iptables -D OUTPUT ! -o ${wgIf} ! -o tailscale0 \
              -m addrtype ! --dst-type LOCAL -j REJECT || true
            ${pkgs.iptables}/bin/ip6tables -D OUTPUT ! -o ${wgIf} ! -o tailscale0 \
              -m addrtype ! --dst-type LOCAL -j REJECT || true
          ''
        }

        rm -f "$ENDPOINT_FILE"
        ;;
      *)
        echo "usage: $0 {up|down}" >&2
        exit 2
        ;;
    esac
  '';
in
{
  assertions = [
    {
      assertion = !wgEnable || builtins.pathExists wgSopsFile;
      message = "wgEnable is true but ${toString wgSopsFile} is missing.";
    }
  ];

  sops = lib.mkIf wgEnable {
    defaultSopsFile = wgSopsFile;
    defaultSopsFormat = "yaml";
    age.keyFile = ageKeyFile;

    secrets = {
      wgAddress = { };
      wgServerPublicKey = { };
      wgServerEndpoint = { };
      wgPrivateKey = { };
    };

    templates.${wgTemplateName} = {
      owner = "root";
      group = "root";
      mode = "0400";
      content = ''
        [Interface]
        Address = ${config.sops.placeholder."wgAddress"}
        PrivateKey = ${config.sops.placeholder."wgPrivateKey"}
        PostUp = ${routeScript} up
        PostDown = ${routeScript} down

        [Peer]
        PublicKey = ${config.sops.placeholder."wgServerPublicKey"}
        Endpoint = ${config.sops.placeholder."wgServerEndpoint"}
        AllowedIPs = 0.0.0.0/0
        PersistentKeepalive = 25
        ${
          lib.optionalString (wgPresharedKeyFile != "")
            "PresharedKey = ${wgPresharedKeyFile}"
        }
      '';
    };
  };

  networking = {
    # Keep WG control plane in systemd; avoid NM creating/activating its own WG profile.
    networkmanager.unmanaged = lib.optional wgEnable "interface-name:${wgIf}";

    wg-quick.interfaces.${wgIf} = lib.mkIf wgEnable {
      autostart = wgAutostart;
      configFile = config.sops.templates.${wgTemplateName}.path;
    };

    firewall.allowedUDPPorts = [ ];
  };

  # Coexist with strict global rp_filter from security.nix.
  boot.kernel.sysctl."net.ipv4.conf.${wgIf}.rp_filter" = lib.mkIf wgEnable 2;

  systemd.services."wg-quick-${wgIf}" = lib.mkIf (wgEnable && !wgAutostart) {
    wantedBy = lib.mkForce [ ];
    restartIfChanged = false;
    stopIfChanged = true;
  };

  # Ensure WireGuard sessions do not persist across boot/switch when autostart is disabled.
  systemd.services."wg-quick-${wgIf}-nonpersistent" = lib.mkIf (wgEnable && !wgAutostart) {
    description = "Force stop WireGuard when wgAutostart is disabled";
    wantedBy = [
      "multi-user.target"
      "sysinit-reactivation.target"
    ];
    after = [
      "network.target"
      "wg-quick-${wgIf}.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
    };
    script = ''
      ${pkgs.systemd}/bin/systemctl stop wg-quick-${wgIf}.service 2>/dev/null || true
      ${pkgs.systemd}/bin/systemctl reset-failed wg-quick-${wgIf}.service 2>/dev/null || true
    '';
  };

  environment.systemPackages = with pkgs; [ wireguard-tools ];

  warnings = lib.optional (!wgEnable) ''
    Proton WireGuard is disabled for host "${host}". Configure encrypted values in secrets/${host}/wireguard.yaml and set wgEnable = true.
  '';
}
