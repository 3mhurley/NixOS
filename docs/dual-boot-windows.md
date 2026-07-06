# Dual-boot plan: Windows 11 (existing 3 drives) + NixOS (new M.2 + old 4TB SATA SSD)

Goal: two closed environments on one PC. Windows keeps its own boot manager,
ESP, and Secure Boot chain — untouched forever. NixOS lives entirely on the two
new drives with its own ESP. OS choice happens in the **firmware boot menu**,
never via one OS's bootloader chainloading the other.

## Why it broke last time, and what prevents it now

Last time the Linux installer wrote its bootloader onto the **Windows ESP**
(the only ESP visible during install), so Windows Update could no longer
service its boot files. Guardrails this time:

1. **Windows drives physically disconnected during install** — the installer
   *cannot* pick the wrong ESP if it isn't there.
2. **NixOS gets its own ESP** on the new M.2. systemd-boot/lanzaboote only ever
   writes to the ESP mounted at `/boot`. Two ESPs, zero shared files.
3. **No Windows entries in systemd-boot, no os-prober, no chainloading.**
   NixOS never mounts the Windows ESP or NTFS volumes.
4. **Windows stays first in NVRAM boot order.** NixOS is reached via the
   boot-menu key. `nixos-rebuild` only rewrites its own entry; it never
   reorders or deletes Windows Boot Manager.
5. **Secure Boot keys enrolled with `--microsoft`**, keeping Microsoft's KEK/db
   certs alongside your keys — Windows keeps booting with Secure Boot ON and
   can still receive signed DBX/boot updates.

## Target layout

| Drive | Content | Touched by NixOS? |
|---|---|---|
| Existing M.2 + 2 SATA | Windows 11, its ESP, its data | Never (not mounted) |
| New M.2 (brand new) | `ESP` 1G vfat · `cryptroot` LUKS2 (root+/home) · `swap` | Yes — NixOS owns it |
| Old 4TB SATA SSD (repurposed, wiped in Phase 2) | `cryptdata` LUKS2 → `/data` (Steam library, bulk) | Yes — NixOS owns it |

Partition names are GPT **partlabels** and must match `hosts/citadel/disks.nix`.

## Phase 0 — prep (in Windows, before opening the case)

- Confirm BitLocker is off: `manage-bde -status` (you said it is — verify anyway).
- Note current firmware boot order and your boot-menu key (F11/F12/F8 by board).
- Windows Fast Startup OFF (Control Panel → Power Options) — avoids NTFS/clock
  weirdness on dual-boot machines even when drives aren't shared.
- Create a Windows recovery USB (belt-and-suspenders; you should never need it).

## Phase 1 — hardware

1. Power off, unplug PSU, hit the power button to drain. **Disconnect all three
   Windows drives** — pull SATA *data* cables (power can stay), and pull the
   Windows M.2 from its slot (pulling it is the safest). Label or photograph
   which cable/port each drive used so reconnection in Phase 4 is exact.
2. Install the new M.2 and the old 4TB SATA SSD (from the shelf).
3. In firmware: temporarily **disable Secure Boot** (the NixOS ISO is unsigned).
   Leave everything else alone.
4. Sanity check before proceeding: firmware should now list **only** the two
   NixOS-destined drives. If any Windows drive still appears, stop and pull it.

## Phase 2 — install NixOS (only the two NixOS drives connected)

Boot the NixOS 26.05 ISO. Every command below is destructive only to the two
connected drives — but identify them anyway before touching anything.

### 2.0 Identify the drives

```sh
lsblk -o NAME,MODEL,SERIAL,SIZE,TYPE,TRAN
```

Expect exactly two disks: the new M.2 (`nvme0n1`, TRAN `nvme`) and the old 4TB
SSD (`sda`, TRAN `sata`). Match MODEL/SERIAL against the physical drives. If
anything else shows up, **stop** — a Windows drive is still connected.
Device names below assume `nvme0n1` / `sda`; adjust if yours differ.

### 2.1 Wipe the old 4TB SSD (it has an old partition table / data)

```sh
wipefs -a /dev/sda            # erase filesystem/RAID/LUKS signatures
sgdisk --zap-all /dev/sda     # destroy GPT+MBR structures
blkdiscard -f /dev/sda        # TRIM the whole device — resets cells, fast
```

If `blkdiscard` fails (some SATA controllers block it), it's fine to skip:
everything written from here on is LUKS-encrypted; old remnant data is
indistinguishable from noise. The new M.2 needs no wipe.

### 2.2 Partition (partlabels must match `hosts/citadel/disks.nix`)

```sh
# New M.2 — ESP / cryptroot / swap (swap sized to taste; 32G shown)
sgdisk -n1:0:+1G   -t1:ef00 -c1:ESP       /dev/nvme0n1
sgdisk -n2:0:-32G  -t2:8309 -c2:cryptroot /dev/nvme0n1
sgdisk -n3:0:0     -t3:8200 -c3:swap      /dev/nvme0n1

# Old 4TB SSD — single data partition
sgdisk -n1:0:0 -t1:8309 -c1:cryptdata /dev/sda

partprobe; ls -l /dev/disk/by-partlabel/   # ESP, cryptroot, swap, cryptdata
```

