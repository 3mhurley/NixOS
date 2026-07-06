# citadel — secure NixOS workstation

Flake-based NixOS 26.05 config for gaming + development with defense-in-depth:
Secure Boot (lanzaboote), LUKS2 + TPM2 auto-unlock, sops-nix secrets, Tailscale
(+ optional WireGuard exit tunnel), nftables deny-by-default firewall, encrypted
DNS, AppArmor, auditd, and kernel hardening tuned to not cost gaming performance.

## Layout

```
flake.nix              inputs: nixpkgs 26.05, home-manager, lanzaboote v1.0.0, sops-nix
hosts/citadel/         host entry, hardware config (placeholder), LUKS/swap
modules/core/          boot/lanzaboote, nix settings, declarative users, locale
modules/security/      sysctl hardening, AppArmor, auditd, fail2ban, sops secrets
modules/network/       nftables firewall, Tailscale, WireGuard (opt-in), DoT DNS
modules/hardware/      NVIDIA (open module, latest driver)
modules/desktop/       Plasma 6 Wayland, PipeWire
modules/gaming/        Steam, Proton-GE, gamemode, gamescope, MangoHud
modules/dev/           podman (rootless), direnv, base toolchain
home/evan.nix          home-manager: git (SSH signing), zsh, starship
secrets/               sops-encrypted secrets (placeholder — see below)
```

## Install

> **Dual-booting alongside Windows?** Follow `docs/dual-boot-windows.md` —
> it wraps these steps with the Windows-preservation guardrails (drives
> disconnected during install, separate ESP, boot order, `--microsoft` keys).

1. **Boot the NixOS 26.05 ISO.** Reusing an old drive? Wipe it first
   (`wipefs -a`, `sgdisk --zap-all`, `blkdiscard` — exact commands in
   `docs/dual-boot-windows.md` §2.1).
2. Partition (GPT): ESP (1G, partlabel `ESP`), `cryptroot`, `swap`; data drive
   gets a single `cryptdata` partition. Partlabels must match
   `hosts/citadel/disks.nix`, or edit that file. (sgdisk commands: doc §2.2.)
3. `cryptsetup luksFormat --type luks2` both LUKS partitions; open them;
   `mkfs.fat -F32 -n ESP` the ESP, `mkfs.ext4` the mapped volumes.
4. Mount root at `/mnt`, ESP at `/mnt/boot` (leave `cryptdata` unmounted —
   `disks.nix` declares `/data`), then replace the placeholder:
   `nixos-generate-config --root /mnt --show-hardware-config > hosts/citadel/hardware-configuration.nix`
5. Set a real password hash in `modules/core/users.nix` (`mkpasswd -m sha-512`).
6. **Bootstrap secrets** (required — the placeholder `secrets/secrets.yaml`
   will fail the build until replaced). Note `/mnt`: the key must land on the
   target system, not the live ISO:
   ```sh
   mkdir -p /mnt/var/lib/sops-nix && age-keygen -o /mnt/var/lib/sops-nix/key.txt
   age-keygen -y /mnt/var/lib/sops-nix/key.txt   # paste into .sops.yaml
   sops secrets/secrets.yaml                 # set tailscale-authkey, wireguard-private-key
   ```
7. `nixos-install --flake .#citadel`

## Post-install

**Secure Boot** (lanzaboote starts inactive until keys exist):
```sh
sudo sbctl create-keys
sudo nixos-rebuild switch --flake .#citadel
sudo sbctl verify                  # everything must be signed
# reboot into firmware, clear/enroll Setup Mode:
sudo sbctl enroll-keys --microsoft # keep MS keys (GPU option ROMs need them)
# enable Secure Boot in firmware, reboot, then: bootctl status
```

**TPM2 auto-unlock** (only after Secure Boot is on, so PCR 7 is meaningful):
```sh
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7 /dev/disk/by-partlabel/cryptroot
```
Keep the LUKS passphrase as fallback — firmware updates change PCRs.

**Tailscale**: joins automatically via the auth key. SSH into this box only via
Tailscale SSH (`tailscale0` is the only trusted interface; sshd is off).

**WireGuard exit tunnel**: fill peer/endpoint in `modules/network/wireguard.nix`,
then set `my.wireguard.enable = true;` in `hosts/citadel/default.nix`.

**USBGuard** (optional): plug in your devices, then
`usbguard generate-policy > /var/lib/usbguard/rules.conf` and flip
`services.usbguard.enable = true`.

## Daily use

```sh
rebuild   # alias: sudo nixos-rebuild switch --flake ~/nixos#citadel
update    # flake update + rebuild
```

Per-project dev environments: add a `flake.nix` devShell + `.envrc`
(`use flake`) to each repo — direnv/nix-direnv loads it automatically.
Keep toolchains out of the system config.

## Security notes / trade-offs

- Standard latest kernel, not `linux_hardened` — the hardened kernel costs real
  gaming performance; mitigations here are sysctls + module blacklist instead.
- NVIDIA driver and Steam are unfree, large, and proprietary — inherently a
  trust trade-off you opted into for gaming.
- `kernel.yama.ptrace_scope = 1` (not 2) so debuggers still work for dev.
- Thunderbolt/FireWire modules blacklisted (DMA attacks) — remove
  `thunderbolt` from the blacklist if you use a TB dock.
- Run `nix flake check` after cloning; this repo was authored off-machine.
