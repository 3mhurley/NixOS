{
  username = "onee"; # auto-set with install.sh, live-install.sh, and rebuild scripts.

  # Desktop Environment
  desktop = "hyprland"; # hyprland, i3, gnome, plasma6

  # Theme & Appearance
  waybarTheme = "minimal"; # stylish, minimal
  sddmTheme = "astronaut"; # astronaut, black_hole, purple_leaves, jake_the_dog, hyprland_kath
  defaultWallpaper = "train-sideview.webp"; # Change with SUPER + SHIFT + W
  hyprlockWallpaper = "train-sideview.webp";

  # Default Applications
  terminal = "kitty"; # kitty, alacritty
  editor = "nixvim"; # nixvim, vscode, helix, doom-emacs, nvchad, neovim
  browser = "firefox"; # zen, firefox, floorp
  tuiFileManager = "yazi"; # yazi, lf
  shell = "zsh"; # zsh, bash
  games = true; # Enable/Disable gaming module

  # Hardware
  hostname = "NixOS-Ava";

  # Network QoS
  uploadSpeed = "285Mbit"; # 95% of actual upload
  downloadSpeed = "2000Mbit"; # 95% of actual download
  wanInterface = ""; # Optional: set e.g. "enp6s0" to pin CAKE shaping to physical WAN

  # WireGuard / ProtonVPN
  wgEnable = true; # Set true after filling values below and creating key file in /etc/wireguard
  wgKillSwitch = false; # Optional: set true to block non-VPN egress when wgEnable = true
  wgPresharedKeyFile = ""; # Optional/Proton: file containing [Peer] PresharedKey
  wgAddress = "REDACTED_ADDR"; # [Interface] Address from ProtonVPN WireGuard config, e.g. "REDACTED_ADDR"
  wgServerPublicKey = "REDACTED_PUBKEY"; # [Peer] PublicKey from ProtonVPN WireGuard config
  wgServerEndpoint = "REDACTED_ENDPOINT:51820"; # [Peer] Endpoint from ProtonVPN WireGuard config, e.g. "1.2.3.4:51820"

  # Audio
  alsaDevice = "alsa_input.pci-0000_00_1f.3.analog-stereo";
  videoDriver = "nvidia"; # nvidia, amdgpu, intel

  # Localization
  timezone = "America/Denver";
  locale = "en_US.UTF-8";
  clock24h = true;
  kbdLayout = "us";
  kbdVariant = "extd";
  consoleKeymap = "us";
}
