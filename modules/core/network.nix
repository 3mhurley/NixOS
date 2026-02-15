{ host, pkgs, ... }:
let
  inherit (import ../../hosts/${host}/variables.nix) hostname uploadSpeed downloadSpeed;
in
{
  networking = {
    hostName = "${hostname}";
    networkmanager.enable = true;
    # wireless.enable = true; # Enables wireless support via wpa_supplicant.
    # proxy = {
    #   default = "http://user:password@proxy:port/";
    #   noProxy = "127.0.0.1,localhost,internal.domain";
    # };

    firewall = {
      enable = true;
      # allowedTCPPorts = [
      # 22 # SSH (Secure Shell) - remote access
      # 80 # HTTP - web traffic
      # 443 # HTTPS - encrypted web traffic
      # 59010 # Custom application port
      # 59011 # Custom application port
      # 8080 # Alternative HTTP/web server port
      # ];
      # allowedUDPPorts = [
      # 59010 # Custom application port
      # 59011 # Custom application port
      # ];
    };
    localCommands = ''
      # Detect the default route interface dynamically
      WANIF=$(${pkgs.iproute2}/bin/ip route show default | ${pkgs.gawk}/bin/awk '{print $5; exit}')

      # Exit early if no default route interface was found
      [ -z "$WANIF" ] && exit 0

      # Create the ifb0 interface if it does not exist (used for ingress traffic shaping)
      ${pkgs.iproute2}/bin/ip link show ifb0 > /dev/null 2>&1 || \
        ${pkgs.iproute2}/bin/ip link add name ifb0 type ifb
      ${pkgs.iproute2}/bin/ip link set dev ifb0 up

      # Apply Cake queuing discipline on the WAN interface for upload shaping
      # Uses 'replace' to atomically update the qdisc on hot rebuilds
      # Options:
      # - bandwidth: set maximum upload bandwidth limit (95% of 300Mbps)
      # - diffserv4: enable DiffServ for QoS marking support
      # - triple-isolate: isolate flows between local, ingress, and egress
      # - nat: improve NAT handling for better fairness
      # - wash: normalize DSCP markings
      # - ack-filter: filter TCP ACK packets to reduce unnecessary traffic
      # - overhead: account for protocol overhead in shaping calculations
      ${pkgs.iproute2}/bin/tc qdisc replace dev "$WANIF" root cake \
        bandwidth ${uploadSpeed} diffserv4 triple-isolate nat wash ack-filter overhead 50

      # Add ingress qdisc on WAN interface to redirect ingress traffic to ifb0
      ${pkgs.iproute2}/bin/tc qdisc replace dev "$WANIF" handle ffff: ingress

      # Redirect all incoming IP traffic from WAN interface to ifb0 for download shaping
      ${pkgs.iproute2}/bin/tc filter replace dev "$WANIF" parent ffff: protocol ip u32 match u32 0 0 \
        flowid 1:1 action mirred egress redirect dev ifb0

      # Apply Cake queuing discipline on ifb0 interface for download shaping (95% of 2100Mbps)
      ${pkgs.iproute2}/bin/tc qdisc replace dev ifb0 root cake \
        bandwidth ${downloadSpeed} diffserv4 triple-isolate nat wash overhead 50
    '';
  };

  environment.systemPackages = with pkgs; [
    networkmanagerapplet
    iproute2
  ];
}
