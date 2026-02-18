# WireGuard Secrets with sops-nix

This repo now expects WireGuard connection values in encrypted files:

- `secrets/Default/wireguard.yaml`
- `secrets/NixOS-Ava/wireguard.yaml`

The files are decrypted at activation via `sops-nix` and rendered to a runtime WireGuard config for `wg-quick-wg0`.

## 1) Set up age + sops

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
age-keygen -y ~/.config/sops/age/keys.txt
```

Copy `.sops.yaml.example` to `.sops.yaml`, then replace `CHANGE_ME_AGE_RECIPIENT` with your public age key.

## 2) Create encrypted host secret

```bash
cp secrets/NixOS-Ava/wireguard.yaml.example secrets/NixOS-Ava/wireguard.yaml
sops -e -i secrets/NixOS-Ava/wireguard.yaml
```

Required keys:

- `wgAddress`
- `wgServerPublicKey`
- `wgServerEndpoint`
- `wgPrivateKey`

## 3) Enable WireGuard in host variables

Set in `hosts/<host>/variables.nix`:

- `wgEnable = true;`
- Optional: `wgAutostart`, `wgKillSwitch`, `wgBypassDomains`, `wgPresharedKeyFile`

## 4) Rebuild

```bash
rebuild
```

Unit names:

- `wg-quick-wg0.service`
- `wg-quick-wg0-nonpersistent.service` (when `wgAutostart = false`)
