{ pkgs, ... }:
{
  # Users are declarative-only; no imperative useradd/passwd drift.
  users.mutableUsers = false;

  users.users.evan = {
    isNormalUser = true;
    description = "Evan";
    extraGroups = [ "wheel" "networkmanager" "gamemode" ];
    shell = pkgs.zsh;
    # Generate with: mkpasswd -m sha-512
    hashedPassword = "$6$REPLACE_ME$REPLACE_ME_WITH_REAL_HASH";
    openssh.authorizedKeys.keys = [
      # "ssh-ed25519 AAAA... dev@evanhurley.dev"
    ];
  };

  programs.zsh.enable = true;

  security.sudo = {
    execWheelOnly = true;
    extraConfig = ''
      Defaults lecture = never
      Defaults passwd_timeout = 0
    '';
  };
}