### 2.3 Encrypt and format

```sh
cryptsetup luksFormat --type luks2 /dev/disk/by-partlabel/cryptroot
cryptsetup luksFormat --type luks2 /dev/disk/by-partlabel/cryptdata
cryptsetup open /dev/disk/by-partlabel/cryptroot cryptroot
cryptsetup open /dev/disk/by-partlabel/cryptdata cryptdata

mkfs.fat -F32 -n ESP /dev/disk/by-partlabel/ESP
mkfs.ext4 -L nixos /dev/mapper/cryptroot
mkfs.ext4 -L data  /dev/mapper/cryptdata
# swap partition: leave it — disks.nix sets up random-key encrypted swap
```

### 2.4 Mount and install

```sh
mount /dev/mapper/cryptroot /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-partlabel/ESP /mnt/boot
# do NOT mount cryptdata under /mnt — disks.nix already declares /data;
# mounting it now would put a duplicate entry in hardware-configuration.nix

nix-shell -p git sops age    # tools for the steps below
git clone <repo-url> /mnt/etc/nixos && cd /mnt/etc/nixos

nixos-generate-config --root /mnt --show-hardware-config \
  > hosts/citadel/hardware-configuration.nix

# real password hash (see README step 4)
mkpasswd -m sha-512          # paste into modules/core/users.nix

# bootstrap sops — key must land on the TARGET system, hence /mnt:
mkdir -p /mnt/var/lib/sops-nix
age-keygen -o /mnt/var/lib/sops-nix/key.txt
age-keygen -y /mnt/var/lib/sops-nix/key.txt   # paste into .sops.yaml
sops secrets/secrets.yaml    # set tailscale-authkey, wireguard-private-key

nixos-install --flake /mnt/etc/nixos#citadel
```

Reboot (remove ISO) — systemd-boot first (lanzaboote inactive until keys
exist). Confirm NixOS boots and `cryptroot` unlocks with the passphrase.
`/data` won't mount yet (`nofail`) — the keyfile comes in Phase 3.

## Phase 3 — Secure Boot (still with Windows drives disconnected)

README "Post-install", the critical flags spelled out. First move the repo to
where the daily aliases expect it:

```sh
sudo mv /etc/nixos ~/nixos && sudo chown -R evan:users ~/nixos
```

```sh
sudo sbctl create-keys
sudo nixos-rebuild switch --flake ~/nixos#citadel
sudo sbctl verify                    # all files signed
# firmware: put Secure Boot into Setup Mode (clear keys)
sudo sbctl enroll-keys --microsoft   # ← keeps MS certs; this is what keeps Windows bootable
# firmware: enable Secure Boot; reboot; bootctl status shows "Secure Boot: enabled"
```

Then TPM2 enrollment (PCR 7 is now meaningful):

```sh
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7 /dev/disk/by-partlabel/cryptroot
```

Set up the data-drive keyfile so one unlock opens both drives:

```sh
sudo dd if=/dev/urandom of=/etc/cryptdata.key bs=64 count=1
sudo chmod 0400 /etc/cryptdata.key
sudo cryptsetup luksAddKey /dev/disk/by-partlabel/cryptdata /etc/cryptdata.key
sudo nixos-rebuild switch --flake ~/nixos#citadel   # crypttab + /data mount
```

## Phase 4 — reconnect Windows, set boot order

1. Power off, reconnect the three Windows drives.
2. In firmware: **boot order = Windows Boot Manager first**, NixOS
   (systemd-boot on the new M.2) second. If the firmware UI is awkward, from
   NixOS: `efibootmgr` to list, `efibootmgr -o XXXX,YYYY` to order.
3. Boot straight through → Windows must come up exactly as before, Secure Boot
   ON (`msinfo32` → Secure Boot State: On). Run Windows Update to confirm it
   still patches.
4. Reboot, press the boot-menu key, pick the NixOS entry → TPM auto-unlock.

## Phase 5 — keep them closed

- Never mount Windows partitions from NixOS (nothing in config references
  them; keep it that way — no ntfs-3g mounts of the Windows drives).
- Never add a Windows entry to systemd-boot.
- After firmware (BIOS) updates: PCRs change → LUKS falls back to passphrase;
  re-enroll TPM. If the firmware update resets Secure Boot to factory keys,
  NixOS won't boot until you redo `sbctl enroll-keys --microsoft` from a
  recovery boot (keep the LUKS passphrase and a NixOS ISO USB around).
- Windows clock skew: NixOS uses UTC RTC by default; if Windows shows wrong
  time, set `RealTimeIsUniversal=1` in the Windows registry (do it in Windows —
  don't touch Windows from NixOS).

## Failure modes and blast radius

| Event | Effect on Windows | Effect on NixOS |
|---|---|---|
| `nixos-rebuild` / kernel update | none (own ESP) | normal |
| Windows Update / boot-manager update | normal | none |
| Firmware resets SB keys | boots (MS keys are factory) | re-enroll sbctl keys |
| New M.2 dies | none — boot order falls through to Windows | reinstall on replacement |
| Wipe/reinstall either OS | other OS untouched | other OS untouched |
