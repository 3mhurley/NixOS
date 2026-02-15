{ ... }:
{
  services.tailscale = {
    enable = true;
    openFirewall = true;
    extraUpFlags = [ "--accept-dns=false" ];
  };
}
