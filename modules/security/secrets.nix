{ ... }:
{
  # sops-nix: secrets encrypted with age, committed to the repo.
  # Bootstrap (see README):
  #   1. age-keygen -o /var/lib/sops-nix/key.txt   (on the target machine, as root)
  #   2. Put the public key in .sops.yaml
  #   3. sops secrets/secrets.yaml  → add keys, save
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";

    secrets = {
      tailscale-authkey = { };
      wireguard-private-key = {
        owner = "root";
        mode = "0400";
      };
    };
  };
}
