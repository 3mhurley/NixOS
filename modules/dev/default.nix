{ pkgs, ... }:
{
  # Rootless containers (no docker daemon running as root)
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  # Per-project environments via flakes + direnv — keep the system clean,
  # put language toolchains in each project's devShell instead.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  documentation.dev.enable = true;

  environment.systemPackages = with pkgs; [
    git
    gnumake
    gcc
    nil # Nix LSP
    nixfmt-rfc-style
    ripgrep
    fd
    jq
    curl
    wget
    btop
    unzip
  ];
}
