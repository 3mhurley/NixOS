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
  browser = "zen"; # zen, firefox, floorp
  tuiFileManager = "yazi"; # yazi, lf
  shell = "zsh"; # zsh, bash
  games = true; # Enable/Disable gaming module

  # Hardware
  hostname = "NixOS-Default";

  # Network QoS
  uploadSpeed = "285Mbit"; # 95% of actual upload
  downloadSpeed = "2000Mbit"; # 95% of actual download
  wanInterface = ""; # Optional: set e.g. "enp6s0" to pin CAKE shaping to physical WAN

  # WireGuard / ProtonVPN
  wgEnable = false; # Set true after creating secrets/${hostname}/wireguard.yaml
  wgAutostart = false; # true to start at boot, false for manual wg-toggle
  wgKillSwitch = false; # Optional: set true to block non-VPN egress when wgEnable = true
  wgBypassDomains = [ ]; # Optional split-tunnel domain bypass list (routed over WAN when wg0 is up)
  wgPresharedKeyFile = ""; # Optional [Peer] PresharedKey file path

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
