{ ... }:
{
  services.openssh = {
    enable = false;
    settings = {
      PasswordAuthentication = false;
      AllowUsers = ["Onee"]; # Allows all users by default. Can be [ "user1" "user2" ]
      UseDns = true;
      X11Forwarding = false;
      PermitRootLogin = "prohibit-password"; # "yes", "without-password", "prohibit-password", "forced-commands-only", "no"
    };
  };
}
