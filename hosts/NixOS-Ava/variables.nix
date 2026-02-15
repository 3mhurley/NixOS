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
  wgEnable = false; # Set true after filling values below and creating key file in /etc/wireguard
  wgAddress = "10.2.0.2/32"; # [Interface] Address from ProtonVPN WireGuard config, e.g. "10.2.0.2/32"
  wgServerPublicKey = "xNAHXhTgYJEPWDwT4g80nqfcfA6bknhNkCRfDOPMcUA="; # [Peer] PublicKey from ProtonVPN WireGuard config
  wgServerEndpoint = "95.173.221.187:51820"; # [Peer] Endpoint from ProtonVPN WireGuard config, e.g. "1.2.3.4:51820"

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
