{ pkgs, ... }:
{
  home.username = "evan";
  home.homeDirectory = "/home/evan";
  home.stateVersion = "26.05";

  programs.git = {
    enable = true;
    userName = "Evan";
    userEmail = "dev@evanhurley.dev";
    signing = {
      format = "ssh";
      key = "~/.ssh/id_ed25519.pub";
      signByDefault = true;
    };
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      fetch.prune = true;
    };
  };

  programs.ssh = {
    enable = true;
    # Hosts on the tailnet resolve via MagicDNS; Tailscale SSH handles auth.
    matchBlocks."*" = {
      serverAliveInterval = 60;
      hashKnownHosts = true;
    };
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --flake ~/nixos#citadel";
      update = "nix flake update --flake ~/nixos && rebuild";
    };
  };

  programs.starship.enable = true;

  programs.fzf.enable = true;
  programs.zoxide.enable = true;
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  home.packages = with pkgs; [
    vscode # or your editor of choice
    eza
    bat
  ];
}
