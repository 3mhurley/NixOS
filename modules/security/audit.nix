{ ... }:
{
  # Kernel audit trail
  security.auditd.enable = true;
  security.audit = {
    enable = true;
    rules = [
      "-a exit,always -F arch=b64 -S execve" # log all executions
    ];
  };

  # Journald: persist, cap size
  services.journald.extraConfig = ''
    Storage=persistent
    SystemMaxUse=1G
  '';

  # SSH: key-only, no root. Off by default on a desktop — enable if needed.
  services.openssh = {
    enable = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
    };
    # When enabled, reachable only over Tailscale (see network/firewall.nix).
  };

  # Brute-force protection if SSH is ever exposed
  services.fail2ban.enable = true;
}
