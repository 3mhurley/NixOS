{ ... }:
{
  # Two-drive layout (see docs/dual-boot-windows.md):
  #   new M.2      — ESP / cryptroot / swap  (OS)
  #   new 4TB SATA — cryptdata → /data       (Steam library, bulk)
  # Windows drives are never referenced or mounted.

  # ── M.2: LUKS2 root, unlocked by TPM2 (with passphrase fallback) ──
  # Enrollment after install (see README):
  #   sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7 /dev/disk/by-partlabel/cryptroot
  boot.initrd.luks.devices.cryptroot = {
    device = "/dev/disk/by-partlabel/cryptroot";
    allowDiscards = true;
    crypttabExtraOpts = [ "tpm2-device=auto" ];
  };

  # systemd-based initrd: required for TPM2 unlock, faster, measured boot.
  boot.initrd.systemd.enable = true;

  # Encrypted swap (random key each boot — no hibernation).
  swapDevices = [
    {
      device = "/dev/disk/by-partlabel/swap";
      randomEncryption.enable = true;
    }
  ];

  # ── 4TB SATA: LUKS2 data volume, unlocked after root via keyfile ──
  # Keyfile lives on the encrypted root, so the single TPM/passphrase unlock
  # opens both drives. Create it post-install (see docs/dual-boot-windows.md):
  #   dd if=/dev/urandom of=/etc/cryptdata.key bs=64 count=1 && chmod 0400 /etc/cryptdata.key
  #   cryptsetup luksAddKey /dev/disk/by-partlabel/cryptdata /etc/cryptdata.key
  environment.etc.crypttab.text = ''
    cryptdata /dev/disk/by-partlabel/cryptdata /etc/cryptdata.key discard,nofail
  '';

  fileSystems."/data" = {
    device = "/dev/mapper/cryptdata";
    fsType = "ext4";
    options = [
      "nofail" # don't block boot if the drive is missing
      "x-systemd.device-timeout=10s"
    ];
  };
}
