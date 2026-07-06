{ ... }:
{
  # Encrypted DNS: systemd-resolved with DNS-over-TLS to Quad9 (malware blocking).
  services.resolved = {
    enable = true;
    dnsovertls = "true";
    dnssec = "allow-downgrade";
    fallbackDns = [ "1.1.1.1#cloudflare-dns.com" "1.0.0.1#cloudflare-dns.com" ];
  };

  networking.nameservers = [
    "9.9.9.9#dns.quad9.net"
    "149.112.112.112#dns.quad9.net"
    "2620:fe::fe#dns.quad9.net"
  ];
}
